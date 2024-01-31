locals {
  cloudformation_template = templatefile("${path.module}/templates/slackernews_cloudformation.tftpl",
                                {
                                  lambda_function_arn = aws_lambda_function.create_license.arn
                                  app_id = var.app_id
                                }
                             )
}

resource "random_pet" "bucket_suffix" {
  length = 2
}

data "aws_iam_policy_document" "stack_policy" {
  statement {
    effect = "Allow"
    actions   = [ "lambda:InvokeFunction" ]
    resources = [ aws_lambda_function.create_license.arn ]
  }
}

resource "aws_iam_policy" "stack_policy" {
  name        = "create-license-lambda-invoke-policy"
  description = "License creation stack policy"

  policy = data.aws_iam_policy_document.stack_policy.json
}

resource "aws_iam_role" "stack_role" {
  name = "create-license-stack-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "cloudformation.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "stack_role" {
  role       = aws_iam_role.stack_role.name
  policy_arn = aws_iam_policy.stack_policy.arn
}

resource "aws_s3_bucket" "template_bucket" {
  bucket = "slackernews-cf-${random_pet.bucket_suffix.id}"
}

resource "aws_s3_bucket_versioning" "template_bucket" {
  bucket = aws_s3_bucket.template_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "cloudformation_template" {
  bucket = aws_s3_bucket.template_bucket.id
  key    = "slackernews_cloudformation.yaml"

  content_type = "text/yaml"
  content      = local.cloudformation_template

  etag = md5(local.cloudformation_template)
}
