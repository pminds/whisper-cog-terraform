module "models_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.17.0"

  name = "models-vpc"
  cidr = "10.10.0.0/21"

  azs = [
    "eu-central-1a",
    "eu-central-1b"
  ]

  private_subnets = [
    "10.10.0.0/24", # Private AZ1a
    "10.10.1.0/24"  # Private AZ1b
  ]

  public_subnets = [
    "10.10.4.0/24", # Public AZ1a
    "10.10.5.0/24"  # Public AZ1b
  ]

  enable_vpn_gateway   = false
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # To be CIS compliant we wipe the default security group rules - this shows up weirdly in Terraform but actually works
  manage_default_security_group  = true
  default_security_group_ingress = [{}]
  default_security_group_egress  = [{}]

}