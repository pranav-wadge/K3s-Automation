terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-south-1"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "random_id" "suffix" {
  byte_length = 4
}

# ✅ Security Group
resource "aws_security_group" "TF_SG" {
  name        = "k3s-sec-group-${random_id.suffix.hex}"
  description = "Allow web + SSH + K8s API"
  vpc_id      = "vpc-06472eb98932e554e"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k3s-sec-group-${random_id.suffix.hex}"
  }
}

# ✅ EC2 Instance
resource "aws_instance" "app_server" {
  ami                    = "ami-00bb6a80f01f03502"
  instance_type          = "t3.large"
  vpc_security_group_ids = [aws_security_group.TF_SG.id]
  key_name               = "kubers"

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
  }

  tags = {
    Name = "K3sAppServer"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | sh -"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("/home/pranav/Downloads/kubers.pem")
      host        = self.public_ip
    }
  }
}

# ✅ Cloudflare DNS Records
resource "cloudflare_record" "shoes" {
  zone_id         = var.cloudflare_zone_id
  name            = "shoes"
  value           = aws_instance.app_server.public_ip
  type            = "A"
  ttl             = 1
  proxied         = true
  allow_overwrite = true
}

resource "cloudflare_record" "grafana" {
  zone_id         = var.cloudflare_zone_id
  name            = "grafana"
  type            = "A"
  value           = aws_instance.app_server.public_ip
  ttl             = 1
  proxied         = false
  allow_overwrite = true
}

resource "cloudflare_record" "prometheus" {
  zone_id         = var.cloudflare_zone_id
  name            = "prometheus"
  type            = "A"
  value           = aws_instance.app_server.public_ip
  ttl             = 1
  proxied         = false
  allow_overwrite = true
}

resource "cloudflare_record" "loki" {
  zone_id         = var.cloudflare_zone_id
  name            = "loki"
  type            = "A"
  value           = aws_instance.app_server.public_ip
  ttl             = 1
  proxied         = false
  allow_overwrite = true
}

resource "cloudflare_record" "portainer" {
  zone_id         = var.cloudflare_zone_id
  name            = "portainer"
  type            = "A"
  value           = aws_instance.app_server.public_ip
  ttl             = 1
  proxied         = false
  allow_overwrite = true
}

resource "cloudflare_record" "simple" {
  zone_id         = var.cloudflare_zone_id
  name            = "simple"
  type            = "A"
  value           = aws_instance.app_server.public_ip
  ttl             = 1
  proxied         = false
  allow_overwrite = true
}

resource "cloudflare_record" "uptime" {
  zone_id         = var.cloudflare_zone_id
  name            = "uptime"
  type            = "A"
  value           = aws_instance.app_server.public_ip
  ttl             = 1
  proxied         = false
  allow_overwrite = true
}

# ✅ Outputs
output "instance_public_ip" {
  description = "The public IP of your EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "grafana_url" {
  value = "https://grafana.${var.domain_name}"
}

output "shoes_url" {
  value = "https://shoes.${var.domain_name}"
}

output "prometheus_url" {
  value = "https://prometheus.${var.domain_name}"
}

output "loki_url" {
  value = "https://loki.${var.domain_name}"
}

output "portainer_url" {
  value = "https://portainer.${var.domain_name}"
}

output "simple_url" {
  value = "https://simple.${var.domain_name}"
}

output "uptime_url" {
  value = "https://uptime.${var.domain_name}"
}
