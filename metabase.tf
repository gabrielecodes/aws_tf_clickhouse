##################################
# NETWORK
##################################

# Public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
}

# Security Group
resource "aws_security_group" "metabase" {
  name        = "metabase-sg"
  description = "Allow SSH to my IP and web access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Inbound SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  ingress {
    description = "Inbound Web UI access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-sg-metabase"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-igw"
  }
}

# Public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}


# NAT Gateway
resource "aws_eip" "nat" {}

# Put the NAT Gateway in the public subnet
resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.project}-nat-gateway"
  }
}

# Update the route table for the private subnet
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.gw.id
}

# Route table for the private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-private-rt"
  }
}

# Associate the route table to the private subnets
resource "aws_route_table_association" "private_assoc" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

##################################
# COMPUTE
##################################

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2_key"
  public_key = file("./ec2_key.pub")
}

# Metabase instance
resource "aws_instance" "metabase" {
  ami                    = var.metabase_ami_id
  instance_type          = var.metabase_instance_type
  key_name               = var.ec2_key
  vpc_security_group_ids = [aws_security_group.metabase.id]
  subnet_id              = aws_subnet.public.id

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = "./metabase-install.yaml"

  tags = {
    Name = "${var.project}-metabase-instance"
  }
}

output "metabase_public_ip" {
  value       = aws_instance.metabase.public_ip
  description = "Public instance ip"
}

# Inventory for Ansible
resource "local_file" "inventory" {
  content  = <<EOF
[clickhouse_nodes]
%{for ip in [for inst in aws_instance.clickhouse_node : inst.private_ip]~}
${ip} ansible_user=ubuntu ansible_ssh_private_key_file=/tmp/ec2_key
%{endfor~}
EOF
  filename = "./inventory.ini"
}

output "local_inventory_content" {
  value       = local_file.inventory.content
  description = "Invenotry file for Ansible"
}

locals {
  clickhouse_node_ids = {
    for idx, key in keys(var.clickhouse_nodes) :
    aws_instance.clickhouse_node[key].private_ip => idx + 1
  }
}

# Variables for Ansible
resource "local_file" "ansible_vars" {
  content  = <<EOF
private_dns:
%{for ip in [for inst in aws_instance.clickhouse_node : inst.private_ip]~}
  - ${ip}
%{endfor}
metabase_cidr: "${var.public_subnet_cidr}"
clickhouse_metabase_password: "${var.clickhouse_metabase_password}"
server_ids:
%{for key, id in local.clickhouse_node_ids~}
  ${key}: ${id}
%{endfor~}
EOF
  filename = "./ansible_vars"
}

output "ansible_vars_content" {
  value       = local_file.ansible_vars.content
  description = "Variables for Ansible"
}

# NOTE: This is only for testing
# resource "null_resource" "clickhouse_config" {
#   depends_on = [aws_instance.clickhouse_node]

#   triggers = {
#     private_dns = join(",", [for instance in aws_instance.clickhouse_node : instance.private_dns])
#   }

#   provisioner "local-exec" {
#     connection {
#       type        = "ssh"
#       user        = "ubuntu"
#       host        = aws_instance.metabase.public_ip
#       private_key = file(var.ec2_key)
#     }

#     command = "scp -i ${var.ec2_key} -r ./templates/* ubuntu@${aws_instance.metabase.public_ip}:/tmp"
#   }

#   provisioner "remote-exec" {
#     connection {
#       type        = "ssh"
#       user        = "ubuntu"
#       host        = aws_instance.metabase.public_ip
#       private_key = file(var.ec2_key)
#     }

#     inline = [
#       "set -euxo",
#       "cat > /tmp/ec2_key <<EOF\n${file(var.ec2_key)}\nEOF",
#       "chmod 600 /tmp/ec2_key",
#       "cat > /tmp/clickhouse.yaml <<EOF\n${file("./clickhouse.yaml")}\nEOF",
#       "cat > /tmp/inventory.ini <<EOF\n${local_file.inventory.content}\nEOF",
#       "cat > /tmp/ansible_vars.yml <<EOF\n${local_file.ansible_vars.content}\nEOF",
#       "sudo apt-get update && sudo apt-get install -y ansible",
#       "ansible-playbook -i /tmp/inventory.ini /tmp/clickhouse.yaml --user ubuntu -e @/tmp/ansible_vars.yml"
#     ]
#   }
# }
