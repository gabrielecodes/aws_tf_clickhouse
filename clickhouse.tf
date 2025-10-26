##################################
# NETWORK
##################################

# Get the IP address of this machine
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "private" {
  for_each = var.private_subnet_cidrs

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.key
  availability_zone = element(data.aws_availability_zones.available.names, index(var.private_subnet_cidrs, each.key))

  tags = {
    Name = "${var.project}-private-subnet-${each.key}"
  }
}

# Security Group
resource "aws_security_group" "private" {
  name        = "sg-clickhouse-nodes"
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
    security_groups = aws_security_group.metabase.id
  }

  ingress {
    description     = "Allow distributed queries"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [self.id]
  }

  ingress {
    description     = "Allow data replication"
    from_port       = 9009
    to_port         = 9009
    protocol        = "tcp"
    security_groups = [self.id]
  }

  ingress {
    description     = "Allow Raft comms"
    from_port       = 9234
    to_port         = 9234
    protocol        = "tcp"
    security_groups = [self.id]
  }

  ingress {
    description     = "Allow Keeper/ZooKeeper access"
    from_port       = 2181
    to_port         = 2181
    protocol        = "tcp"
    security_groups = [self.id]
  }

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

##################################
# COMPUTE
##################################

# Clickhouse instance
resource "aws_instance" "clickhouse_node" {
  for_each = var.clickhouse_nodes

  ami                    = var.clickhouse_ami_id
  instance_type          = var.clickhouse_instance_type
  key_name               = var.ec2_key
  vpc_security_group_ids = [aws_security_group.private.id]
  subnet_id              = aws_subnet.private[each.value.subnet_cidr_key].id

  user_data = templatefile("${path.module}/clickhouse-install.yaml", {
    server_id                    = index(keys(var.clickhouse_nodes), each.key) + 1
    is_coordinator               = each.key == "node1"
    cluster_name                 = var.clickhouse_cluster_name
    private_dns                  = values(aws_instance.clickhouse_node)[*].private_dns
    clickhouse_metabase_password = var.clickhouse_metabase_password # password for the metabase "user"
  })

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project}-airflow-instance"
  }
}
