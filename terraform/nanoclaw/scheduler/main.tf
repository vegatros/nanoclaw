# Lambda zip
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/index.zip"
}

# IAM Role for Lambda
resource "aws_iam_role" "scheduler" {
  name = "${var.project_name}-scheduler"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.scheduler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "ec2_control" {
  name = "${var.project_name}-ec2-startstop"
  role = aws_iam_role.scheduler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ec2:StartInstances", "ec2:StopInstances"]
      Resource = "arn:aws:ec2:${var.aws_region}:*:instance/${var.instance_id}"
    }]
  })
}

# Start Lambda + EventBridge
resource "aws_lambda_function" "start" {
  count         = var.schedule_start != "" ? 1 : 0
  function_name = "${var.project_name}-ec2-start"
  role          = aws_iam_role.scheduler.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      ACTION      = "start"
      INSTANCE_ID = var.instance_id
      REGION      = var.aws_region
    }
  }
}

resource "aws_cloudwatch_event_rule" "start" {
  count               = var.schedule_start != "" ? 1 : 0
  name                = "${var.project_name}-ec2-start"
  schedule_expression = var.schedule_start
}

resource "aws_cloudwatch_event_target" "start" {
  count = var.schedule_start != "" ? 1 : 0
  rule  = aws_cloudwatch_event_rule.start[0].name
  arn   = aws_lambda_function.start[0].arn
}

resource "aws_lambda_permission" "start" {
  count         = var.schedule_start != "" ? 1 : 0
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start[0].arn
}

# Stop Lambda + EventBridge
resource "aws_lambda_function" "stop" {
  count         = var.schedule_stop != "" ? 1 : 0
  function_name = "${var.project_name}-ec2-stop"
  role          = aws_iam_role.scheduler.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      ACTION      = "stop"
      INSTANCE_ID = var.instance_id
      REGION      = var.aws_region
    }
  }
}

resource "aws_cloudwatch_event_rule" "stop" {
  count               = var.schedule_stop != "" ? 1 : 0
  name                = "${var.project_name}-ec2-stop"
  schedule_expression = var.schedule_stop
}

resource "aws_cloudwatch_event_target" "stop" {
  count = var.schedule_stop != "" ? 1 : 0
  rule  = aws_cloudwatch_event_rule.stop[0].name
  arn   = aws_lambda_function.stop[0].arn
}

resource "aws_lambda_permission" "stop" {
  count         = var.schedule_stop != "" ? 1 : 0
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop[0].arn
}
