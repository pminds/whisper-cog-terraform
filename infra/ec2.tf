data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name = "name"
    values = ["al2023-ami*-x86_64"] # Replace with Amazon Linux 2023 pattern
  }
  owners = ["amazon"] # Amazon's AWS Account
}

resource "aws_instance" "whisper-diarization" {
  instance_type        = "g5.xlarge"
  ami                  = "ami-07bbe58ebf89ee018" # Amazon Deep Learning AMI (DLAMI)
  #instance_type          = "t3.micro"
  #ami                    = "ami-0cdd6d7420844683b" # Amazon Linux 2023
  subnet_id            = module.models_vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.models_ec2_direct_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  associate_public_ip_address = false

  tags = {
    Name = "g5-whisper-diarization"
  }

  root_block_device {
    volume_size = 200   # Replace with the desired size in GB
    volume_type = "gp3" # General Purpose SSD (default)
  }

  user_data = templatefile("${path.module}/user-data-template.sh", {
    MODEL_PACKAGE_S3_URI = "s3://models-bucket-just-stag/whisper-diarization.tar.gz"
  })

  user_data_replace_on_change = true

}

resource "aws_instance" "prepared-whisper-diarization-no" {
  instance_type        = "g5.xlarge"
  ami = "ami-07bbe58ebf89ee018" # Amazon Deep Learning AMI (DLAMI)
  subnet_id            = module.models_vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.models_ec2_direct_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  associate_public_ip_address = true

  tags = {
    Name = "g5-whisper-diarization-no"
  }

  root_block_device {
    volume_size = 200   # Replace with the desired size in GB
    volume_type = "gp3" # General Purpose SSD (default)
  }

  user_data = templatefile("${path.module}/user-data-template.sh", {
    MODEL_PACKAGE_S3_URI = "s3://models-bucket-just-stag/whisper-diarization-no.tar.gz"
  })

  user_data_replace_on_change = true

}

resource "aws_instance" "prepared-whisper-diarization" {
  instance_type        = "g5.xlarge"
  ami                  = "ami-07bbe58ebf89ee018" # Amazon Deep Learning AMI (DLAMI)
  #ami                  = "ami-02ea8ee638ebe41a6" # Prepared whisper-diarization AMI
  #ami                    = "ami-0cdd6d7420844683b" # Amazon Linux 2023
  subnet_id            = module.models_vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.models_ec2_direct_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  associate_public_ip_address = true

  tags = {
    Name = "prepared-g5-whisper-diarization"
  }

  root_block_device {
    volume_size = 200   # Replace with the desired size in GB
    volume_type = "gp3" # General Purpose SSD (default)
  }

  user_data = templatefile("${path.module}/user-data-template.sh", {
    MODEL_PACKAGE_S3_URI = "s3://models-bucket-just-stag/whisper-diarization.tar.gz"
  })

  user_data_replace_on_change = true

}

resource "aws_security_group" "models_ec2_direct_sg" {
  name        = "models-ec2_direct_sg"
  description = "Allow traffic on port 8000"
  vpc_id      = module.models_vpc.vpc_id

  ingress {
    from_port = 8000
    to_port   = 8000
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "models_ec2_sg" {
  name        = "models-ec2_sg"
  description = "Allow ALB traffic on port 80"
  vpc_id      = module.models_vpc.vpc_id

  ingress {
    from_port = 5000
    to_port   = 5000
    protocol  = "tcp"
    cidr_blocks = ["10.10.0.0/21"] # ALB subnet range
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2_instance_role" {
  name = "ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_model_access_policy" {
  name        = "EC2S3CopyPolicy"
  description = "Allows EC2 instances to copy a model from S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${module.models_bucket.bucket_arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_model_access_policy_attachment" {
  policy_arn = aws_iam_policy.s3_model_access_policy.arn
  role       = aws_iam_role.ec2_instance_role.name
}

resource "aws_iam_policy_attachment" "ssm_policy_attachment" {
  name       = "ssm-managed-policy-attachment"
  roles = [aws_iam_role.ec2_instance_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy_attachment" "ecr_policy_attachment" {
  name       = "ecr-managed-policy-attachment"
  roles = [aws_iam_role.ec2_instance_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}


resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
}
