##################################
# NETWORK
##################################

data "aws_availability_zones" "available" {}

resource "aws_subnet" "private" {
  for_each = var.private_subnet_cidrs

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.az

  tags = {
    Name = "${var.project}-private-subnet-${each.key}"
  }
}

# Security Group
resource "aws_security_group" "clickhouse" {
  name        = "clickhouse-sg"
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
    description     = "Inbound metabase access"
    from_port       = 8123
    to_port         = 8123
    protocol        = "tcp"
    security_groups = [aws_security_group.metabase.id]
  }

  # ingress {
  #   description     = "Allow distributed queries"
  #   from_port       = 9000
  #   to_port         = 9000
  #   protocol        = "tcp"
  #   security_groups = [self.id]
  # }

  # ingress {
  #   description     = "Allow data replication"
  #   from_port       = 9009
  #   to_port         = 9009
  #   protocol        = "tcp"
  #   security_groups = [self.id]
  # }

  # ingress {
  #   description     = "Allow Raft comms"
  #   from_port       = 9234
  #   to_port         = 9234
  #   protocol        = "tcp"
  #   security_groups = [self.id]
  # }

  # ingress {
  #   description     = "Allow Keeper/ZooKeeper access"
  #   from_port       = 2181
  #   to_port         = 2181
  #   protocol        = "tcp"
  #   security_groups = [self.id]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-sg-clickhouse-nodes"
  }
}

locals {
  clickhouse_self_ports = ["9000", "9009", "9234", "2181"]
}

# Rules for each internal port
resource "aws_security_group_rule" "clickhouse_self_ingress" {
  for_each = toset(local.clickhouse_self_ports)

  type        = "ingress"
  from_port   = each.value
  to_port     = each.value
  protocol    = "tcp"
  description = "Allow self-reference for port ${each.value}"

  security_group_id        = aws_security_group.clickhouse.id
  source_security_group_id = aws_security_group.clickhouse.id
}

##################################
# COMPUTE
##################################

# Clickhouse instance
resource "aws_instance" "clickhouse_node" {
  for_each = var.clickhouse_nodes

  ami                    = var.clickhouse_ami_id
  instance_type          = var.clickhouse_instance_type
  key_name               = var.ec2_key
  vpc_security_group_ids = [aws_security_group.clickhouse.id]
  subnet_id              = aws_subnet.private[each.value.subnet_cidr_key].id

  # user_data = templatefile("${path.module}/clickhouse-install.yaml", {
  #   server_id                    = index(keys(var.clickhouse_nodes), each.key) + 1
  #   is_coordinator               = each.key == "node1"
  #   cluster_name                 = var.clickhouse_cluster_name
  #   private_dns                  = [for instance in aws_instance.clickhouse_node : i.private_dns]
  #   metabase_cidr                = var.public_subnet_cidr
  #   clickhouse_metabase_password = var.clickhouse_metabase_password # password for the metabase "user"
  # })

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  depends_on = [aws_key_pair.ec2_key, aws_subnet.private]

  tags = {
    Name = "${var.project}-clickhouse-instance"
  }
}

# Temporary public ip for node1 to apply the Ansible config
resource "aws_eip" "node1" {
  count    = contains(keys(var.clickhouse_nodes), "node1") ? 1 : 0
  instance = aws_instance.clickhouse_node["node1"].id
}

# Inventory for Ansible
resource "local_file" "inventory" {
  content  = <<EOF
[clickhouse_nodes]
%{for ip in [for inst in aws_instance.clickhouse_node : inst.private_ip]~}
${ip} ansible_user=ubuntu ansible_ssh_private_key_file=./ec2_key.pem
%{endfor~}
EOF
  filename = "./inventory.ini"
}

locals {
  clickhouse_node_ids = {
    for idx, key in keys(var.clickhouse_nodes) :
    key => idx + 1
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

resource "null_resource" "clickhouse_config" {
  depends_on = [aws_instance.clickhouse_node]

  triggers = {
    private_dns = join(",", [for instance in aws_instance.clickhouse_node : instance.private_dns])
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.clickhouse_node["node1"].public_ip
      private_key = file(var.ec2_key)
    }

    inline = [
      "sudo apt-get update && sudo apt-get install -y ansible",
      "echo '${local_file.inventory.content}' > /tmp/inventory.ini",
      "echo '${local_file.ansible_vars.content}' > /tmp/ansible_vars.yml",
      "ansible-playbook -i /tmp/inventory.ini clickhouse.yaml -e @/tmp/ansible_vars.yml"
    ]
  }
}
