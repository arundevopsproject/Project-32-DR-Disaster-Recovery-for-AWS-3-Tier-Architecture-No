
# Declare the data source for Availability Zones

data "aws_availability_zones" "available" {
  state = "available"
}

##################################################################################


# NETWORKING #

# VPC

resource "aws_vpc" "my_site_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# Create and attacah an Internet Gateway to VPC

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_site_vpc.id

  tags = local.common_tags

}

# Create Route tables

# Route table for public subnets

resource "aws_route_table" "three-tier-rt-public" {
  vpc_id = aws_vpc.my_site_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = local.common_tags
}

# Route table for private subnets

resource "aws_route_table" "three-tier-rt" {
  vpc_id = aws_vpc.my_site_vpc.id

  tags = local.common_tags
}


# Define public subnet Tier 1 - ALB

resource "aws_subnet" "public_subnet1" {
  cidr_block              = var.public_subnets_cidr_blocks[0]
  vpc_id                  = aws_vpc.my_site_vpc.id
  availability_zone       = slice(data.aws_availability_zones.available.names, 0, 2)[0]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = local.common_tags

}

resource "aws_subnet" "public_subnet2" {
  cidr_block              = var.public_subnets_cidr_blocks[1]
  vpc_id                  = aws_vpc.my_site_vpc.id
  availability_zone       = slice(data.aws_availability_zones.available.names, 0, 2)[1]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = local.common_tags

}


# Define private subnet Tier 1 - Web servers

resource "aws_subnet" "private_subnet1" {
  cidr_block        = var.private_subnets_cidr_blocks[0]
  vpc_id            = aws_vpc.my_site_vpc.id
  availability_zone = slice(data.aws_availability_zones.available.names, 0, 2)[0]

  tags = local.common_tags

}

resource "aws_subnet" "private_subnet2" {
  cidr_block        = var.private_subnets_cidr_blocks[1]
  vpc_id            = aws_vpc.my_site_vpc.id
  availability_zone = slice(data.aws_availability_zones.available.names, 0, 2)[1]

  tags = local.common_tags

}

# Define private subnet Tier 2 - App servers

resource "aws_subnet" "private_subnet3" {
  cidr_block        = var.private_subnets_cidr_blocks[2]
  vpc_id            = aws_vpc.my_site_vpc.id
  availability_zone = slice(data.aws_availability_zones.available.names, 0, 2)[0]

  tags = local.common_tags

}

resource "aws_subnet" "private_subnet4" {
  cidr_block        = var.private_subnets_cidr_blocks[3]
  vpc_id            = aws_vpc.my_site_vpc.id
  availability_zone = slice(data.aws_availability_zones.available.names, 0, 2)[1]

  tags = local.common_tags

}

# Define private subnet Tier 3 - DB instances

resource "aws_subnet" "private_subnet5" {
  cidr_block        = var.private_subnets_cidr_blocks[4]
  vpc_id            = aws_vpc.my_site_vpc.id
  availability_zone = slice(data.aws_availability_zones.available.names, 0, 2)[0]

  tags = local.common_tags

}

resource "aws_subnet" "private_subnet6" {
  cidr_block        = var.private_subnets_cidr_blocks[5]
  vpc_id            = aws_vpc.my_site_vpc.id
  availability_zone = slice(data.aws_availability_zones.available.names, 0, 2)[1]

  tags = local.common_tags

}

###################################################################################

# Route table association Tier 1

resource "aws_route_table_association" "private_sub1_tier1" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.three-tier-rt.id
}

resource "aws_route_table_association" "private_sub2_tier1" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.three-tier-rt.id
}

# Route table association Tier 2

resource "aws_route_table_association" "private_sub1_tier2" {
  subnet_id      = aws_subnet.private_subnet3.id
  route_table_id = aws_route_table.three-tier-rt.id
}

resource "aws_route_table_association" "private_sub2_tier2" {
  subnet_id      = aws_subnet.private_subnet4.id
  route_table_id = aws_route_table.three-tier-rt.id
}

