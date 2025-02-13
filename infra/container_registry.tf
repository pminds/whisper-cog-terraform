resource "aws_ecr_repository" "container_registry" {
  name = "cog-whisper-diarization"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "whisper_diarization_no" {
  name = "whisper-diarization-no"
  image_scanning_configuration {
    scan_on_push = true
  }
}
