resource "aws_s3_bucket" "sample_lambda_codepipeline_bucket" {
  bucket = "sample-lambda-codepipeline-${var.ENV_VALUE_ENVIRONMENT}"
}

resource "aws_s3_bucket_acl" "codepipeline_bucket" {
  bucket = aws_s3_bucket.sample_lambda_codepipeline_bucket.id
  acl    = "private"
}
