# VPC endpoint for first region bucket

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.my_site_vpc.id
  service_name      = "com.amazonaws.${var.aws_regions}.s3"
  vpc_endpoint_type = "Gateway"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Allow-access-to-specific-bucket",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
         "s3:ListBucket",
         "s3:GetObject",
         "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.thread-bucket.arn}",
        "${aws_s3_bucket.thread-bucket.arn}/*"
      ]
    }
  ]
}
EOF

  tags = local.common_tags
}
# Associate route table with VPC endpoint

resource "aws_vpc_endpoint_route_table_association" "example" {
  route_table_id  = aws_route_table.three-tier-rt.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

# Create S3 bucket for VPC

resource "aws_s3_bucket" "thread-bucket" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Environment = "backup"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "thread-bucket" {
  bucket = aws_s3_bucket.thread-bucket.id

  rule {
    id = "catalog-lifecycle"

    # Transition to Standard-IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 1 year (365 days)
    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    # Expire backups after 3 years 
    expiration {
      days = 1095
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    status = "Enabled"
  }
}


# Enable S3 bucket versioning

resource "aws_s3_bucket_versioning" "thread-bucket" {
  bucket = aws_s3_bucket.thread-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "object1" {
  bucket       = aws_s3_bucket.thread-bucket.id
  key          = "catalog/index.html"
  content_type = "text/html"
  source       = "C:/Users/Irina/Downloads/currently 3 tier and backup/files/catalog/index.html"

}

resource "aws_s3_object" "object01" {
  bucket       = aws_s3_bucket.thread-bucket.id
  key          = "index.html"
  content_type = "text/html"
  source       = "C:/Users/Irina/Downloads/currently 3 tier and backup/files/index.html"
}

data "aws_iam_policy_document" "allow_vpc" {

  # Statement to allow AWS Backup service access
  statement {
    sid    = "AllowAWSBackupAccess"
    effect = "Allow"
    actions = [
      "s3:GetBucketVersioning",
      "s3:ListBucket",
      "s3:GetObject",
      "s3:GetBucketLocation"
    ]
    resources = [
      "${aws_s3_bucket.thread-bucket.arn}",
      "${aws_s3_bucket.thread-bucket.arn}/*"
    ]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }

  statement {
    sid       = "AllowVPCAccess"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.thread-bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpc"
      values   = [aws_vpc.my_site_vpc.id]
    }
  }

  # Statement to allow VPC access to list the bucket
  statement {
    sid       = "AllowListBucketForVPCAccess"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.thread-bucket.arn}"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpc"
      values   = [aws_vpc.my_site_vpc.id]
    }
  }

}

# Attach bucket policy to S3
resource "aws_s3_bucket_policy" "thread-bucket-pol" {
  bucket = aws_s3_bucket.thread-bucket.id
  policy = data.aws_iam_policy_document.allow_vpc.json

}



# VPC endpoint for DR bucket 

resource "aws_vpc_endpoint" "recov_s3" {
  vpc_id            = aws_vpc.recovery_site_vpc.id
  service_name      = "com.amazonaws.us-west-1.s3"
  vpc_endpoint_type = "Gateway"
  provider          = aws.backup

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Allow-access-to-specific-bucket",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
         "s3:ListBucket",
         "s3:GetObject",
         "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.thread_craft_west.arn}",
        "${aws_s3_bucket.thread_craft_west.arn}/*"
      ]
    }
  ]
}
EOF

}
# Associate route table with VPC endpoint

resource "aws_vpc_endpoint_route_table_association" "recov_example" {
  route_table_id  = aws_route_table.recovery_three-tier-rt.id
  vpc_endpoint_id = aws_vpc_endpoint.recov_s3.id
  provider        = aws.backup

}

# Create S3 cross region replication

