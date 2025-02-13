

##################################################################################


# NETWORKING #

# VPC

resource "aws_vpc" "recovery_site_vpc" {
  cidr_block           = var.recovery_cidr_block
  provider             = aws.backup
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.recovery_tags
}

# Create and attach an Internet Gateway to VPC

resource "aws_internet_gateway" "recovery_gw" {
  vpc_id   = aws_vpc.recovery_site_vpc.id
  provider = aws.backup

  tags = local.recovery_tags

}

# Create Route tables

# Route table for public subnets

resource "aws_route_table" "recovery_three-tier-rt-public" {
  vpc_id   = aws_vpc.recovery_site_vpc.id
  provider = aws.backup

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.recovery_gw.id
  }

  tags = local.recovery_tags
}

# Route table for private subnets

resource "aws_route_table" "recovery_three-tier-rt" {
  vpc_id   = aws_vpc.recovery_site_vpc.id
  provider = aws.backup
}

# Define public subnet Tier 1 - ALB

resource "aws_subnet" "recovery_public_subnet1" {
  cidr_block              = var.recovery_public_subnets_cidr_blocks[0]
  vpc_id                  = aws_vpc.recovery_site_vpc.id
  provider                = aws.backup
  availability_zone       = slice(data.aws_availability_zones.recovery_available.names, 0, 2)[0]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = local.recovery_tags

  depends_on = [aws_route_table.recovery_three-tier-rt-public]

}

resource "aws_subnet" "recovery_public_subnet2" {
  cidr_block              = var.recovery_public_subnets_cidr_blocks[1]
  vpc_id                  = aws_vpc.recovery_site_vpc.id
  provider                = aws.backup
  availability_zone       = slice(data.aws_availability_zones.recovery_available.names, 0, 2)[1]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = local.recovery_tags

  depends_on = [aws_route_table.recovery_three-tier-rt-public]
}


# Define private subnet Tier 1 - Web servers

resource "aws_subnet" "recovery_private_subnet1" {
  cidr_block        = var.recovery_private_subnets_cidr_blocks[0]
  vpc_id            = aws_vpc.recovery_site_vpc.id
  provider          = aws.backup
  availability_zone = slice(data.aws_availability_zones.recovery_available.names, 0, 2)[0]

  tags = local.recovery_tags

  depends_on = [aws_route_table.recovery_three-tier-rt]
}

resource "aws_subnet" "recovery_private_subnet2" {
  cidr_block        = var.recovery_private_subnets_cidr_blocks[1]
  vpc_id            = aws_vpc.recovery_site_vpc.id
  provider          = aws.backup
  availability_zone = slice(data.aws_availability_zones.recovery_available.names, 0, 2)[1]

  tags = local.recovery_tags

  depends_on = [aws_route_table.recovery_three-tier-rt]

}

# Define private subnet Tier 2 - App servers

resource "aws_subnet" "recovery_private_subnet3" {
  cidr_block        = var.recovery_private_subnets_cidr_blocks[2]
  vpc_id            = aws_vpc.recovery_site_vpc.id
  provider          = aws.backup
  availability_zone = slice(data.aws_availability_zones.recovery_available.names, 0, 2)[0]

  tags = local.recovery_tags

  depends_on = [aws_route_table.recovery_three-tier-rt]

}

resource "aws_subnet" "recovery_private_subnet4" {
  cidr_block        = var.recovery_private_subnets_cidr_blocks[3]
  vpc_id            = aws_vpc.recovery_site_vpc.id
  provider          = aws.backup
  availability_zone = slice(data.aws_availability_zones.recovery_available.names, 0, 2)[1]

  tags = local.recovery_tags

  depends_on = [aws_route_table.recovery_three-tier-rt]

}

# Define private subnet Tier 3 - DB instances

resource "aws_subnet" "recovery_private_subnet5" {
  cidr_block        = var.recovery_private_subnets_cidr_blocks[4]
  vpc_id            = aws_vpc.recovery_site_vpc.id
  provider          = aws.backup
  availability_zone = slice(data.aws_availability_zones.recovery_available.names, 0, 2)[0]

  tags = local.recovery_tags

  depends_on = [aws_route_table.recovery_three-tier-rt]

}

