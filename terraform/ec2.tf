###############################################################################
# Jenkins server EC2  --  PUBLIC SUBNET (personal account)
#
#   * Canonical's public Ubuntu 24.04 AMI (the org-restricted RCP golden AMI does
#     not exist in a personal account; no SCP blocking public AMIs here).
#   * Launched in a PUBLIC subnet (module.vpc.public_subnets[0]) with an Elastic
#     IP, so you reach Jenkins at http://<eip>:8080 from your browser.
#   * SSH key pair auto-generated (tls_private_key) -> ./terra-key.pem.
###############################################################################

# Canonical's official Ubuntu 24.04 LTS AMI (owner 099720109477).
data "aws_ami" "os_image" {
  owners      = ["099720109477"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# --- Auto-generate an SSH key pair (no terra-key.pub in this repo) -----------
resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "deployer_private_key" {
  content         = tls_private_key.deployer.private_key_pem
  filename        = "${path.module}/terra-key.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "deployer" {
  key_name   = "terra-automate-key"
  public_key = tls_private_key.deployer.public_key_openssh
}

resource "aws_security_group" "allow_user_to_connect" {
  name        = "allow TLS"
  description = "Allow user to connect"
  vpc_id      = module.vpc.vpc_id
  dynamic "ingress" {
    for_each = [
      { description = "port 22 allow", from = 22, to = 22, protocol = "tcp", cidr = ["0.0.0.0/0"] },
      { description = "port 80 allow", from = 80, to = 80, protocol = "tcp", cidr = ["0.0.0.0/0"] },
      { description = "port 443 allow", from = 443, to = 443, protocol = "tcp", cidr = ["0.0.0.0/0"] },
      { description = "port 8080 allow", from = 8080, to = 8080, protocol = "tcp", cidr = ["0.0.0.0/0"] }
    ]
    content {
      description = ingress.value.description
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr
    }
  }

  egress {
    description = "allow all outgoing traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysecurity"
  }
}

resource "aws_instance" "testinstance" {
  ami                         = data.aws_ami.os_image.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.allow_user_to_connect.id]
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  user_data                   = file("${path.module}/install_tools.sh")
  tags = {
    Name = "Jenkins-Automate"
  }
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
}

# Elastic IP so the Jenkins URL is stable across restarts.
resource "aws_eip" "jenkins_server_ip" {
  instance = aws_instance.testinstance.id
  domain   = "vpc"
}
