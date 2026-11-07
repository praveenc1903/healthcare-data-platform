# Notify Snowpipe's SQS queue whenever a new openFDA file lands in S3
resource "aws_s3_bucket_notification" "snowpipe" {
  count  = var.snowpipe_sqs_arn != "" ? 1 : 0
  bucket = aws_s3_bucket.raw.id

  queue {
    queue_arn     = var.snowpipe_sqs_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "openfda/"
  }
}