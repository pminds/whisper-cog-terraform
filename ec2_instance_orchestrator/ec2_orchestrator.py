import httpx

from fastapi import FastAPI, HTTPException
from mangum import Mangum
import boto3
import logging
import traceback
from datetime import datetime
from typing import List, Dict


# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def print_timestamp(message: str):
    ts = datetime.now().isoformat()
    logger.info(f"{ts} - {message}")


def get_model_tag_value(ami_id: str) -> str:
    ec2_client = boto3.client("ec2")
    response = ec2_client.describe_images(ImageIds=[ami_id])
    images = response.get("Images", [])
    if images:
        tags = images[0].get("Tags", [])
        # Look for the tag with Key "Model"
        model_tag = next((tag for tag in tags if tag.get("Key") == "Model"), None)
        if model_tag:
            return model_tag.get("Value")
    return None


# Define the FastAPI app
app = FastAPI()


# Sample endpoints for testing
@app.get("/health")
def health_check():
    print(f"{datetime.now().isoformat()} - Status: healthy")
    return {"status": "healthy"}


from pydantic import BaseModel


class CreateInstanceRequest(BaseModel):
    ami_id: str


from pydantic import BaseModel


class CreateInstanceRequest(BaseModel):
    ami_id: str


@app.post("/create/{ami_id}")
def create_instance(ami_id: str):
    print_timestamp("Starting instance launch process...")

    instance_type = "g5.xlarge"
    # List of subnets across the three availability zones
    available_subnets = [
        "subnet-0782b2c51913f5597",  # eu-central-1a
        "subnet-0563d0db138045902",  # eu-central-1b
    ]
    security_group_id = "sg-035e9d14ca33b05dd"
    iam_instance_profile_name = "ec2-instance-profile"
    tag_name = "boto3-g5-whisper-diarization"
    volume_size = 200  # in GB
    volume_type = "gp3"

    # Log configuration parameters
    print_timestamp(
        f"Configuration: ami_id={ami_id}, instance_type={instance_type}, "
        f"available_subnets={available_subnets}, security_group_id={security_group_id}, "
        f"iam_instance_profile_name={iam_instance_profile_name}, tag_name={tag_name}, "
        f"volume_size={volume_size}, volume_type={volume_type}"
    )

    # Create an EC2 resource
    try:
        ec2 = boto3.resource("ec2")
        print_timestamp("Boto3 EC2 resource created successfully.")
    except Exception as e:
        print_timestamp(f"Error creating EC2 resource: {e}")
        raise HTTPException(status_code=500, detail=f"Error creating EC2 resource: {e}")

    instance = None
    last_error = None

    # Attempt to launch the instance in one of the available subnets
    for subnet_id in available_subnets:
        try:
            print_timestamp(f"Attempting to launch instance in subnet {subnet_id}...")
            instance = ec2.create_instances(
                ImageId=ami_id,
                InstanceType=instance_type,
                MinCount=1,
                MaxCount=1,
                NetworkInterfaces=[
                    {
                        "SubnetId": subnet_id,
                        "DeviceIndex": 0,
                        "AssociatePublicIpAddress": True,
                        "Groups": [security_group_id],
                    }
                ],
                IamInstanceProfile={"Name": iam_instance_profile_name},
                TagSpecifications=[
                    {
                        "ResourceType": "instance",
                        "Tags": [{"Key": "Name", "Value": tag_name}],
                    }
                ],
                BlockDeviceMappings=[
                    {
                        "DeviceName": "/dev/sda1",  # Default root device name
                        "Ebs": {"VolumeSize": volume_size, "VolumeType": volume_type},
                    }
                ],
            )[0]
            print_timestamp(
                f"Instance creation request sent. Instance ID: {instance.id} in subnet {subnet_id}"
            )
            break  # Successfully launched; exit the loop
        except Exception as e:
            last_error = e
            if "InsufficientInstanceCapacity" in str(e):
                print_timestamp(
                    f"Insufficient capacity in subnet {subnet_id}. Trying next subnet..."
                )
            else:
                print_timestamp(f"Error launching instance in subnet {subnet_id}: {e}")
                print_timestamp(traceback.format_exc())
                raise HTTPException(
                    status_code=500,
                    detail=f"Error launching instance in subnet {subnet_id}: {e}",
                )

    if instance is None:
        raise HTTPException(
            status_code=500,
            detail=f"Error launching instance in all subnets. Last error: {last_error}",
        )

    # Wait until the instance is in the "running" state
    try:
        print_timestamp("Waiting for instance to transition to running state...")
        instance.wait_until_running()
        instance.reload()
        print_timestamp("Instance is now running.")
    except Exception as e:
        print_timestamp(f"Error waiting for instance to run: {e}")
        print_timestamp(traceback.format_exc())
        raise HTTPException(
            status_code=500, detail=f"Error waiting for instance to run: {e}"
        )

    # Add a Model tag to the running instance using the value from the AMI
    additional_tag_key = "Model"
    additional_tag_value = get_model_tag_value(ami_id)
    try:
        instance.create_tags(
            Tags=[{"Key": additional_tag_key, "Value": additional_tag_value}]
        )
        print_timestamp(
            f"Added tag {additional_tag_key}:{additional_tag_value} to instance {instance.id}"
        )
    except Exception as e:
        print_timestamp(f"Error adding additional tag: {e}")
        print_timestamp(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error adding additional tag: {e}")

    print_timestamp(f"Public IP available: {instance.public_ip_address}")

    # Construct the health check URL using the public IP
    health_url = f"http://{instance.public_ip_address}:8000/health"
    print_timestamp(f"Starting health checks at {health_url} every 1 second...")

    return {
        "instance_id": instance.id,
        "public_ip": instance.public_ip_address,
    }


@app.get("/status/{instance_id}")
async def get_instance_status(instance_id: str):
    """
    Checks the status of an EC2 instance by its instance ID.

    It retrieves the instance's public IP using boto3, then calls http://<public_ip>:8000/health.
    If the health endpoint returns 200 OK, the instance is considered "ready".
    Otherwise, the endpoint returns a "not ready" status along with details.
    """
    # Create an EC2 client (make sure your Lambda's IAM role has ec2:DescribeInstances permission)
    ec2 = boto3.client("ec2")
    try:
        response = ec2.describe_instances(InstanceIds=[instance_id])
        reservations = response.get("Reservations", [])
        if not reservations:
            raise HTTPException(status_code=404, detail="Instance not found")
        # Assuming we use the first instance from the first reservation
        instance = reservations[0]["Instances"][0]
        public_ip = instance.get("PublicIpAddress")
        if not public_ip:
            raise HTTPException(
                status_code=400, detail="Instance does not have a public IP"
            )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving instance: {e}")

    # Construct the health check URL using the public IP on port 8000
    health_url = f"http://{public_ip}:8000/health"
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(health_url, timeout=5.0)
        if response.status_code == 200:
            return {"status": "ready"}
        else:
            return {
                "status": "not ready",
                "detail": f"Health check returned status code {response.status_code}",
            }
    except httpx.RequestError as exc:
        # If the connection fails, we assume the service is not ready
        return {
            "status": "not ready",
            "detail": f"Error connecting to {health_url}: {exc}",
        }


@app.get("/list")
def list_running_ec2_instances() -> Dict[str, List[Dict]]:
    """
    Lists all running EC2 instances that have the 'Model' tag, along with their tags and predict endpoint.
    """
    ec2 = boto3.client("ec2")
    response = ec2.describe_instances(
        Filters=[
            {
                "Name": "instance-state-name",
                "Values": ["initializing", "running", "stopping", "stopped"],
            },
            {
                "Name": "tag-key",
                "Values": ["Model"],
            },
        ]
    )

    instances = []
    for reservation in response.get("Reservations", []):
        for instance in reservation.get("Instances", []):
            public_ip = instance.get("PublicIpAddress")
            health_endpoint = f"http://{public_ip}:8000/health" if public_ip else None
            predict_endpoint = f"http://{public_ip}:8000/predict" if public_ip else None

            instances.append(
                {
                    "InstanceId": instance.get("InstanceId"),
                    "InstanceType": instance.get("InstanceType"),
                    "State": instance.get("State", {}).get("Name"),
                    "PublicIpAddress": public_ip,
                    "Tags": instance.get("Tags", []),
                    "HealthEndpoint": health_endpoint,
                    "PredictEndpoint": predict_endpoint,
                }
            )

    return {"running_instances": instances}


@app.get("/list_images")
def list_images():
    """
    Lists all AMIs owned by the account that have the 'Model' tag.
    """
    ec2 = boto3.client("ec2")
    try:
        response = ec2.describe_images(
            Owners=["self"], Filters=[{"Name": "tag-key", "Values": ["Model"]}]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing images: {e}")

    images = []
    for image in response.get("Images", []):
        model_value = None
        for tag in image.get("Tags", []):
            if tag.get("Key") == "Model":
                model_value = tag.get("Value")
                break
        images.append(
            {
                "ImageId": image.get("ImageId"),
                "Name": image.get("Name"),
                "CreationDate": image.get("CreationDate"),
                "Model": model_value,
                "Tags": image.get("Tags", []),
            }
        )

    return {"images": images}


@app.post("/start/{instance_id}")
def start_instance(instance_id: str):
    """
    Starts the specified EC2 instance.
    """
    ec2 = boto3.client("ec2")

    try:
        response = ec2.start_instances(InstanceIds=[instance_id])
        return {
            "message": f"Start initiated for instance {instance_id}",
            "response": response,
        }
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Error starting instance {instance_id}: {e}"
        )


@app.post("/stop/{instance_id}")
def stop_instance(instance_id: str):
    """
    Stops the specified EC2 instance.
    """
    ec2 = boto3.client("ec2")

    try:
        response = ec2.stop_instances(InstanceIds=[instance_id])
        return {
            "message": f"Stop initiated for instance {instance_id}",
            "response": response,
        }
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Error stopping instance {instance_id}: {e}"
        )


@app.delete("/terminate/{instance_id}")
def terminate_instance(instance_id: str):
    """
    Terminates a single EC2 instance given its instance ID.
    """
    ec2 = boto3.client("ec2")
    try:
        response = ec2.terminate_instances(InstanceIds=[instance_id])
    except Exception as e:
        # Raise an HTTP exception with a 400 status if termination fails.
        raise HTTPException(status_code=400, detail=str(e))

    return {
        "message": f"Termination initiated for instance {instance_id}",
        "response": response,
    }


# Attach the FastAPI app to Mangum, so it can be used as a Lambda function
lambda_handler = Mangum(app)