resource "aws_subnet" "recovery_private_subnet6" {
  cidr_block        = var.recovery_private_subnets_cidr_blocks[5]
  vpc_id            = aws_vpc.recovery_site_vpc.id
  provider          = aws.backup
  availability_zone = slice(data.aws_availability_zones.recovery_available.names, 0, 2)[1]

  tags = local.recovery_tags

  depends_on = [aws_route_table.recovery_three-tier-rt]

}

###################################################################################

# Route table association Tier 1

resource "aws_route_table_association" "recovery_private_sub1_tier1" {
  subnet_id      = aws_subnet.recovery_private_subnet1.id
  route_table_id = aws_route_table.recovery_three-tier-rt.id
  provider       = aws.backup

  depends_on = [aws_subnet.recovery_private_subnet1, aws_route_table.recovery_three-tier-rt]
}

resource "aws_route_table_association" "recovery_private_sub2_tier1" {
  subnet_id      = aws_subnet.recovery_private_subnet2.id
  route_table_id = aws_route_table.recovery_three-tier-rt.id
  provider       = aws.backup

  depends_on = [aws_subnet.recovery_private_subnet2, aws_route_table.recovery_three-tier-rt]
}

# Route table association Tier 2

resource "aws_route_table_association" "recovery_private_sub1_tier2" {
  subnet_id      = aws_subnet.recovery_private_subnet3.id
  route_table_id = aws_route_table.recovery_three-tier-rt.id
  provider       = aws.backup

  depends_on = [aws_subnet.recovery_private_subnet3, aws_route_table.recovery_three-tier-rt]
}

resource "aws_route_table_association" "recovery_private_sub2_tier2" {
  subnet_id      = aws_subnet.recovery_private_subnet4.id
  route_table_id = aws_route_table.recovery_three-tier-rt.id
  provider       = aws.backup

  depends_on = [aws_subnet.recovery_private_subnet4, aws_route_table.recovery_three-tier-rt]
}

# Route table association Tier 3

resource "aws_route_table_association" "recovery_private_sub1_tier3" {
  subnet_id      = aws_subnet.recovery_private_subnet5.id
  route_table_id = aws_route_table.recovery_three-tier-rt.id
  provider       = aws.backup

  depends_on = [aws_subnet.recovery_private_subnet5, aws_route_table.recovery_three-tier-rt]
}

resource "aws_route_table_association" "recovery_private_sub2_tier3" {
  subnet_id      = aws_subnet.recovery_private_subnet6.id
  route_table_id = aws_route_table.recovery_three-tier-rt.id
  provider       = aws.backup

  depends_on = [aws_subnet.recovery_private_subnet6, aws_route_table.recovery_three-tier-rt]
}

# Route table association Tier 1 for public subnets

resource "aws_route_table_association" "recovery_public_sub1_tier1" {
  subnet_id      = aws_subnet.recovery_public_subnet1.id
  route_table_id = aws_route_table.recovery_three-tier-rt-public.id
  provider       = aws.backup

  depends_on = [aws_subnet.recovery_public_subnet1, aws_route_table.recovery_three-tier-rt-public]
}

resource "aws_route_table_association" "recovery_public_sub2_tier1" {
  subnet_id      = aws_subnet.recovery_public_subnet2.id
  route_table_id = aws_route_table.recovery_three-tier-rt-public.id
  provider       = aws.backup

  depends_on = [aws_subnet.recovery_public_subnet2, aws_route_table.recovery_three-tier-rt-public]
}


#################################################################################

# Adding VPC Interface endpoint for SSM

resource "aws_vpc_endpoint" "recovery_ssm" {
  vpc_id              = aws_vpc.recovery_site_vpc.id
  provider            = aws.backup
  service_name        = "com.amazonaws.${var.aws_secondary_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.recovery_private_subnet1.id, aws_subnet.recovery_private_subnet2.id]
  security_group_ids  = [aws_security_group.recovery_endpoint-sg.id]
  private_dns_enabled = true

  tags = local.recovery_tags
}

