#!/bin/bash

start_index=27
index=1
for project in $(ls terraform/projects/ | grep infra); do
 if [ ${index} -lt ${start_index} ]; then
   index=$((index+1))
   continue
 fi

 echo "planning ${project}"
 index=$((index+1))
 if [ "infra-ukcloud-vpn" == ${project} ]; then
   continue
 fi
 aws-vault exec govuk-integration -- tools/build-terraform-project.sh -c plan -p ${project} -d ../govuk-aws-data/data -e integration -s govuk       
done 
