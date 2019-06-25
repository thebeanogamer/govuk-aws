/**
* ## Project: infra-download-logs-analytics
*
* Manages to movement of Download logs from S3 to Google Analytics.
*/
variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

variable "aws_environment" {
  type        = "string"
  description = "AWS Environment"
}

variable "stackname" {
  type        = "string"
  description = "Stackname"
}

# Resources
# --------------------------------------------------------------
terraform {
  backend          "s3"             {}
}

provider "aws" {
  region  = "${var.aws_region}"
  version = "1.60.0"
}

resource "aws_lambda_function" "assets_logs_executor" {
  filename      = "../../lambda/DownloadLogsAnalytics/function.zip"
  function_name = "SendAssetLogsToGA-${var.aws_environment}"
  role          = "${aws_iam_role.assets_logs_executor.arn}"
  handler       = "main.lambda_handler"
  runtime       = "python3.7"
}

resource "aws_iam_role" "assets_logs_executor" {
  name = "AWSLambdaRole-assets-logs-executor"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "assets_logs_executor" {
  name   = "fastly-logs-${var.aws_environment}-assets-logs-executor-policy"
  policy = "${data.template_file.assets_logs_executor_policy_template.rendered}"
}

resource "aws_iam_role_policy_attachment" "assets_logs_executor" {
  role       = "${aws_iam_role.assets_logs_executor.name}"
  policy_arn = "${aws_iam_policy.assets_logs_executor.arn}"
}

data "template_file" "assets_logs_executor_policy_template" {
  template = "${file("${path.module}/../../policies/assets_logs_executor_policy.tpl")}"

  vars {
    bucket_arn = "arn:aws:s3:::govuk-analytics-logs-${var.aws_environment}"
  }
}

resource "aws_s3_bucket_notification" "bucket_terraform_notification" {
    bucket = "govuk-analytics-logs-${var.aws_environment}"
    lambda_function {
        lambda_function_arn = "${aws_lambda_function.assets_logs_executor.arn}"
        events = ["s3:ObjectCreated:*"]
        filter_prefix = "govuk_assets/"
    }
}

resource "aws_lambda_permission" "allow_terraform_bucket" {
    statement_id = "AllowExecutionFromS3Bucket"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.assets_logs_executor.arn}"
    principal = "s3.amazonaws.com"
    source_arn = "arn:aws:s3:::govuk-analytics-logs-${var.aws_environment}"
}
