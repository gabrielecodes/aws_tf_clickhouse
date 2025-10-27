variable "region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "eu-north-1"
}

variable "project" {
  description = "The name of the project."
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "ec2_key" {
  description = "EC2 Key Pair name"
  type        = string
}

### Subnets

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnets."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidrs" {
  description = "A list of CIDR blocks for private subnets."
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
}

variable "secure_tcp_port" {
  description = "The secure TCP port (e.g., 9440) for ClickHouse."
  type        = number
  default     = 9440
}

### Metabase

variable "metabase_instance_type" {
  description = "The type of compute instance to use."
  type        = string
  default     = "t3.medium"
}

variable "metabase_ami_id" {
  description = "The AMI ID for the Metabase compute instance."
  type        = string
  default     = "ami-0393c82ef8ecfdbed" # Ubuntu Server 22.04
}

variable "metabase_username" {
  description = "Username for the metabase instance"
  type        = string
}

variable "metabase_password" {
  description = "Password for the metabase instance"
  type        = string
}

### Clickhouse

variable "clickhouse_cluster_name" {
  description = "Name for the clickhouse cluster"
  type        = string
  default     = "clickhouse_cluster"
}

variable "clickhouse_instance_type" {
  description = "The type of compute instance to use."
  type        = string
  default     = "t3.micro"
}

variable "clickhouse_ami_id" {
  description = "The AMI ID for the Metabase compute instance."
  type        = string
  default     = "ami-0393c82ef8ecfdbed" # Ubuntu Server 22.04
}

variable "clickhouse_metabase_password" {
  description = "Metabase user password for the clickhouse user"
  type        = string
}

variable "clickhouse_nodes" {
  description = "A map defining the ClickHouse cluster nodes."
  type = map(object({
    instance_type   = string
    subnet_cidr_key = string
    replica_id      = number
  }))
  default = {
    node1 = {
      instance_type   = "t3.small"
      subnet_cidr_key = "10.0.2.0/24"
      replica_id      = 1
    }
    node2 = {
      instance_type   = "t3.small"
      subnet_cidr_key = "10.0.3.0/24"
      replica_id      = 2
    }
    node3 = {
      instance_type   = "t3.small"
      subnet_cidr_key = "10.0.4.0/24"
      replica_id      = 2
    }
  }
}
