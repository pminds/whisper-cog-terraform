# Terraform Infrastructure for Whisper Diarization

This directory contains Terraform code to set up the infrastructure required for the Whisper Diarization project.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Terraform](https://www.terraform.io/downloads.html)
- [AWS CLI](https://aws.amazon.com/cli/)
- Configured AWS credentials (`~/.aws/credentials`)

## Setting Up Terraform

1. **Install Terraform**:
   Follow the instructions on the [Terraform website](https://www.terraform.io/downloads.html) to install Terraform on
   your system.

2. **Configure AWS CLI**:
   Set up your AWS CLI with the necessary credentials by following
   this [AWS setup guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html):
    ```sh
    aws configure
    ```

## Deploying the Infrastructure

1. **Navigate to the `infra` directory**:
    ```sh
    cd whisper-cog-terraform/infra
    ```

2. **Initialize Terraform**:
   Initialize the Terraform working directory. This step downloads the necessary provider plugins.
    ```sh
    terraform init
    ```

3. **Plan the Infrastructure**:
   Generate and review the execution plan for the infrastructure.
    ```sh
    terraform plan
    ```

4. **Apply the Infrastructure**:
   Apply the changes required to reach the desired state of the configuration.
    ```sh
    terraform apply
    ```
   Confirm the apply step by typing `yes` when prompted.

## Terraform Code Overview

### `main.tf`

Defines the main configuration for the Terraform project, including the VPC setup using the
`terraform-aws-modules/vpc/aws` module. It creates a VPC with public and private subnets, NAT gateway, and necessary
configurations.

### `ec2.tf`

Creates EC2 instances for running the Whisper Diarization application. It includes configurations for instance types,
AMIs, security groups, IAM roles, and reference to the user data script to set up the environment on the instances.

### `user-data-template.sh`

A shell script used as user data for EC2 instances. It installs necessary dependencies, sets up a virtual environment,
downloads the model package from S3, and configures the application to run as a service.

### `lambda.tf`

Defines the Lambda function for orchestrating EC2 instances. It includes the creation of the Lambda function, IAM roles
and policies, and the packaging of the Lambda function code.

### `provider.tf`

Specifies the required providers and their versions. It also configures the AWS provider with the region to be used for
resource creation.

### `variables.tf`

Defines variables used throughout the Terraform configuration, such as the AWS region.

### `api_gateway.tf`

Sets up an API Gateway to expose the Lambda function as a REST API. It includes the creation of the API, methods,
integrations, and necessary permissions.

### `s3_models.tf`

Creates an S3 bucket for storing model packages and other data. It includes configurations for bucket policies,
versioning, and access control.

### `backend.tf`

Configures the Terraform backend to store the Terraform state remotely.

### `outputs.tf`

Defines the Terraform output values that provide key resource details after deployment, such as API Gateway endpoints.

### `container_registry.tf`

Creates an ECR repository for storing Docker images used by the Whisper Diarization application. It includes
configurations for image scanning and repository policies.

## Cleaning Up

⚠️ **Warning:** Destroying the infrastructure will delete all resources permanently.

To destroy the infrastructure and clean up all resources created by Terraform run:

```sh
terraform destroy
```

Confirm the destroy step by typing `yes` when prompted.
