resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "main"
  }
}

# Get the IP address of this machine
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}
