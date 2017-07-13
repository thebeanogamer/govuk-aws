# == Module: aws::elasticache_redis_cluster
#
# Create a redis replication cluster and elasticache subnet group
#
# === Variables:
#
# subnet_ids
# security_group_ids
#
# === Outputs:
#
#

variable "name" {
  type        = "string"
  description = "The common name for all the resources created by this module"
}

variable "subnet_ids" {
  type        = "list"
  description = "Subnet IDs to assign to the aws_elasticache_subnet_group"
}

variable "default_tags" {
  type        = "map"
  description = "Additional resource tags"
  default     = {}
}

variable "elasticache_node_type" {
  type        = "string"
  description = "The node type to use. Must not be t.* in order to use failover."
  default     = "cache.m3.medium"
}

variable "security_group_ids" {
  type        = "list"
  description = "Security group IDs to apply to this cluster"
}

# Resources
# --------------------------------------------------------------

resource "aws_elasticache_subnet_group" "redis_cluster_subnet_group" {
  name       = "${var.name}"
  subnet_ids = ["${var.subnet_ids}"]
}

resource "aws_elasticache_replication_group" "redis_cluster" {
  # replication_group_id          = "${length(var.name) > 20 ? substr(var.name, 0, 20) : var.name}"
  replication_group_id          = "${var.name}"
  replication_group_description = "${var.name} redis cluster"
  node_type                     = "${var.elasticache_node_type}"
  port                          = 6379
  parameter_group_name          = "default.redis3.2.cluster.on"
  automatic_failover_enabled    = true

  subnet_group_name  = "${aws_elasticache_subnet_group.redis_cluster_subnet_group.name}"
  security_group_ids = ["${var.security_group_ids}"]

  tags = "${merge(var.default_tags, map("Name", var.name))}"

  cluster_mode {
    replicas_per_node_group = 1
    num_node_groups         = 1
  }
}

# Outputs
#--------------------------------------------------------------

output "configuration_endpoint_address" {
  value       = "${aws_elasticache_replication_group.redis_cluster.configuration_endpoint_address}"
  description = "Configuration endpoint address of the redis cluster"
}