resource "aws_vpc_endpoint" "recovery_ec2messages" {
  vpc_id              = aws_vpc.recovery_site_vpc.id
  provider            = aws.backup
  service_name        = "com.amazonaws.${var.aws_secondary_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.recovery_private_subnet1.id, aws_subnet.recovery_private_subnet2.id]
  security_group_ids  = [aws_security_group.recovery_endpoint-sg.id]
  private_dns_enabled = true

  tags = local.recovery_tags
}
resource "aws_vpc_endpoint" "recovery_ssmmessages" {
  vpc_id              = aws_vpc.recovery_site_vpc.id
  provider            = aws.backup
  service_name        = "com.amazonaws.${var.aws_secondary_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.recovery_private_subnet1.id, aws_subnet.recovery_private_subnet2.id]
  security_group_ids  = [aws_security_group.recovery_endpoint-sg.id]
  private_dns_enabled = true

  tags = local.recovery_tags
}

# VPC Interface endpoint for STS

resource "aws_vpc_endpoint" "recovery_sts" {
  vpc_id              = aws_vpc.recovery_site_vpc.id
  provider            = aws.backup
  service_name        = "com.amazonaws.us-west-1.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.recovery_private_subnet1.id, aws_subnet.recovery_private_subnet2.id]
  security_group_ids  = [aws_security_group.recovery_endpoint-sg.id]
  private_dns_enabled = true

  tags = local.recovery_tags
}


##################################################################################

# Security groups

# Security group for SSM and STS VPC endpoint

resource "aws_security_group" "recovery_endpoint-sg" {
  name        = "recovery_endpoint-sg"
  description = "Security group for VPC endpoint"
  vpc_id      = aws_vpc.recovery_site_vpc.id
  provider    = aws.backup

  # Outbound EC2 
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.recovery_cidr_block]
  }

  # Allow all outbound traffic (default for endpoints)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.recovery_tags
}

# Security group for EC2 tier 1

resource "aws_security_group" "recovery_ec2-tier1" {
  name        = "ec2-tier1"
  description = "Security group for EC2 web servers"
  vpc_id      = aws_vpc.recovery_site_vpc.id
  provider    = aws.backup

  # Inbound from VPC SSM endpoints
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.recovery_endpoint-sg.id]
  }

  # Inbound from ALB tier 1

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.recovery_alb-tier1.id]
  }

  # Allow all outbound traffic within the VPC
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS to S3 VPC endpoint
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.s3_prefix_recov.id]

  }
}
# Get the S3 prefix list for the region
data "aws_prefix_list" "s3_prefix_recov" {
  provider = aws.backup
  filter {
    name   = "prefix-list-name"
    values = ["com.amazonaws.us-west-1.s3"]
  }
}

# Security group ALB tier 1

resource "aws_security_group" "recovery_alb-tier1" {
  name        = "alb1-sg"
  description = "Security group for ALB web servers allowing my IP and Route 53 healthchecks"
  vpc_id      = aws_vpc.recovery_site_vpc.id
  provider    = aws.backup

  # Inbound traffic from external sources
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = data.aws_ip_ranges.route53_healthchecks.cidr_blocks
  }

  # Allow my IP on port 443
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.recovery_cidr_block]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.recovery_cidr_block]
  }
}


##########################################################################

# Security group for EC2 tier 2

resource "aws_security_group" "recovery_ec2-tier2" {
  name        = "ec2-tier2"
  description = "Security group for EC2 app servers"
  vpc_id      = aws_vpc.recovery_site_vpc.id
  provider    = aws.backup

  # Inbound from and ALB tier 2
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.recovery_cidr_block]
  }

  # Inbound from VPC endpoint
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.recovery_endpoint-sg.id]
  }


  # Egress rule for DB tier 3
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = local.recovery_tags
}

# Security group ALB tier 2

resource "aws_security_group" "recovery_alb-tier2" {
  name        = "alb2-sg"
  description = "Security group for ALB app servers"
  vpc_id      = aws_vpc.recovery_site_vpc.id
  provider    = aws.backup

  # inbound from ec2 tier 1
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.recovery_ec2-tier1.id]
  }

  # outbound to Ec2 instances
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.recovery_cidr_block]
  }

  tags = local.recovery_tags
}

# Security group DB tier 3 

resource "aws_security_group" "recovery_db-tier3" {
  name        = "db-sg"
  description = "Security group for DB instance"
  vpc_id      = aws_vpc.recovery_site_vpc.id
  provider    = aws.backup

  # inbound from ec2 tier 2
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.recovery_ec2-tier2.id]
  }

  # outbound to Ec2 instances
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.recovery_cidr_block]
  }

  tags = local.recovery_tags
}
