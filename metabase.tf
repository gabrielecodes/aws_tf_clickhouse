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

##################################
# COMPUTE
##################################

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
