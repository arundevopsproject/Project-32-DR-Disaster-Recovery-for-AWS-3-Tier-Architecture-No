data "aws_ssm_parameter" "amzn2_linux" {
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
  provider = aws.backup
}

# Ec2 policy
# create a aws_iam_role Terraform resource with an assume_role_policy for the ec2.amazonaws.com principal

data "aws_iam_policy_document" "recov_ec2_assume_role" {
  provider = aws.backup
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }

}

resource "aws_iam_role" "recov_ec2_role" {
  provider           = aws.backup
  name               = "recov_ec2_role"
  assume_role_policy = data.aws_iam_policy_document.recov_ec2_assume_role.json
}

# Attach the AmazonSSMManagedInstanceCore managed policy to the role

resource "aws_iam_role_policy_attachment" "recov_test_attach" {
  provider   = aws.backup
  role       = aws_iam_role.recov_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# create the aws_iam_instance_profile role from the aws_iam_role

resource "aws_iam_instance_profile" "recov_ec2_profile" {
  provider = aws.backup
  name     = "recov_ec2_profile"
  role     = aws_iam_role.recov_ec2_role.name
}

# attach the iam_instance_profile to the EC2 instance.
#iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

# IAM Policy for EC2 to Access S3

data "aws_iam_policy_document" "recov_ec2_s3_access" {
  provider = aws.backup
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.thread_craft_west.arn}",
      "${aws_s3_bucket.thread_craft_west.arn}/*"
    ]
  }

}

resource "aws_iam_policy" "recov_ec2_s3_policy" {
  provider = aws.backup
  name     = "recov_ec2_s3_access_policy"
  policy   = data.aws_iam_policy_document.recov_ec2_s3_access.json
}

resource "aws_iam_role_policy_attachment" "recov_ec2_s3_policy_attach" {
  provider   = aws.backup
  role       = aws_iam_role.recov_ec2_role.name
  policy_arn = aws_iam_policy.recov_ec2_s3_policy.arn
}

########################################################################## 

# Tier 1 - web servers

# Create a new ASG Target Group attachment
resource "aws_autoscaling_attachment" "recov_asg-tier1" {
  provider               = aws.backup
  autoscaling_group_name = aws_autoscaling_group.recov_asg-tier1.id
  lb_target_group_arn    = aws_lb_target_group.recov_first-tiertg.arn
}

# Autoscaling group tier 1

resource "aws_placement_group" "recov_webservers" {
  provider = aws.backup
  name     = "recov-webservers"
  strategy = "spread"

  tags = local.recovery_tags
}

resource "aws_autoscaling_group" "recov_asg-tier1" {
  provider                  = aws.backup
  name                      = "recov-threadcraft"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 600
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  placement_group           = aws_placement_group.recov_webservers.id
  vpc_zone_identifier       = [aws_subnet.recovery_private_subnet1.id, aws_subnet.recovery_private_subnet2.id]
  launch_template {
    id      = aws_launch_template.recov_thread-web.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.recov_first-tiertg.arn]

}

# launch template

resource "aws_launch_template" "recov_thread-web" {
  provider               = aws.backup
  name_prefix            = "recov-thread-web"
  image_id               = data.aws_ssm_parameter.amzn2_linux.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.recovery_ec2-tier1.id]
  user_data = base64encode(<<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

aws s3 cp s3://${aws_s3_bucket.thread_craft_west.id}/index.html /var/www/html/index.html


EOF
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.recov_ec2_profile.name
  }

  tags = {
    Environment = "production"
    Name        = "Webservers"
  }
}

########################################################################## 

# Tier 2 - app servers

# Create a new ASG Target Group attachment
resource "aws_autoscaling_attachment" "recov_asg-tier2" {
  provider               = aws.backup
  autoscaling_group_name = aws_autoscaling_group.recov_asg-tier2.id
  lb_target_group_arn    = aws_lb_target_group.recov_second-tiertg.arn
}

# Autoscaling group tier 2

resource "aws_placement_group" "recov_appservers" {
  provider = aws.backup
  name     = "recov-appservers"
  strategy = "spread"

  tags = local.recovery_tags
}

resource "aws_autoscaling_group" "recov_asg-tier2" {
  provider                  = aws.backup
  name                      = "recov-threadcraft2"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 600
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  placement_group           = aws_placement_group.recov_appservers.id
  vpc_zone_identifier       = [aws_subnet.recovery_private_subnet3.id, aws_subnet.recovery_private_subnet4.id]
  launch_template {
    id      = aws_launch_template.recov_thread-app.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.recov_second-tiertg.arn]

}

# launch template

resource "aws_launch_template" "recov_thread-app" {
  provider               = aws.backup
  name_prefix            = "recov-thread-app"
  image_id               = data.aws_ssm_parameter.amzn2_linux.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.recovery_ec2-tier2.id]
  user_data = base64encode(<<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

aws s3 cp s3://${aws_s3_bucket.thread_craft_west.id}/index.html /var/www/html/index.html


EOF
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.recov_ec2_profile.name
  }

  tags = {
    Environment = "recproduction"
    Name        = "recAppservers"
  }

}

#########################################################################

# Load Balancers

# aws_lb tier 1 

resource "aws_lb" "recov_alb-tier1" {
  provider           = aws.backup
  name               = "recov-alb-webservers"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.recovery_alb-tier1.id]
  subnets            = [aws_subnet.recovery_public_subnet1.id, aws_subnet.recovery_public_subnet2.id]

  enable_deletion_protection = false
  tags                       = local.recovery_tags
}

# target group ALB

resource "aws_lb_target_group" "recov_first-tiertg" {
  provider = aws.backup
  name     = "recov-first-tier-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.recovery_site_vpc.id

  tags = local.recovery_tags

  health_check {
    protocol            = "HTTP"
    path                = "/index.html"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2

  }
}

# aws_lb_listener

resource "aws_lb_listener" "recov_first-tierlsn" {
  provider          = aws.backup
  load_balancer_arn = aws_lb.recov_alb-tier1.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.thread_cert_dr.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.recov_first-tiertg.arn
  }

  tags = local.recovery_tags
}


##########################################################################

# aws_lb tier 2

resource "aws_lb" "recov_alb-tier2" {
  provider           = aws.backup
  name               = "recov-alb-appservers"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.recovery_alb-tier2.id]
  subnets            = [aws_subnet.recovery_private_subnet3.id, aws_subnet.recovery_private_subnet4.id]

  enable_deletion_protection = false # Terraform will be able to delete the ALB

  tags = local.recovery_tags
}

# target group ALB

resource "aws_lb_target_group" "recov_second-tiertg" {
  provider = aws.backup
  name     = "recov-second-tier-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.recovery_site_vpc.id

  health_check {
    protocol            = "HTTP"
    path                = "/index.html"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2

  }

  tags = local.recovery_tags

}


# aws_lb_listener

resource "aws_lb_listener" "recov_second-tierlsn" {
  provider          = aws.backup
  load_balancer_arn = aws_lb.recov_alb-tier2.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.recov_second-tiertg.arn
  }

  tags = local.recovery_tags
}