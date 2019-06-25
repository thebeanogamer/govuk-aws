## Download and send analytics logs to GA

This lambda function downloads logs from an S3 bucket and sends them off to google analytics. It runs automatically every 10 minutes.

Original Source: https://github.com/alphagov/govuk-lambda-app-deployment/tree/master/download-lambda-logs

Run `build.sh` to download dependencies and package the python code into a `.zip` file. Ensure this runs successfully locally before committing any finished changes ready for terraforming. 
