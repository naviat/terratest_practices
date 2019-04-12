# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A SINGLE INFLUXDB ENTERPRISE CLUSTER
# This is an example of how to deploy an InfluxDB Enterprise cluster on a single server with load
# balancer in front of the data nodes to handle providing the public interface into the cluster.
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  # The AWS region in which all resources will be created
  region = "${var.aws_region}"
}

# ---------------------------------------------------------------------------------------------------------------------
# USE THE PUBLIC EXAMPLE AMIS IF VAR.AMI_ID IS NOT SPECIFIED
# We have published some example AMIs publicly that will be used if var.ami_id is not specified. This makes it easier
# to try these examples out, but we recommend you build your own AMIs for production use.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_ami" "influxdb_ubuntu_example" {
  most_recent = true
  owners      = ["562637147889"] # Gruntwork

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "name"
    values = ["*influxdb-ubuntu-example*"]
  }
}

locals = {
  ami_id = "${var.ami_id == "" ? data.aws_ami.influxdb_ubuntu_example.id : var.ami_id}"
}

module "influxdb" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-influx.git//modules/influxdb-cluster?ref=v0.0.1"
  source = "./modules/influxdb-cluster"

  cluster_name = "${var.influxdb_cluster_name}"
  min_size     = 3
  max_size     = 3

  # We use small instance types to keep these examples cheap to run. In a production setting, you'll probably want
  # R4 or M4 instances.
  instance_type = "t2.micro"

  ami_id    = "${local.ami_id}"
  user_data = "${data.template_file.user_data_influxdb.rendered}"

  vpc_id     = "${data.aws_vpc.default.id}"
  subnet_ids = "${data.aws_subnet_ids.default.ids}"

  ebs_block_devices = [
    {
      device_name = "${var.volume_device_name}"
      volume_type = "gp2"
      volume_size = 50
    },
  ]

  # To make testing easier, we allow SSH requests from any IP address here. In a production deployment, we strongly
  # recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  allowed_ssh_cidr_blocks = ["0.0.0.0/0"]

  ssh_key_name = "${var.ssh_key_name}"

  # To make it easy to test this example from your computer, we allow the InfluxDB servers to have public IPs. In a
  # production deployment, you'll probably want to keep all the servers in private subnets with only private IPs.
  associate_public_ip_address = true

  # An example of custom tags
  tags = [
    {
      key                 = "Environment"
      value               = "development"
      propagate_at_launch = true
    },
    {
      key                 = "NodeType"
      value               = "both"
      propagate_at_launch = true
    },
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE USER DATA SCRIPTS THAT WILL RUN ON EACH INSTANCE IN THE VARIOUS CLUSTERS ON BOOT
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data_influxdb" {
  template = "${file("${path.module}/influxdb-cluster-simple/user-data/user-data.sh")}"

  vars {
    cluster_asg_name = "${var.influxdb_cluster_name}"
    aws_region       = "${var.aws_region}"
    license_key      = "${var.license_key}"
    shared_secret    = "${var.shared_secret}"

    # Pass in the data about the EBS volumes so they can be mounted
    volume_device_name = "${var.volume_device_name}"
    volume_mount_point = "${var.volume_mount_point}"
    volume_owner       = "${var.volume_owner}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE SECURITY GROUP RULES FOR INFLUXDB
# This controls which ports are exposed and who can connect to them
# ---------------------------------------------------------------------------------------------------------------------

module "influxdb_security_group_rules" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-influx.git//modules/influxdb-security-group-rules?ref=v0.0.1"
  source = "./modules/influxdb-security-group-rules"

  security_group_id = "${module.influxdb.security_group_id}"

  raft_port = 8089
  rest_port = 8091
  tcp_port  = 8088
  api_port  = 8086

  # To keep this example simple, we allow these ports to be accessed from any IP. In a production
  # deployment, you may want to lock these down just to trusted servers.
  raft_port_cidr_blocks = ["0.0.0.0/0"]

  rest_port_cidr_blocks = ["0.0.0.0/0"]
  tcp_port_cidr_blocks  = ["0.0.0.0/0"]
  api_port_cidr_blocks  = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH IAM POLICIES TO EACH CLUSTER
# These policies allow the clusters to automatically bootstrap themselves
# ---------------------------------------------------------------------------------------------------------------------

module "influxdb_iam_policies" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-influx.git//modules/influxdb-iam-policies?ref=v0.0.1"
  source = "./modules/influxdb-iam-policies"

  iam_role_id = "${module.influxdb.iam_role_id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A LOAD BALANCER FOR THE CLUSTERS
# ---------------------------------------------------------------------------------------------------------------------

module "load_balancer" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-influx.git//modules/load-balancer?ref=v0.0.1"
  source = "./modules/load-balancer"

  name       = "${var.influxdb_cluster_name}-lb"
  vpc_id     = "${data.aws_vpc.default.id}"
  subnet_ids = "${data.aws_subnet_ids.default.ids}"

  http_listener_ports = [8086]

  # To make testing easier, we allow inbound connections from any IP. In production usage, you may want to only allow
  # connectsion from certain trusted servers, or even use an internal load balancer, so it's only accessible from
  # within the VPC

  allow_inbound_from_cidr_blocks = ["0.0.0.0/0"]
  idle_timeout                   = 3600
}

module "influxdb_target_group" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-influx.git//modules/load-balancer-target-group?ref=v0.0.1"
  source = "./modules/load-balancer-target-group"

  target_group_name    = "${var.influxdb_cluster_name}-tg"
  asg_name             = "${module.influxdb.asg_name}"
  port                 = "${module.influxdb_security_group_rules.api_port}"
  health_check_path    = "/ping"
  health_check_matcher = "204"
  vpc_id               = "${data.aws_vpc.default.id}"

  listener_arns                   = ["${lookup(module.load_balancer.http_listener_arns, 8086)}"]
  listener_arns_num               = 1
  listener_rule_starting_priority = 100
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY INFLUXDB IN THE DEFAULT VPC AND SUBNETS
# Using the default VPC and subnets makes this example easy to run and test, but it means InfluxDB is accessible from
# the public Internet. For a production deployment, we strongly recommend deploying into a custom VPC with private
# subnets.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}
