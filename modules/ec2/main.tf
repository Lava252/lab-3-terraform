resource "aws_instance" "this" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = var.security_groups
user_data = <<EOF
#!/bin/bash
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo Hello from $(hostname) > /var/www/html/index.html
EOF
}


