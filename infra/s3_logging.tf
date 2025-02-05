resource "random_pet" "logging_bucket" {
  prefix = "logging-bucket"
  length = 2
}

module "logging_bucket" {
  source = "cloudposse/s3-log-storage/aws"
  # Cloud Posse recommends pinning every module to a specific version
  version = "1.3.1"

  name                     = random_pet.logging_bucket.id
  acl                      = "log-delivery-write"
  standard_transition_days = 30
  glacier_transition_days  = 60
  expiration_days          = 90
  bucket_key_enabled       = true

  source_policy_documents = [
    jsonencode({
      "Version" : "2012-10-17",
      "Id" : "AWSConsole-AccessLogs-Policy-1656327714020",
      "Statement" : [
        {
          "Sid" : "AWSConsoleStmt-1656327714023",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : "arn:aws:iam::156460612806:root"
          },
          "Action" : "s3:PutObject",
          "Resource" : "arn:aws:s3:::${random_pet.logging_bucket.id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        },
        {
          "Sid" : "AWSLogDeliveryWrite",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "delivery.logs.amazonaws.com"
          },
          "Action" : "s3:PutObject",
          "Resource" : "arn:aws:s3:::${random_pet.logging_bucket.id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
          "Condition" : {
            "StringEquals" : {
              "s3:x-amz-acl" : "bucket-owner-full-control"
            }
          }
        },
        {
          "Sid" : "AWSLogDeliveryAclCheck",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "delivery.logs.amazonaws.com"
          },
          "Action" : "s3:GetBucketAcl",
          "Resource" : "arn:aws:s3:::${random_pet.logging_bucket.id}"
        }
      ]
    }),
  ]
}
