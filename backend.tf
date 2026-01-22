terraform {
  backend "s3" {
    bucket = "terraform-lab3-state-bucket"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}

