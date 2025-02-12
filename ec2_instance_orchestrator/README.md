# FastAPI-Based EC2 Instance Management API

This project provides a **FastAPI-based API** to manage AWS EC2 instances. It allows you to create, start, stop,
terminate, and check the status of EC2 instances. The API is designed to be deployed as an **AWS Lambda function** using
**Mangum** to enable seamless integration with AWS API Gateway.

## Features

- 🚀 **Launch EC2 Instances** (`POST /create`)
- 📡 **Check Instance Status** (`GET /status/{instance_id}`)
- 📋 **List Instances** (`GET /list`)
- ▶️ **Start an Instance** (`POST /start/{instance_id}`)
- ⏸️ **Stop an Instance** (`POST /stop/{instance_id}`)
- ❌ **Terminate an Instance** (`DELETE /terminate/{instance_id}`)
- ❤️ ** API Health Check** (`GET /health`)

## Prerequisites

Before deploying or running the API, ensure you have:

- **Python 3.9+** installed - developed with Python 3.12
- **AWS CLI** configured (`~/.aws/credentials`)
- **Boto3** installed for AWS interaction:

- ```sh
  pip install -r requirements.txt
  ```

## API Endpoints

### **1. Health Check**

Checks if the API is running.

```sh
GET /health
```

#### Response:

```json
{
  "status": "healthy"
}
```

### **2. Create an EC2 Instance**

Launches an EC2 instance with predefined configurations.

```sh
POST /create
```

#### Response:

```json
{
  "instance_id": "i-1234567890abcdef0",
  "public_ip": "3.238.123.45"
}
```

### **3. Get Status of the API running on the EC2 instance **

Fetches the status of a given instance.

```sh
GET /status/{instance_id}
```

#### Response:

```json
{
  "status": "ready"
}
```

or

```json
{
  "status": "not ready",
  "detail": "Health check returned status code 503"
}
```

### **4. List Running EC2 Instances**

Retrieves a list of all active EC2 instances.

```sh
GET /list
```

#### Response:

```json
{
  "running_instances": [
    {
      "InstanceId": "i-1234567890abcdef0",
      "InstanceType": "g5.xlarge",
      "State": "running",
      "PublicIpAddress": "3.238.123.45"
    }
  ]
}
```

### **5. Start an EC2 Instance**

Starts a previously stopped EC2 instance.

```sh
POST /start/{instance_id}
```

#### Response:

```json
{
  "message": "Start initiated for instance i-1234567890abcdef0"
}
```

### **6. Stop an EC2 Instance**

Stops a running EC2 instance.

```sh
POST /stop/{instance_id}
```

#### Response:

```json
{
  "message": "Stop initiated for instance i-1234567890abcdef0"
}
```

### **7. Terminate an EC2 Instance**

Terminates an EC2 instance.

```sh
DELETE /terminate/{instance_id}
```

#### Response:

```json
{
  "message": "Termination initiated for instance i-1234567890abcdef0"
}
```

## Logging

The API logs events to CloudWatch with timestamps, using **Python's logging module**.

Example log:

```plaintext
2025-02-11T14:30:25 - Starting instance launch process...
2025-02-11T14:30:26 - Instance creation request sent. Instance ID: i-1234567890abcdef0
```

## Deployment as an AWS Lambda Function

To deploy the API as an AWS Lambda function, follow the steps in the infra README.md file.

---

This API enables easy EC2 instance management via RESTful endpoints while being lightweight and **serverless-friendly**!
🚀