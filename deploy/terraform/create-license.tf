resource "aws_secretsmanager_secret" "api_token" {
  name        = "replicated_api_token"
  description = "API token the Replicated Vendor Portal"
}

resource "aws_secretsmanager_secret_version" "api_token" {
  secret_id     = aws_secretsmanager_secret.api_token.id
  secret_string = var.api_token
}

resource "aws_s3_bucket" "licenses" {
  bucket = "slackernews-license-${random_pet.bucket_suffix.id}"

}

resource "aws_s3_bucket_ownership_controls" "licenses" {
  bucket = aws_s3_bucket.licenses.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_acl" "licenses" {
  depends_on = [ aws_s3_bucket_ownership_controls.licenses ]

  bucket = aws_s3_bucket.licenses.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "licenses" {
  bucket = aws_s3_bucket.licenses.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_lambda_function" "create_license" {
  function_name = "create-replicated-license"
  architectures = ["arm64"]

  handler       = "main.handler"  # Assuming your Python file is named lambda_function.py
  role          = aws_iam_role.lambda_exec_role.arn
  runtime       = "python3.11"

  filename         = "${var.build_directory}/create-license.zip"
  source_code_hash = filebase64sha256("${var.build_directory}/create-license.zip")
  
  timeout = 6

  environment {
    variables = {
      SECRET_ARN = aws_secretsmanager_secret.api_token.arn
      LICENSE_BUCKET_NAME = aws_s3_bucket.licenses.bucket
      LICENSE_BUCKET_DOMAIN = aws_s3_bucket.licenses.bucket_regional_domain_name
    }
  }
}

resource "aws_iam_policy" "lambda_license_bucket" {
  name   = "lambda_license_bucket"
  policy = data.aws_iam_policy_document.lambda_license_bucket.json
}

data "aws_iam_policy_document" "lambda_license_bucket" {
  statement {
    actions   = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:PutObject",
    ]
    resources = [ "${aws_s3_bucket.licenses.arn}/*" ]
  }
}

resource "aws_iam_policy" "lambda_secrets_manager" {
  name   = "lambda_secrets_manager"
  policy = data.aws_iam_policy_document.lambda_secrets_manager.json
}

data "aws_iam_policy_document" "lambda_secrets_manager" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.api_token.arn]
  }
}

data "aws_iam_policy" "lambda_exec_policy" {
  name = "AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_license_bucket" {
  role       = aws_iam_role.lambda_exec_role.id
  policy_arn = aws_iam_policy.lambda_license_bucket.arn
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_manager" {
  role       = aws_iam_role.lambda_exec_role.id
  policy_arn = aws_iam_policy.lambda_secrets_manager.arn
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  role       = aws_iam_role.lambda_exec_role.id
  policy_arn = data.aws_iam_policy.lambda_exec_policy.arn
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
      },
    ],
  })
}

