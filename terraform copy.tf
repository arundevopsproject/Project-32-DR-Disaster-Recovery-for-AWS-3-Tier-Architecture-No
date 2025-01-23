terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider Primary region
provider "aws" {
  profile = ""
  region  = var.aws_regions
}

# Configure the AWS Provider Secondary region
provider "aws" {
  alias   = "backup"
  profile = ""
  region  = var.aws_secondary_region
}