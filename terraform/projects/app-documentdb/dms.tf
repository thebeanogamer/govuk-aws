data "aws_iam_policy_document" "dms_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["dms.amazonaws.com"]
      type        = "Service"
    }
  }
}

# Create a new certificate
resource "aws_dms_certificate" "documentdb-cert" {
  certificate_id  = "documentdb-cert"
  certificate_pem = "${file("${path.module}/rds-combined-ca-bundle.pem")}"
}

resource "aws_iam_role" "dms-cloudwatch-logs-role" {
  assume_role_policy = "${data.aws_iam_policy_document.dms_assume_role.json}"
  name               = "dms-cloudwatch-logs-role"
}

resource "aws_iam_role_policy_attachment" "dms-cloudwatch-logs-role-AmazonDMSCloudWatchLogsRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
  role       = "${aws_iam_role.dms-cloudwatch-logs-role.name}"
}

resource "aws_iam_role" "dms-vpc-role" {
  assume_role_policy = "${data.aws_iam_policy_document.dms_assume_role.json}"
  name               = "dms-vpc-role"
}

resource "aws_iam_role_policy_attachment" "dms-vpc-role-AmazonDMSVPCManagementRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
  role       = "${aws_iam_role.dms-vpc-role.name}"
}

# Create a new replication instance
resource "aws_dms_replication_instance" "router-documentdb-replication-instance" {
  allocated_storage            = 20
  replication_subnet_group_id  = "${aws_dms_replication_subnet_group.dms-subnet-group.id}"
  apply_immediately            = true
  engine_version              = "3.1.4"
  auto_minor_version_upgrade   = true
  availability_zone            = "eu-west-1a"
  multi_az                     = false
  publicly_accessible          = false
  replication_instance_class   = "dms.t2.micro"
  replication_instance_id      = "router-documentdb-replication-instance"

  tags = {
    Name = "router-documentdb-replication-instance"
  }

  vpc_security_group_ids = [
    "${data.terraform_remote_state.infra_security_groups.sg_documentdb_id}",
    "${data.terraform_remote_state.infra_security_groups.sg_mongo_id}",
  ]
}

# Create a new endpoint
resource "aws_dms_endpoint" "router-mongo-source-endpoint" {
  database_name               = "router"
  endpoint_id                 = "router-backend-mongo"
  endpoint_type               = "source"
  engine_name                 = "mongodb"
  extra_connection_attributes = "authType=NO"
  port                        = 27017
  server_name                 = "router-backend-2.blue.integration.govuk-internal.digital"
  ssl_mode                    = "none"
  username                    = "notused"
  password                    = "notused"

  tags = {
    Name = "router-backend-mongo"
  }

}

# Create a new target endpoint
resource "aws_dms_endpoint" "router-documentdb-target-endpoint" {
  certificate_arn             = "${aws_dms_certificate.documentdb-cert.certificate_arn}"
  database_name               = "router"
  endpoint_id                 = "router-documentdb"
  endpoint_type               = "target"
  engine_name                 = "docdb"
  port                        = 27017
  server_name                 = "${aws_docdb_cluster.cluster.endpoint}"
  ssl_mode                    = "verify-full"
  username                    = "${var.master_username}"
  password                    = "${var.master_password}"

  tags = {
    Name = "router-backend-mongo"
  }

}

# Create a new replication subnet group
resource "aws_dms_replication_subnet_group" "dms-subnet-group" {
  replication_subnet_group_description = "DMS subnet group"
  replication_subnet_group_id          = "dms-subnet-group"

  subnet_ids = [
    "${data.terraform_remote_state.infra_networking.private_subnet_ids}"
  ]

  tags = {
    Name = "dms-subnet-group"
  }
}
