terraform {
  backend "s3" {
    bucket         = "terraform-state-20250122"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}