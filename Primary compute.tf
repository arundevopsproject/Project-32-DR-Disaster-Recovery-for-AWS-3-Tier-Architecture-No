# aws_lb tier 1 

resource "aws_lb" "alb-tier1" {
  name               = "alb-webservers"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-tier1.id]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]

  enable_deletion_protection = false # Terraform will be able to delete the ALB

  tags = local.common_tags
}

# Create the association between WAF alb web acl and ALB first tier

#resource "aws_wafv2_web_acl_association" "alb_association" {
#resource_arn = aws_lb.alb-tier1.arn
#web_acl_arn  = aws_wafv2_web_acl.alb_web_acl.arn
#}

# target group ALB

resource "aws_lb_target_group" "first-tiertg" {
  name     = "first-tier-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_site_vpc.id

  tags = local.common_tags

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

resource "aws_lb_listener" "first-tierlsn" {
  load_balancer_arn = aws_lb.alb-tier1.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.thread_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.first-tiertg.arn
  }

  tags = local.common_tags
}


##########################################################################

# aws_lb tier 2

resource "aws_lb" "alb-tier2" {
  name               = "alb-appservers"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-tier2.id]
  subnets            = [aws_subnet.private_subnet3.id, aws_subnet.private_subnet4.id]

  enable_deletion_protection = false # Terraform will be able to delete the ALB

  tags = local.common_tags
}

# target group ALB

resource "aws_lb_target_group" "second-tiertg" {
  name     = "second-tier-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_site_vpc.id

  health_check {
    protocol            = "HTTP"
    path                = "/index.html"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2

  }

  tags = local.common_tags

}


# aws_lb_listener

resource "aws_lb_listener" "second-tierlsn" {
  load_balancer_arn = aws_lb.alb-tier2.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.second-tiertg.arn
  }

  tags = local.common_tags
}

#######################################################

# Create Auto Scaling Groups

/*data "aws_ssm_parameter" "amzn2_linux" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}
*/


data "aws_ami" "apache_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.custom_ami]
  }

  owners = [var.account_id]
}

data "aws_ami" "mysql_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.sql_ami]
  }

  owners = [var.account_id]
}

# Ec2 policy
# create a aws_iam_role Terraform resource with an assume_role_policy for the ec2.amazonaws.com principal

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }

}

resource "aws_iam_role" "ec2_role" {
  name               = "ec2_role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Attach the AmazonSSMManagedInstanceCore managed policy to the role

resource "aws_iam_role_policy_attachment" "test_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# create the aws_iam_instance_profile role from the aws_iam_role

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name
}

# attach the iam_instance_profile to the EC2 instance.
#iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

# IAM Policy for EC2 to Access S3

data "aws_iam_policy_document" "ec2_s3_access" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.thread-bucket.arn}",
      "${aws_s3_bucket.thread-bucket.arn}/*"
    ]
  }
}



resource "aws_iam_policy" "ec2_s3_policy" {
  name   = "ec2_s3_access_policy"
  policy = data.aws_iam_policy_document.ec2_s3_access.json
}

resource "aws_iam_role_policy_attachment" "ec2_s3_policy_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_s3_policy.arn
}

########################################################################## 

# Tier 1 - web servers

# Create a new ALB Target Group attachment
resource "aws_autoscaling_attachment" "asg-tier1" {
  autoscaling_group_name = aws_autoscaling_group.asg-tier1.id
  lb_target_group_arn    = aws_lb_target_group.first-tiertg.arn
}

# Autoscaling group tier 1

resource "aws_placement_group" "webservers" {
  name     = "webservers"
  strategy = "spread"

  tags = local.common_tags
}

resource "aws_autoscaling_group" "asg-tier1" {
  name                      = "threadcraft"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 600
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  placement_group           = aws_placement_group.webservers.id
  vpc_zone_identifier       = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
  launch_template {
    id      = aws_launch_template.thread-web.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.first-tiertg.arn]
}

# launch template

resource "aws_launch_template" "thread-web" {
  name_prefix            = "thread-web"
  image_id               = data.aws_ami.apache_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2-tier1.id]
  user_data = base64encode(<<EOF
#!/bin/bash

aws s3 cp s3://${aws_s3_bucket.thread-bucket.id}/index.html /var/www/html/index.html


EOF
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }


  /*
  block_device_mappings {
    device_name = "/dev/xvdf"
    ebs {
      volume_size           = 8
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }
*/

  tags = {
    Environment = "production"
    Name        = "Webservers"
  }

}

########################################################################## 

# Tier 2 - app servers

# Create a new ALB Target Group attachment
resource "aws_autoscaling_attachment" "asg-tier2" {
  autoscaling_group_name = aws_autoscaling_group.asg-tier2.id
  lb_target_group_arn    = aws_lb_target_group.second-tiertg.arn
}

# Autoscaling group tier 2

resource "aws_placement_group" "appservers" {
  name     = "appservers"
  strategy = "spread"

  tags = local.common_tags
}

resource "aws_autoscaling_group" "asg-tier2" {
  name                      = "threadcraft2"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 600
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  placement_group           = aws_placement_group.appservers.id
  vpc_zone_identifier       = [aws_subnet.private_subnet3.id, aws_subnet.private_subnet4.id]
  launch_template {
    id      = aws_launch_template.thread-app.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.second-tiertg.arn]

}

# launch template

resource "aws_launch_template" "thread-app" {
  name_prefix            = "thread-app"
  image_id               = data.aws_ami.mysql_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2-tier2.id]
  user_data = base64encode(<<EOF
#!/bin/bash

aws s3 cp s3://${aws_s3_bucket.thread-bucket.id}/index.html /var/www/html/index.html


EOF
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  tags = {
    Environment = "production"
    Name        = "Appservers"
  }

}
