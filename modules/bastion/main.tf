# bastion/main.tf
resource "aws_instance" "bastion" {
  ami           = "ami-0e83be366243f524a"  # Amazon Linux 2023 in us-east-2
  instance_type = "t3.micro"
  
  subnet_id                   = var.public_subnet_id  # Place in public subnet
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name                   = var.key_name  # You'll need to create/specify an EC2 key pair

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env}-bastion"
  })
}

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.env}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  # SSH access from allowed IPs
  dynamic "ingress" {
    for_each = var.allowed_ips
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "SSH access from ${ingress.value}"
    }
  }

  # Outbound access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}