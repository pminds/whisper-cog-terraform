resource "aws_lb" "models_loadbalancer" {
  name               = "models-loadbalancer"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.models_lb_sg.id]
  subnets            = module.models_vpc.private_subnets
}

resource "aws_security_group" "models_lb_sg" {
  name        = "models-lb-sg"
  description = "Allow HTTP traffic on port 5000"
  vpc_id      = module.models_vpc.vpc_id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Target group for the cog-whisper-diarization model
resource "aws_lb_target_group" "cog_whisper_diarization_tg" {
  name        = "cog-whisper-diarization-tg"
  port        = 5000
  protocol    = "TCP"
  vpc_id      = module.models_vpc.vpc_id
  target_type = "instance"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    protocol            = "TCP"
  }
}

# Listener for the cog-whisper-diarization model
resource "aws_lb_listener" "cog_whisper_diarization_lb_listener" {
  load_balancer_arn = aws_lb.models_loadbalancer.arn
  port              = 5000
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cog_whisper_diarization_tg.arn
  }
}

# Attach the cog-whisper-diarization model to the target group
resource "aws_lb_target_group_attachment" "tg_attachment" {
  target_group_arn = aws_lb_target_group.cog_whisper_diarization_tg.arn
  target_id        = aws_instance.whisper-diarization.id
  port             = 5000
}
