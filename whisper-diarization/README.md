# Whisper Diarization

This project uses a speech-to-text model with speaker diarization capabilities. The model processes audio files to
transcribe speech and identify different speakers within the audio.

## Model Used

The Whisper model used
is: [https://huggingface.co/openai/whisper-large-v3](https://huggingface.co/openai/whisper-large-v3)

## Packaging the Application for EC2 deployment

To package the `main.py` and `requirements.txt` files into a `tar.gz` file, follow these steps:

1. Navigate to the `whisper-diarization-no` directory:
    ```sh
    cd whisper-diarization-no
    ```

2. Create a `tar.gz` archive containing `main.py` and `requirements.txt`:
    ```sh
    tar -czvf whisper-diarization-no.tar.gz main.py requirements.txt
    ```

3. Upload the `whisper-diarization.tar.gz` file to the S3 bucket.

## Building the Dockerfile

To build the Docker image using the provided `Dockerfile`, follow these steps:

1. Navigate to the `whisper-diarization` directory:
    ```sh
    cd whisper-diarization-no
    ```

2. Build the Docker image:
    ```sh
    docker build -t whisper-diarization-no .
    ```

3. Run the Docker container:
    ```sh
    docker run --gpus all -p 8000:8000 whisper-diarization-no
    ```

This will start the FastAPI application, exposing it on port 8000. You can then access the API endpoints as defined in
`main.py`.