#!/bin/bash
set -e

usage() {
  echo 'This script is intended for verifying the restore of a mongodump into a'
  echo 'DocumentDB cluster.'
  echo
  echo 'Given a MongoDB backup (a directory of mongodump output), a DB cluster'
  echo 'which has just been restored into, and one or more database names, this'
  echo 'script:'
  echo
  echo '1. Runs a mongodump from the restored DB cluster, into a temp directory.'
  echo '2. Produces a JSON file for each collection in the old and new dumps. These'
  echo '   contains one line of JSON per document (record).'
  echo '3. Compares the JSON of the original dump with the new dump, producing a'
  echo '   file of diffs for each collection where there are differences.'
  echo
  echo 'usage: [nocleanup=1] $0 dump_dir rs0/host1,host2,host3 database [database ...]'
  echo 
  echo 'The directory dump_dir should contain a directory for each database named on'
  echo 'the command line. Each of those directories should contain bson files.'
  echo
  echo 'The nocleanup option leaves the created mongodump in $TEMP instead of'
  echo 'deleting it afterwards.'
  echo
  echo 'In this example, the current directory contains licensify-refdata/*.bson'
  echo 'and licensify/*.bson and we want to compare those against a DocDB:'
  echo
  echo "nocleanup=1 $0 . rs0/licensify-documentdb-0.x.eu-west-1.docdb.amazonaws.com,licensify-documentdb-1.x.eu-west-1.docdb.amazonaws.com,licensify-documentdb-2.x.eu-west-1.docdb.amazonaws.com licensify-refdata licensify"
  exit 64  # EX_USAGE from sysexits.h
}

decode_collection() {
  # Given a path to a BSON file, produce a JSON file in the same directory.
  # Example: decode_collection /tmp/licensify-refdata/departments.bson
  infile="${1?}"
  outfile="${infile%bson}json"
  echo "${infile}" >&2
  bsondump "${infile}" > "${outfile}"
}

decode_db_dump() {
  # Given a path to a directory containing BSON files, produce a JSON file for
  # each, in the same directory.
  dumpdir="${1?}"
  for collection in "${dumpdir?}"/*.bson; do
    decode_collection "${collection?}"
  done
}

dump_for_verification() {
  # Given a database name and a directory for output, produce a mongodump of
  # all the collections from that database. The output directory will contain
  # a BSON file for each collection. The source DB is determined by the globals
  # $db_hostname, $db_username, $db_password.
  db="${1?}"
  outdir="${2?}"
  mongodump -h "${db_hostname?}" -u "${db_username?}" -p "${db_password}" \
            -d "${db?}" -o "${outdir?}"
}

compare_db() {
  # Given two directories which contain JSON files, compare all equivalently
  # named pairs of JSON files. Output in universal diff format to stdout.
  orig="${1?}"
  new="${2?}"
  for orig_path in "${orig?}"/*.json; do
    filename="$(basename ${orig_path?})"
    # Skip the metadata json files. We definitely don't want to in-place-sort
    # those and it isn't particularly helpful to diff them either.
    if [[ "${filename}" == *".metadata.json" ]]; then
      continue
    fi
    new_path="${new?}/${filename?}"
    # Sort files in-place. This effectively sorts by object ID. We need to sort
    # in order for the diff to be meaningful, because there is no guarantee of
    # consistent ordering between dumps.
    sort -o "${orig_path?}" "${orig_path?}"
    sort -o "${new_path?}" "${new_path?}"
    diff_outfile="${orig?}/${filename?}.diff"
    if ! diff -u "${orig_path?}" "${new_path?}" > "${diff_outfile?}"; then
      diff_line_count="$(wc -l ${diff_outfile?} |grep -o '[0-9]\+')"
      echo "${diff_outfile?}: ${diff_line_count?} lines of diff output (recommend less -S to view)" >&2
    fi
  done
}

cleanup() {
  if [ $nocleanup ]; then
    echo "Leaving verification dumps in ${verification_dump_dir?}" >&2
  else
    echo "Removing temp files from ${verification_dump_dir?}" >&2
    rm -r "${verification_dump_dir?}"
  fi
}

if [ $# -lt 3 ]; then
  usage
fi
orig_dump_dir="$1"; shift
db_hostname="$1"; shift
databases="$@"
db_username="master"

verification_dump_dir="$(mktemp -d)"
trap cleanup EXIT

echo -n "DB password for ${db_username?} user: "
read -s db_password
echo

for db in $databases; do
  dump_for_verification "${db?}" "${verification_dump_dir?}"
  echo "Decoding BSON files to JSON:" >&2
  decode_db_dump "${orig_dump_dir?}/${db?}"
  decode_db_dump "${verification_dump_dir?}/${db?}"
  compare_db "${orig_dump_dir?}/${db?}" "${verification_dump_dir?}/${db?}"
done
