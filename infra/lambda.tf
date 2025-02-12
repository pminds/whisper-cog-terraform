resource "null_resource" "ec2_instance_orchestrator_lambda_zip" {
  triggers = {
    python_file = filemd5("${path.module}/../ec2_instance_orchestrator/ec2_orchestrator.py")
    timestamp = timestamp() # This updates with the current timestamp whenever Terraform runs
  }
}

data "archive_file" "ec2_instance_orchestrator_lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/../artifacts/ec2_instance_orchestrator.zip"
  source_dir  = "${path.module}/../ec2_instance_orchestrator/"

  depends_on = [
    null_resource.ec2_instance_orchestrator_lambda_zip
  ]
}

resource "aws_s3_object" "ec2_instance_orchestrator_lambda" {
  bucket = module.models_bucket.bucket_id
  key    = "ec2_instance_orchestrator.zip"
  source = data.archive_file.ec2_instance_orchestrator_lambda_zip.output_path
  etag   = data.archive_file.ec2_instance_orchestrator_lambda_zip.output_md5

  depends_on = [
    data.archive_file.ec2_instance_orchestrator_lambda_zip
  ]
}

resource "aws_iam_role" "ec2_instance_orchestrator_lambda_role" {
  name_prefix = "ec2-instance-orchestrator-lambda-role"
  path        = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = [
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_instance_orchestrator_lambda_role_policy" {
  name = "ec2-instance-orchestrator-role-lambda-policy"
  role = aws_iam_role.ec2_instance_orchestrator_lambda_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": "${aws_lambda_function.ec2_instance_orchestrator.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::767828746624:role/ec2-instance-role"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:DescribeInstances",
        "ec2:CreateTags",
        "ec2:TerminateInstances",
        "ec2:StopInstances",
        "ec2:StartInstances",
        "ec2:DescribeImages"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_lambda_function" "ec2_instance_orchestrator" {
  function_name = "ec2_instance_orchestrator"
  description   = "Lambda function to create/terminate EC2 instances"

  s3_bucket = module.models_bucket.bucket_id
  s3_key    = aws_s3_object.ec2_instance_orchestrator_lambda.key

  runtime = "python3.12"
  handler = "ec2_orchestrator.lambda_handler"

  role = aws_iam_role.ec2_instance_orchestrator_lambda_role.arn

  source_code_hash = data.archive_file.ec2_instance_orchestrator_lambda_zip.output_base64sha256

  # Increase timeout to 120 seconds to allow EC2 instance creation to complete
  timeout = 120

  depends_on = [aws_s3_object.ec2_instance_orchestrator_lambda]
}

