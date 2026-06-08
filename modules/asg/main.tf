################################################################################
# Fetch the latest Amazon Linux 2023 AMI automatically
# (so you never need to hard-code an AMI ID)
################################################################################

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

################################################################################
# Security Group — controls what traffic reaches EC2 instances
################################################################################

resource "aws_security_group" "ec2" {
  name        = "${var.name}-ec2-sg"
  description = "Allow inbound from ALB only; allow all outbound"
  vpc_id      = var.vpc_id

  # Only accept traffic that came through the ALB — nothing direct from the internet
  ingress {
    description     = "HTTP from ALB only"
    from_port       = var.instance_port
    to_port         = var.instance_port
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  # SSM Session Manager — lets you shell into instances without SSH keys or bastion hosts
  egress {
    description = "All outbound (needed for SSM, yum updates, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-ec2-sg" }
}

################################################################################
# IAM — EC2 instance profile for SSM access (no SSH keys needed)
################################################################################

resource "aws_iam_role" "ec2_ssm" {
  name = "${var.name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Allows SSM Session Manager to connect (no inbound SSH port needed)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ec2_ssm.name
}

################################################################################
# Launch Template — the blueprint for every EC2 instance in the ASG
################################################################################

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-lt-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type

  # Attach the SSM instance profile
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  network_interfaces {
    associate_public_ip_address = true           # needed in default VPC
    security_groups             = [aws_security_group.ec2.id]
  }

  # User data runs once on first boot — starts a minimal HTTP server on port 8080
  # Replace this with your actual app startup script in production
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Install Python (available by default on AL2023)
    yum install -y python3

    # Write a minimal HTTP server that responds to /health and /
    cat > /home/ec2-user/server.py << 'PYEOF'
    import http.server
    import json

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/health":
                body = json.dumps({"status": "ok"}).encode()
                self.send_response(200)
            else:
                body = json.dumps({"service": "order-worker", "env": "${var.environment}"}).encode()
                self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", len(body))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, fmt, *args):
            pass  # suppress default request logging

    http.server.HTTPServer(("", ${var.instance_port}), Handler).serve_forever()
    PYEOF

    # Start the server as a background process
    nohup python3 /home/ec2-user/server.py &> /var/log/order-worker.log &
  EOF
  )

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.name}-worker"
      Environment = var.environment
    }
  }
}

################################################################################
# Auto Scaling Group — maintains exactly 2 healthy instances across AZs
################################################################################

resource "aws_autoscaling_group" "this" {
  name                = "${var.name}-asg"
  min_size            = var.min_size        # never drop below this
  max_size            = var.max_size        # never exceed this
  desired_capacity    = var.desired_size    # target: 2
  vpc_zone_identifier = var.subnet_ids     # span all AZs in the default VPC

  # Register new instances with the ALB target group automatically
  target_group_arns = [var.target_group_arn]

  # Wait for the health check to pass before marking instance as InService
  health_check_type         = "ELB"   # use ALB health check (not just EC2 status)
  health_check_grace_period = 60      # seconds to wait before first check

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  # Replace instances smoothly when the launch template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50  # keep at least 1 instance up during refresh
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-asg"
    propagate_at_launch = true
  }
}
