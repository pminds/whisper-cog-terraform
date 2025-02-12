# Project Overview

This project consists of four major parts, each serving a specific purpose in the overall architecture. Below is a brief
description of each part:

## 1. `ec2_instance_orchestrator`

This is a Lambda function responsible for orchestrating EC2 instances. It handles the lifecycle of EC2 instances,
including starting, stopping, and monitoring their status.

## 2. `infra`

This directory contains Terraform code to set up all the necessary infrastructure. It includes configurations for AWS
resources such as EC2 instances, Lambda functions, and other required services.

## 3. `whisper-diarization`

This is a FastAPI application that wraps the `openai/whisper-large-v3` model. It provides endpoints for speech-to-text
processing and speaker diarization.

## 4. `whisper-diarization-no`

This is a FastAPI application that wraps the `NbAiLab/nb-whisper-large` model. Similar to `whisper-diarization`, it
offers endpoints for speech-to-text processing and speaker diarization.

## Getting Started

### Prerequisites

- Python 3.8 or higher - developed with Python 3.12
- Terraform 1.0 or higher
- AWS CLI configured with appropriate permissions
- Docker (for local development and testing)
