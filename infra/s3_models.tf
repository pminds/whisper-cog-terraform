resource "random_pet" "models_bucket" {
  prefix = "models-bucket"
  length = 2
}


module "models_bucket" {
  source = "cloudposse/s3-bucket/aws"
  # Cloud Posse recommends pinning every module to a specific version
  version = "4.10.0"
  enabled = true

  bucket_name = random_pet.models_bucket.id

  acl                     = "private"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  s3_object_ownership     = "BucketOwnerEnforced"

  bucket_key_enabled      = true
  allow_ssl_requests_only = true

  versioning_enabled = true
  force_destroy      = false

  sse_algorithm = "AES256"

  allowed_bucket_actions = ["s3:*"]

  logging = [{
    bucket_name = module.logging_bucket.bucket_id
    prefix      = "${random_pet.models_bucket.id}/"
  }]

}

# Since the `cloudposse/s3-bucket` module doesn't support `lifecycle { prevent_destroy = true }`, we can use
# force_destroy = false and add an object directly to the bucket when deploying.
# This will prevent the bucket from being destroyed as long as this object exists.
resource "aws_s3_object" "lambda_zips_bucket_prevent_destroy" {
  bucket  = module.models_bucket.bucket_id
  key     = "prevent_destroy"
  content = "1"
}
