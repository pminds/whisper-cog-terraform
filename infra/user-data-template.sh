#!/bin/bash
set -euxo pipefail

# Variables
MODEL_PACKAGE_S3_URI=${MODEL_PACKAGE_S3_URI}

# Install virtualenv if not already installed
pip3 install --upgrade pip
pip3 install virtualenv


wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar -xf ffmpeg-release-amd64-static.tar.xz
mv ffmpeg-*-amd64-static/ffmpeg /usr/local/bin/
ffmpeg -version

# Create virtual environment
mkdir -p /opt/venvs
cd /opt/venvs
python3 -m venv model

# Ensure ownership and permissions
chown -R ec2-user:ec2-user /opt/venvs/model
chmod -R 755 /opt/venvs/model

# Make cuda libraries available in the virtual environment
#echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.5/lib:$LD_LIBRARY_PATH' >> /opt/venvs/model/bin/activate
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.5/lib:/opt/amazon/efa/lib64:/opt/amazon/openmpi/lib64:/opt/aws-ofi-nccl/lib:/usr/local/cuda-12.4/lib:/usr/local/cuda-12.4/lib64:/usr/local/cuda-12.4:/usr/local/cuda-12.4/targets/x86_64-linux/lib/:/usr/local/lib:/usr/lib:/lib' >> /opt/venvs/model/bin/activate

# Activate virtual environment on login
echo 'source /opt/venvs/model/bin/activate' >> /home/ec2-user/.bashrc

# Confirm installation
python3 --version
pip3 --version
source /opt/venvs/model/bin/activate
python --version

# Download and unpack tar.gz file from S3
aws s3 cp ${MODEL_PACKAGE_S3_URI} /tmp/model.tar.gz
mkdir -p /opt/model
tar -xzvf /tmp/model.tar.gz -C /opt/model

pip install -r /opt/model/requirements.txt

# Ensure ownership and permissions for unpacked files
chown -R ec2-user:ec2-user /opt/model
chmod -R 755 /opt/model

# Run the unpacked file as a service
cat <<EOF > /etc/systemd/system/model.service
[Unit]
Description=Model
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/opt/venvs/model/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
WorkingDirectory=/opt/model
Environment="PATH=/opt/venvs/model/bin:$PATH"
Environment="LD_LIBRARY_PATH=/usr/local/cuda-12.5/lib:/opt/amazon/efa/lib64:/opt/amazon/openmpi/lib64:/opt/aws-ofi-nccl/lib:/usr/local/cuda-12.4/lib:/usr/local/cuda-12.4/lib64:/usr/local/cuda-12.4:/usr/local/cuda-12.4/targets/x86_64-linux/lib/:/usr/local/lib:/usr/lib:/lib"
Restart=always
User=ec2-user
Group=ec2-user

[Install]
WantedBy=multi-user.target
EOF


# Reload systemd to recognize the new service
systemctl daemon-reload

# Enable and start the service
systemctl enable model
systemctl start model

echo "Setup is complete."
