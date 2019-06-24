#! /bin/bash

rm -rf .venv function.zip

virtualenv .venv
. .venv/bin/activate
pip install --user -r requirements.txt

zip -r function.zip download_logs handler.py -x *.pyc -x *.log
(
  cd .venv/lib/python3.6/site-packages
  zip -r ../../../../function.zip * -x *.pyc
)

pip download --platform manylinux1_x86_64 --only-binary :all: --abi cp36m $(cat binary_requirements.txt)
mkdir -p wheelhouse
ls *.whl | xargs -I '{}' -n1 unzip {} -d wheelhouse
rm *.whl
(
  cd wheelhouse
  zip -r ../function.zip *
)
rm -rf wheelhouse
