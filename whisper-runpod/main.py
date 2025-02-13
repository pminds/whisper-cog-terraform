import logging
import subprocess
import os
import requests
import time
import torch
import re
import sys
import json

from pydantic import BaseModel
from typing import Optional

from faster_whisper import WhisperModel
from pyannote.audio import Pipeline
import torchaudio

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)


# Retrieve the Hugging Face token from the environment variable
hugging_face_token = os.getenv("HUGGING_FACE_TOKEN")
if not hugging_face_token:
    raise ValueError("The HUGGING_FACE_TOKEN environment variable is not set.")


# Models
class Output(BaseModel):
    segments: list
    language: Optional[str] = None
    num_speakers: Optional[int] = None


class PredictRequest(BaseModel):
    file_string: Optional[str] = None
    file_url: Optional[str] = None
    # Changed from UploadFile to str, since we are now handling URLs only.
    file: Optional[str] = None
    group_segments: bool = True
    transcript_output_format: str = "both"
    num_speakers: Optional[int] = None
    translate: bool = False
    language: Optional[str] = None
    prompt: Optional[str] = None
    offset_seconds: int = 0


# Model initializations
model_name = "NbAiLab/nb-whisper-large"
whisper_model = WhisperModel(
    model_name,
    device="cuda" if torch.cuda.is_available() else "cpu",
    compute_type="float32",
)

diarization_model = Pipeline.from_pretrained(
    "pyannote/speaker-diarization-3.1",
    use_auth_token=hugging_face_token,
).to(torch.device("cuda"))


