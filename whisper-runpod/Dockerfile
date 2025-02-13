# Use NVIDIA's CUDA runtime base image for Ubuntu 22.04
FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04

# Install system dependencies including wget, xz-utils, and python3-pip
RUN apt-get update && \
    apt-get install -y software-properties-common wget xz-utils python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Download and install ffmpeg
RUN wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz && \
    tar -xf ffmpeg-release-amd64-static.tar.xz && \
    mv ffmpeg-*-amd64-static/ffmpeg /usr/local/bin/ && \
    ffmpeg -version && \
    rm -rf ffmpeg-release-amd64-static.tar.xz ffmpeg-*-amd64-static

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file and install Python dependencies
COPY requirements.txt .
RUN python3 -m pip install --no-cache-dir -r requirements.txt

# Copy the application code into the container
COPY main.py .

# (Optional) Remove port exposure as this app is not running a web server
# EXPOSE 8000

# Run the application as a script. This script expects event JSON via a command-line argument or STDIN.
CMD ["python3", "-u", "main.py"]
