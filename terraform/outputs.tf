output "raw_bucket_name" {
  value = aws_s3_bucket.raw.bucket
}

output "ingest_lambda_name" {
  value = aws_lambda_function.ingest.function_name
}