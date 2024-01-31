resource "aws_secretsmanager_secret" "api_token" {
  name        = "replicated_api_token"
  description = "API token the Replicated Vendor Portal"
}

resource "aws_secretsmanager_secret_version" "api_token" {
  secret_id     = aws_secretsmanager_secret.api_token.id
  secret_string = var.api_token
}

resource "aws_lambda_function" "create_license" {
  function_name = "create-replicated-license"
  architectures = ["arm64"]

  handler       = "main.handler"  # Assuming your Python file is named lambda_function.py
  role          = aws_iam_role.lambda_exec_role.arn
  runtime       = "python3.11"

  filename         = "${var.build_directory}/create-license.zip"
  source_code_hash = filebase64sha256("${var.build_directory}/create-license.zip")
  
  environment {
    variables = {
      SECRET_ARN = aws_secretsmanager_secret.api_token.arn
    }
  }
}

resource "aws_iam_role_policy" "lambda_secretsmanager_policy" {
  name   = "lambda_secretsmanager_policy"
  role   = aws_iam_role.lambda_exec_role.id
  policy = data.aws_iam_policy_document.lambda_secretsmanager_policy.json
}

data "aws_iam_policy_document" "lambda_secretsmanager_policy" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.api_token.arn]
  }
}

data "aws_iam_policy" "lambda_exec_policy" {
  name = "AWSLambdaBasicExecutionRole"
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


