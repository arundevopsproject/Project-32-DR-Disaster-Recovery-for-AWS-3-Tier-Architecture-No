variable "aws_regions" {
  type        = string
  description = "Regions to use for AWS resources"
  default     = "us-east-1"
}

variable "aws_secondary_region" {
  type        = string
  description = "Regions to use for AWS resources"
  default     = "us-west-1"
}

variable "vpc_cidr_block" {
  type        = string
  description = "Base CIDR block for my_site_vpc"
  default     = "10.0.0.0/16"
}

variable "recovery_cidr_block" {
  type        = string
  description = "Base CIDR block for my_site_vpc"
  default     = "10.1.0.0/16"
}

variable "public_subnets_cidr_blocks" {
  type        = list(string)
  description = "Cidr blocks for 2 public subnets"
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "recovery_public_subnets_cidr_blocks" {
  type        = list(string)
  description = "Cidr blocks for 2 public subnets"
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}

variable "private_subnets_cidr_blocks" {
  type        = list(string)
  description = "Cidr blocks for 6 private subnets"
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
}

variable "recovery_private_subnets_cidr_blocks" {
  type        = list(string)
  description = "Cidr blocks for 6 private subnets"
  default     = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24", "10.1.4.0/24", "10.1.5.0/24"]
}
variable "vpc_public_subnet_count" {
  type        = number
  description = "Number of public subnets to create"
  default     = 2
}

variable "vpc_private_subnet_count" {
  type        = number
  description = "Number of private subnets to create"
  default     = 6
}


variable "instance_type" {
  type        = string
  description = "Type of the EC2 instance"
  default     = "t2.micro"
}

variable "company" {
  type        = string
  description = "Company name for the resource tagging"
  default     = "ThreadCraft"
}

variable "project" {
  type        = string
  description = "Project name for resource tagging"
  default     = "3-tier-architecture"
}

variable "name" {
  type        = string
  description = "The base name for resources."
  default     = "app1"
}

variable "tier1_sg" {
  type        = list(string)
  description = "Security groups for tier1"
  default     = ["endpoint-sg", "ec2-tier1", "alb-tier1", "asg-sg1"]
}

variable "tier1_subnets" {
  type        = list(string)
  description = "Subnets for tier1"
  default     = ["private_subnet1", "private_subnet2"]
}

variable "db_name" {
  type        = string
  description = "Name for DB tier 3"
  default     = "ThreadCraftDB"
}

variable "db_engine_version" {
  type        = string
  description = "MySQL engine version for DB tier 3"
  default     = "8.0.mysql_aurora.3.05.2"
}

variable "db_instance_type" {
  type        = string
  description = "Instance type for DB tier 3"
  default     = "db.r6g.large"
}

variable "db_username" {
  type        = string
  description = "Username for DB tier 3"
  default     = ""
}

variable "db_password" {
  type        = string
  description = "Password for DB tier 3"
  default     = ""
}

variable "db_parameter_group" {
  type        = string
  description = "Configuration settings for DB engine"
  default     = "default.mysql8.0"
}


variable "bucket_name" {
  type        = string
  description = "Name of the bucket"
  default     = "thread-bucket-"
}

variable "account_id" {
  type        = string
  description = "account id"
  default     = ""
}


variable "domain_name_alb" {
  type        = string
  description = "domain name for alb"
  default     = "threadcraft.link"
}


variable "hosted_zone_name" {
  type        = string
  description = "DNS hosted zone name"
  default     = "threadcraft.link"
}


variable "map_public_ip_on_launch" {
  type        = bool
  description = "Map a public IP address for Subnet instances"
  default     = true
}

variable "custom_ami" {
  type        = string
  description = "Custom AMI to launch Apache web server"
  default     = "Apache_server"
}

variable "sql_ami" {
  type        = string
  description = "Custom AMI to launch sql server"
  default     = "mysql_server2"
}

variable "email" {
  type        = string
  description = "email address for sns"
  default     = ""
}

variable "backup_vault" {
  type        = string
  description = "Name for backup vault"
  default     = "backup-vault"
}

variable "backup_vault2" {
  type        = string
  description = "Name for backup vault for the secondary region"
  default     = "backup-vault2"
}

variable "bucket_name_west" {
  type        = string
  description = "Name for destination S3 cross region replication"
  default     = "thread-craft-replication-"
}

