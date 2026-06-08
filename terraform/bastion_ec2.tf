###############################################################################
# Bastion host EC2  --  PUBLIC SUBNET (personal account)
#
#   * Launched in a PUBLIC subnet (module.vpc.public_subnets[1]) so you can SSH
#     in directly using terra-key.pem.
#   * Reuses the auto-generated key pair + public Ubuntu AMI from ec2.tf.
###############################################################################

resource "aws_security_group" "allow_user_bastion" {
  name        = "bastion_host_SG"
  description = "Allow user to connect"
  vpc_id      = module.vpc.vpc_id
  dynamic "ingress" {
    for_each = [
      { description = "port 22 allow", from = 22, to = 22, protocol = "tcp", cidr = ["0.0.0.0/0"] },
      { description = "port 80 allow", from = 80, to = 80, protocol = "tcp", cidr = ["0.0.0.0/0"] },
      { description = "port 443 allow", from = 443, to = 443, protocol = "tcp", cidr = ["0.0.0.0/0"] }
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
    Name = "bastion_security"
  }
}

resource "aws_instance" "bastion_host" {
  ami                         = data.aws_ami.os_image.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.allow_user_bastion.id]
  subnet_id                   = module.vpc.public_subnets[1]
  associate_public_ip_address = true
  user_data                   = file("${path.module}/bastion_user_data.sh")
  tags = {
    Name = "Bastion-Host"
  }
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
}
