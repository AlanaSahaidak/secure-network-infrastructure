variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_private_cidr" {
  default = "10.0.1.0/24"
}

variable "subnet_public_cidr" {
  default = "10.0.2.0/24"
}
#Amazon Linux 2023
variable "linux_ami" {
  default = "ami-02141377eee7defb9" 
}

variable "instance_type" {
  default = "t2.micro"
}

variable "region" {
  default = "eu-west-1"
  description = "AWS Region for resources"
}

variable "ssh_key_path" {
  description = "Path to ssh key"
}