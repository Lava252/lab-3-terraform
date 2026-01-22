

################################
# AMI
################################
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

################################
# VPC Module
################################
module "vpc" {
  source = "./modules/vpc"
}

################################
# Security Groups
################################
resource "aws_security_group" "public_sg" {
  name   = "public-ec2-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_security_group" "private_sg" {
  name   = "private-ec2-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################################
# EC2 Modules
################################
module "public_ec2" {
  source          = "./modules/ec2"
  ami             = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  subnet_id       = module.vpc.public_subnets[0]
  key_name        = "terraform-key-new"
  security_groups = [aws_security_group.public_sg.id]
}

module "private_ec2" {
  source          = "./modules/ec2"
  ami             = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  subnet_id       = module.vpc.private_subnets[0]
  key_name        = "terraform-key-new"
  security_groups = [aws_security_group.private_sg.id]
}

################################
# ALB Modules
################################
module "public_alb" {
  source   = "./modules/alb"
  name     = "public-alb"
  internal = false
  subnets  = module.vpc.public_subnets
}

module "private_alb" {
  source   = "./modules/alb"
  name     = "private-alb"
  internal = true
  subnets  = module.vpc.private_subnets
}

################################
# Target Group (Private EC2)
################################
resource "aws_lb_target_group" "private_ec2_tg" {
  name     = "private-ec2-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb_target_group_attachment" "private_ec2_attach" {
  target_group_arn = aws_lb_target_group.private_ec2_tg.arn
  target_id        = module.private_ec2.id
  port             = 80
}

################################
# Public ALB Listener
################################
resource "aws_lb_listener" "public_alb_listener" {
  load_balancer_arn = module.public_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.private_ec2_tg.arn
  }
}

################################
# Provisioner (Public EC2)
################################
resource "null_resource" "public_provisioner" {
  depends_on = [module.public_ec2]

  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y httpd",
      "sudo systemctl start httpd",
      "echo Hello from $(hostname) | sudo tee /var/www/html/index.html"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${path.module}/terraform-key-new.pem")
      host        = module.public_ec2.public_ip
    }
  }
}

################################
# Local Exec (IPs)
################################
resource "null_resource" "all_ips" {
  provisioner "local-exec" {
    command = <<EOT
echo "public-ip ${module.public_ec2.public_ip}" > all-ips.txt
echo "private-ip ${module.private_ec2.private_ip}" >> all-ips.txt
EOT
  }
}

