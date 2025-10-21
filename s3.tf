# ==============================================================================
# S3: Snapshots Bucket
# ==============================================================================

resource "aws_s3_bucket" "snapshots" {
  bucket = var.snapshots_bucket_name
}

resource "aws_s3_bucket_versioning" "snapshots" {
  bucket = aws_s3_bucket.snapshots.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "snapshots" {
  bucket = aws_s3_bucket.snapshots.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "snapshots" {
  bucket                  = aws_s3_bucket.snapshots.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "snapshots_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      aws_s3_bucket.snapshots.arn,
      "${aws_s3_bucket.snapshots.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "snapshots" {
  bucket = aws_s3_bucket.snapshots.id
  policy = data.aws_iam_policy_document.snapshots_tls_only.json
}