def predict(event: dict, predict_request: PredictRequest) -> Output:
    logger.debug("Received predict event")
    temp_wav_filename = f"temp-{time.time_ns()}.wav"
    temp_input_filename = None
    try:
        # Instead of awaiting request.json(), we simply use the provided event dict.
        body = event
        logger.debug("Received event: %s", body)

        if "input" not in body:
            raise ValueError("Missing 'input' field in event body")

        input_data = body["input"]
        file_url = input_data.get("file_url")
        file_from_json = input_data.get(
            "file"
        )  # if 'file' is a URL, handle it like file_url

        logger.debug("file_url: %s", file_url)
        logger.debug("file (from JSON): %s", file_from_json)

        temp_input_filename = f"temp-{time.time_ns()}.input"

        if file_url or file_from_json:
            download_url = file_url if file_url else file_from_json
            logger.debug("Downloading file from URL: %s", download_url)

            headers = {"User-Agent": "File-Downloader"}
            response = requests.get(
                download_url, headers=headers, timeout=10, allow_redirects=True
            )

            if response.status_code != 200:
                logger.error("Failed to download file from URL: %s", download_url)
                raise ValueError("Failed to download file from URL")

            with open(temp_input_filename, "wb") as f:
                f.write(response.content)
            logger.debug("File downloaded and saved as %s", temp_input_filename)

            result = subprocess.run(
                [
                    "ffmpeg",
                    "-i",
                    temp_input_filename,
                    "-ar",
                    "16000",
                    "-ac",
                    "1",
                    "-c:a",
                    "pcm_s16le",
                    temp_wav_filename,
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            logger.debug("ffmpeg output: %s", result.stdout)
            logger.debug("ffmpeg error: %s", result.stderr)
            if result.returncode != 0:
                raise RuntimeError(
                    f"ffmpeg failed with return code {result.returncode}"
                )
            if os.path.exists(temp_input_filename):
                os.remove(temp_input_filename)
                logger.debug("Temporary audio file removed")
        else:
            raise ValueError(
                "Either 'file', 'file_url', or uploaded file must be provided"
            )

        logger.debug("Starting speech-to-text processing")
        segments, detected_num_speakers, detected_language = speech_to_text(
            temp_wav_filename,
            predict_request.num_speakers,
            predict_request.prompt,
            predict_request.offset_seconds,
            predict_request.group_segments,
            predict_request.language,
            word_timestamps=True,
            transcript_output_format=predict_request.transcript_output_format,
            translate=predict_request.translate,
        )
        logger.debug("Speech-to-text processing completed")

        return Output(
            segments=segments,
            language=detected_language,
            num_speakers=detected_num_speakers,
        )

    except requests.exceptions.RequestException as req_err:
        logger.error("Request error while downloading file: %s", req_err)
        raise ValueError("Error downloading file: " + str(req_err))
    except Exception as e:
        logger.error("Error processing file: %s", e)
        raise e
    finally:
        if temp_input_filename and os.path.exists(temp_input_filename):
            os.remove(temp_input_filename)
            logger.debug("Temporary input file removed")


def speech_to_text(
    audio_file_wav,
    num_speakers=None,
    prompt="",
    offset_seconds=0,
    group_segments=True,
    language=None,
    word_timestamps=True,
    transcript_output_format="both",
    translate=False,
):
    time_start = time.time()
    logger.debug("Starting transcription")

    options = dict(
        vad_filter=True,
        vad_parameters=dict(min_silence_duration_ms=1000),
        initial_prompt=prompt,
        word_timestamps=word_timestamps,
        language=language,
        task="translate" if translate else "transcribe",
        hotwords=prompt,
    )
    segments, transcript_info = whisper_model.transcribe(audio_file_wav, **options)
    segments = list(segments)
    segments = [
        {
            "avg_logprob": s.avg_logprob,
            "start": float(s.start + offset_seconds),
            "end": float(s.end + offset_seconds),
            "text": s.text,
            "words": [
                {
                    "start": float(w.start + offset_seconds),
                    "end": float(w.end + offset_seconds),
                    "word": w.word,
                    "probability": w.probability,
                }
                for w in s.words
            ],
        }
        for s in segments
    ]

    time_transcribing_end = time.time()
    logger.debug(
        "Transcription completed in %.5f seconds", time_transcribing_end - time_start
    )

    logger.debug("Starting diarization")
    waveform, sample_rate = torchaudio.load(audio_file_wav)
    diarization = diarization_model(
        {"waveform": waveform, "sample_rate": sample_rate},
        num_speakers=num_speakers,
    )

    time_diarization_end = time.time()
    logger.debug(
        "Diarization completed in %.5f seconds",
        time_diarization_end - time_transcribing_end,
    )

    margin = 0.1
    final_segments = []
    diarization_list = list(diarization.itertracks(yield_label=True))
    unique_speakers = {
        speaker for _, _, speaker in diarization.itertracks(yield_label=True)
    }
    detected_num_speakers = len(unique_speakers)

    speaker_idx = 0
    n_speakers = len(diarization_list)

    for segment in segments:
        segment_start = segment["start"] + offset_seconds
        segment_end = segment["end"] + offset_seconds
        segment_text = []
        segment_words = []

        for word in segment["words"]:
            word_start = word["start"] + offset_seconds - margin
            word_end = word["end"] + offset_seconds + margin

            while speaker_idx < n_speakers:
                turn, _, speaker = diarization_list[speaker_idx]

                if turn.start <= word_end and turn.end >= word_start:
                    segment_text.append(word["word"])
                    word["word"] = word["word"].strip()
                    segment_words.append(word)

                    if turn.end <= word_end:
                        speaker_idx += 1

                    break
                elif turn.end < word_start:
                    speaker_idx += 1
                else:
                    break

        if segment_text:
            combined_text = "".join(segment_text)
            cleaned_text = re.sub("  ", " ", combined_text).strip()
            new_segment = {
                "avg_logprob": segment["avg_logprob"],
                "start": segment_start - offset_seconds,
                "end": segment_end - offset_seconds,
                "speaker": speaker,
                "text": cleaned_text,
                "words": segment_words,
            }
            final_segments.append(new_segment)

    time_merging_end = time.time()
    logger.debug(
        "Merging completed in %.5f seconds", time_merging_end - time_diarization_end
    )

    if not final_segments:
        logger.debug("No final segments found")
        return [], detected_num_speakers, transcript_info.language

    segments = final_segments
    output = []

    current_group = {
        "start": segments[0]["start"],
        "end": segments[0]["end"],
        "speaker": segments[0]["speaker"],
        "avg_logprob": segments[0]["avg_logprob"],
    }

    if transcript_output_format in ("segments_only", "both"):
        current_group["text"] = segments[0]["text"]
    if transcript_output_format in ("words_only", "both"):
        current_group["words"] = segments[0]["words"]

    for i in range(1, len(segments)):
        time_gap = segments[i]["start"] - segments[i - 1]["end"]

        if (
            segments[i]["speaker"] == segments[i - 1]["speaker"]
            and time_gap <= 2
            and group_segments
        ):
            current_group["end"] = segments[i]["end"]
            if transcript_output_format in ("segments_only", "both"):
                current_group["text"] += " " + segments[i]["text"]
            if transcript_output_format in ("words_only", "both"):
                current_group.setdefault("words", []).extend(segments[i]["words"])
        else:
            output.append(current_group)
            current_group = {
                "start": segments[i]["start"],
                "end": segments[i]["end"],
                "speaker": segments[i]["speaker"],
                "avg_logprob": segments[i]["avg_logprob"],
            }
            if transcript_output_format in ("segments_only", "both"):
                current_group["text"] = segments[i]["text"]
            if transcript_output_format in ("words_only", "both"):
                current_group["words"] = segments[i]["words"]

    output.append(current_group)

    time_cleaning_end = time.time()
    logger.debug(
        "Cleaning completed in %.5f seconds", time_cleaning_end - time_merging_end
    )
    time_end = time.time()
    logger.debug("Total processing time: %.5f seconds", time_end - time_start)

    return output, detected_num_speakers, transcript_info.language


def handler(event: dict) -> dict:
    """
    Entry point for serverless usage.
    Expects `event` to be a dict with an "input" key containing the parameters.
    """
    try:
        predict_request = PredictRequest(**event["input"])
    except Exception as e:
        raise ValueError("Invalid input parameters: " + str(e))
    result = predict(event, predict_request)
    return result.dict()


if __name__ == "__main__":
    # For local testing, read the event JSON from a command-line argument or standard input.
    if len(sys.argv) > 1:
        event = json.loads(sys.argv[1])
    else:
        event = json.load(sys.stdin)
    output = handler(event)
    print(json.dumps(output))