resource "aws_s3_bucket" "thread_craft_west" {
  provider      = aws.backup
  bucket        = var.bucket_name_west
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "recov_bucket_ownership" {
  bucket   = aws_s3_bucket.thread_craft_west.id
  provider = aws.backup

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "thread_craft_west" {
  provider = aws.backup

  bucket = aws_s3_bucket.thread_craft_west.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_lifecycle_configuration" "thread_craft_west" {
  bucket   = aws_s3_bucket.thread_craft_west.id
  provider = aws.backup

  rule {
    id = "catalog-backup-lifecycle"

    # Transition to Standard-IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 1 year (365 days)
    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    # Expire backups after 3 years 
    expiration {
      days = 1095
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365

    }

    status = "Enabled"
  }
}


resource "aws_s3_object" "west_object" {
  bucket       = aws_s3_bucket.thread_craft_west.id
  provider     = aws.backup
  key          = "catalog/index.html"
  content_type = "text/html"
  source       = "C:/Users/Irina/Downloads/currently 3 tier and backup/files/catalog/index.html"
}

resource "aws_s3_object" "west_object1" {
  bucket       = aws_s3_bucket.thread_craft_west.id
  provider     = aws.backup
  key          = "/index.html"
  content_type = "text/html"
  source       = "C:/Users/Irina/Downloads/currently 3 tier and backup/files/index.html"
}

data "aws_iam_policy_document" "recov_bucket_policy" {

  statement {
    sid       = "AllowVPCAccess"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.thread_craft_west.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpc"
      values   = [aws_vpc.recovery_site_vpc.id]
    }
  }
}


# Statement to allow VPC access to list the bucket
statement {
  sid       = "AllowListBucketForVPCAccess"
  effect    = "Allow"
  actions   = ["s3:ListBucket"]
  resources = ["${aws_s3_bucket.thread_craft_west.arn}"]

  principals {
    type        = "AWS"
    identifiers = ["*"]
  }

  condition {
    test     = "StringEquals"
    variable = "aws:SourceVpc"
    values   = [aws_vpc.recovery_site_vpc.id]
  }
}

# Attach bucket policy to S3
resource "aws_s3_bucket_policy" "thread-bucket-pol-recov" {
  provider = aws.backup
  bucket   = aws_s3_bucket.thread_craft_west.id
  policy   = data.aws_iam_policy_document.recov_bucket_policy.json

}


data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "east_replication" {
  name               = "tf-iam-role-replication-12345"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "east_replication" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.thread-bucket.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = ["${aws_s3_bucket.thread-bucket.arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = ["${aws_s3_bucket.thread_craft_west.arn}/*"]
  }

}

resource "aws_iam_policy" "east_replication" {
  name   = "tf-iam-role-policy-replication-12345"
  policy = data.aws_iam_policy_document.east_replication.json
}

resource "aws_iam_role_policy_attachment" "east_replication" {
  role       = aws_iam_role.east_replication.name
  policy_arn = aws_iam_policy.east_replication.arn
}

resource "aws_s3_bucket_replication_configuration" "east_to_west" {
  depends_on = [aws_s3_bucket_versioning.thread-bucket]

  role   = aws_iam_role.east_replication.arn
  bucket = aws_s3_bucket.thread-bucket.id

  rule {
    id = "east-to-west-replication"

    filter {
      prefix = "catalog/"
    }

    delete_marker_replication {
      status = "Enabled"
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.thread_craft_west.arn
      storage_class = "STANDARD"

      replication_time {
        status = "Enabled"
        time {
          minutes = 15
        }
      }
      metrics {
        event_threshold {
          minutes = 15
        }
        status = "Enabled"
      }
    }
  }
}



resource "aws_s3_bucket_replication_configuration" "west_to_east" {
  provider = aws.backup
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.thread_craft_west]

  role   = aws_iam_role.west_replication.arn
  bucket = aws_s3_bucket.thread_craft_west.id

  rule {
    id = "west-to-east-replication"

    filter {
      prefix = "catalog/"
    }

    delete_marker_replication {
      status = "Enabled"
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.thread-bucket.arn
      storage_class = "STANDARD"

      replication_time {
        status = "Enabled"
        time {
          minutes = 15
        }
      }
      metrics {
        event_threshold {
          minutes = 15
        }
        status = "Enabled"
      }
    }
  }
}

data "aws_iam_policy_document" "assume_role_west" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "west_replication" {
  name               = "tf-iam-role-replication-1234556"
  assume_role_policy = data.aws_iam_policy_document.assume_role_west.json
}

data "aws_iam_policy_document" "west_replication" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.thread_craft_west.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = ["${aws_s3_bucket.thread_craft_west.arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = ["${aws_s3_bucket.thread-bucket.arn}/*"]
  }

}

resource "aws_iam_policy" "west_replication" {
  name   = "tf-iam-role-policy-replication-1234556"
  policy = data.aws_iam_policy_document.west_replication.json
}
resource "aws_iam_role_policy_attachment" "west_replication" {
  role       = aws_iam_role.west_replication.name
  policy_arn = aws_iam_policy.west_replication.arn
}