# Route table association Tier 3

resource "aws_route_table_association" "private_sub1_tier3" {
  subnet_id      = aws_subnet.private_subnet5.id
  route_table_id = aws_route_table.three-tier-rt.id
}

resource "aws_route_table_association" "private_sub2_tier3" {
  subnet_id      = aws_subnet.private_subnet6.id
  route_table_id = aws_route_table.three-tier-rt.id
}

# Route table association Tier 1 for public subnets

resource "aws_route_table_association" "public_sub1_tier1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.three-tier-rt-public.id
}

resource "aws_route_table_association" "public_sub2_tier1" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.three-tier-rt-public.id
}


#################################################################################

# Adding VPC endpoint

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.my_site_vpc.id
  service_name        = "com.amazonaws.${var.aws_regions}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
  security_group_ids  = [aws_security_group.endpoint-sg.id]
  private_dns_enabled = true

  tags = local.common_tags
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.my_site_vpc.id
  service_name        = "com.amazonaws.${var.aws_regions}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
  security_group_ids  = [aws_security_group.endpoint-sg.id]
  private_dns_enabled = true

  tags = local.common_tags
}
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.my_site_vpc.id
  service_name        = "com.amazonaws.${var.aws_regions}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
  security_group_ids  = [aws_security_group.endpoint-sg.id]
  private_dns_enabled = true

  tags = local.common_tags
}

##################################################################################

# Security groups

# Security group VPC endpoint

resource "aws_security_group" "endpoint-sg" {
  name        = "endpoint-sg"
  description = "Security group for VPC endpoint"
  vpc_id      = aws_vpc.my_site_vpc.id

  # Outbound EC2 
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  # Allow all outbound traffic (default for endpoints)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# Security group for EC2 tier 1

resource "aws_security_group" "ec2-tier1" {
  name        = "ec2-tier1"
  description = "Security group for EC2 web servers"
  vpc_id      = aws_vpc.my_site_vpc.id

  # Inbound from VPC SSM endpoints
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.endpoint-sg.id]
  }

  # Inbound from ALB tier 1

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb-tier1.id]
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
    prefix_list_ids = [data.aws_prefix_list.s3_prefix.id]

  }
}
# Get the S3 prefix list for the region
data "aws_prefix_list" "s3_prefix" {
  filter {
    name   = "prefix-list-name"
    values = ["com.amazonaws.${var.aws_regions}.s3"]
  }
}

# Security group ALB tier 1

resource "aws_security_group" "alb-tier1" {
  name        = "alb1-sg"
  description = "Security group for ALB web servers allowing my IP and Route 53 healthchecks"
  vpc_id      = aws_vpc.my_site_vpc.id

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
    cidr_blocks = [var.vpc_cidr_block]
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
    cidr_blocks = [var.vpc_cidr_block]
  }
}


##########################################################################

# Security group for EC2 tier 2

resource "aws_security_group" "ec2-tier2" {
  name        = "ec2-tier2"
  description = "Security group for EC2 app servers"
  vpc_id      = aws_vpc.my_site_vpc.id

  # Inbound from and ALB tier 2
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  # Inbound from VPC endpoint
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.endpoint-sg.id]
  }

  # Egress rule for DB tier 3
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = local.common_tags
}

# Security group ALB tier 2

resource "aws_security_group" "alb-tier2" {
  name        = "alb2-sg"
  description = "Security group for ALB app servers"
  vpc_id      = aws_vpc.my_site_vpc.id

  # inbound from ec2 tier 1
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2-tier1.id]
  }

  # outbound to Ec2 instances
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = local.common_tags
}

# Security group DB tier 3 

resource "aws_security_group" "db-tier3" {
  name        = "db-sg"
  description = "Security group for DB instance"
  vpc_id      = aws_vpc.my_site_vpc.id

  # inbound from ec2 tier 2
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2-tier2.id]
  }

  # outbound to Ec2 instances
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = local.common_tags
}
