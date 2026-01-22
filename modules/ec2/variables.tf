variable "ami" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "key_name" {}
variable "security_groups" {
  type = list(string)
}


variable "enable_provisioner" {
  type    = bool
  default = false
}


