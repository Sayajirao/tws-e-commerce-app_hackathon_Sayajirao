###############################################################################
# Bastion host EC2  --  PRIVATE SUBNET
#
# REPLICA CHANGES vs. the original:
#   * Launched in an EXISTING PRIVATE subnet (local.subnet_ids[1]) instead of a
#     created public subnet. Reached from the VDI inside the VPC network.
#   * Reuses the auto-generated key pair from ec2.tf (aws_key_pair.deployer).
#   * Security group references local.vpc_id (no module.vpc).
###############################################################################

resource "aws_security_group" "allow_user_bastion" {
  name        = "bastion_host_SG"
  description = "Allow user to connect"
  vpc_id      = local.vpc_id
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
  ami                    = data.aws_ami.os_image.id
  instance_type          = var.node_instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.allow_user_bastion.id]
  subnet_id              = local.subnet_ids[1] # private subnet (eu-central-1c)
  user_data              = file("${path.module}/bastion_user_data.sh")
  tags = {
    Name = "Bastion-Host"
  }
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}
