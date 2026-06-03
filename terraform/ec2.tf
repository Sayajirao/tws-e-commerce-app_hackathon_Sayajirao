###############################################################################
# Jenkins server EC2  --  PRIVATE SUBNET
#
# REPLICA CHANGES vs. the original:
#   * Launched in an EXISTING PRIVATE subnet (local.subnet_ids[0]) instead of a
#     created public subnet. You reach it from the VDI / browser inside the VPC.
#   * SSH key pair is AUTO-GENERATED (tls_private_key) and written to disk, since
#     there is no terra-key.pub file. Private key saved as ./terra-key.pem.
#   * Elastic IP removed (an EIP is pointless on a private instance).
#   * Security group references local.vpc_id (no module.vpc).
###############################################################################

# Latest Ubuntu 24.04 AMI (Canonical)
data "aws_ami" "os_image" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/*24.04-amd64*"]
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
  vpc_id      = local.vpc_id
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
  ami                    = data.aws_ami.os_image.id
  instance_type          = var.node_instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.allow_user_to_connect.id]
  subnet_id              = local.subnet_ids[0] # private subnet (eu-central-1a)
  user_data              = file("${path.module}/install_tools.sh")
  tags = {
    Name = "Jenkins-Automate"
  }
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}

# --- ORIGINAL Elastic IP (removed): not valid on a private-subnet instance ---
# resource "aws_eip" "jenkins_server_ip" {
#   instance = aws_instance.testinstance.id
#   domain   = "vpc"
# }
