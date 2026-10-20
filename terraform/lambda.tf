data "archive_file" "ingest" {
  type        = "zip"
  source_file = "${path.module}/../ingestion/lambda_function.py"
  output_path = "${path.module}/build/ingest.zip"
}

resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/aws/lambda/${var.project}-openfda-ingest"
  retention_in_days = 14
}

resource "aws_lambda_function" "ingest" {
  function_name    = "${var.project}-openfda-ingest"
  role             = aws_iam_role.ingest_lambda.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.ingest.output_path
  source_code_hash = data.archive_file.ingest.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.raw.bucket
      LIMIT       = "100"
    }
  }

  depends_on = [aws_cloudwatch_log_group.ingest]
}