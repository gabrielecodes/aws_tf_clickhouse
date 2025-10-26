# ClickHouse Data Warehouse with Metabase Frontend

This project provides a Terraform configuration to deploy a highly available and fault-tolerant ClickHouse data warehouse cluster on AWS, integrated with Metabase as a business intelligence frontend.

## What this Project Provides

Upon successful deployment, this project will provision:

- A **3-node ClickHouse cluster** that is highly available, fault-tolerant, and secured with TLS.
- A **Metabase instance** accessible via a web browser, ready for you to connect to the deployed ClickHouse cluster as a data source.

## Project Overview

The Terraform configuration sets up the following AWS resources:

- **Virtual Private Cloud (VPC):** A dedicated network environment for your resources.
- **Private Subnets:** For the ClickHouse cluster nodes, ensuring they are not directly exposed to the internet.
- **Public Subnet:** For the Metabase instance, allowing access to its web UI.
- **Security Groups:** Configured to allow necessary communication between ClickHouse nodes, Metabase, and your local machine (for SSH and Metabase UI access).
- **ClickHouse Cluster** (3 Nodes):
  - Three EC2 instances, each running ClickHouse Server.
  - Configured for high availability with a single shard and three replicas.
  - Uses ClickHouse Keeper for distributed coordination.
  - TLS/SSL enabled with self-signed certificates for secure communication.
  - A dedicated `metabase` user is created in ClickHouse for Metabase to connect.
- **Metabase Frontend**:
  - One EC2 instance running Metabase in a Docker container.
  - Metabase uses its default embedded H2 database for internal storage.
  - Configured to allow access to its web UI (port 8080) from your IP address.

## Prerequisites

- **AWS Account:** You need an active AWS account with appropriate sufficient to create VPCs, EC2 instances, subnets, and security groups.
- **AWS Credentials:** Terraform will need your AWS access key and secret key configured on your local machine (e.g., via `~/.aws/credentials` or environment variables).
- **Terraform Basics:** While you don't need to be a Terraform expert, understanding the concepts of `terraform init`, `terraform plan`, and `terraform apply` is essential.
- **EC2 Key Pair:** You will need an existing EC2 Key Pair in your AWS region to SSH into the instances. The name of this key pair will be provided as a variable.
- **IP Address:** The configuration automatically detects your public IP address to allow SSH and Metabase UI access. If your IP changes, you might need to re-run `terraform apply`.
- **Cost:** Deploying AWS resources incurs costs. Be mindful of the instance types and volumes provisioned. Remember to `terraform destroy` when you are done to avoid unnecessary charges.
- **Metabase Setup:** After Metabase is deployed, you will need to access its web UI (via `http://<Metabase_Public_IP>:8080`), complete the initial setup wizard, and then add the ClickHouse cluster as a new data source using the credentials defined in this project.

## Steps to Use This Repository

1.  Prerequisites:

    - Install [Terraform](https://www.terraform.io/downloads).
    - Configure your [AWS CLI credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).
    - Create an [EC2 Key Pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) in your desired AWS region.
      - The EC2 Key Pair is used to SSH into the metabase and clickhouse instances. It can be generated with the `ssh-keygen` utility.
      - Consider using multiple keys in production

2.  Clone the Repository:

    ```bash
    git clone <repository_url>
    cd tf_clickhouse
    ```

3.  Initialize Terraform:

    ```bash
    terraform init
    ```

4.  Review and Customize Variables (Optional):
    Inspect `variables.tf` and consider creating a `terraform.tfvars` file to override default values, especially for `project`, `ec2_key`, and `clickhouse_metabase_password`.
    Example `terraform.tfvars`:

    ```terraform
    project = "my-clickhouse-project"
    ec2_key = "my-ec2-key-pair-name"
    clickhouse_metabase_password = "YourStrongClickHouseMetabasePassword"
    ```

5.  Plan the Deployment:
    Review the changes Terraform will make before applying them.

    ```bash
    terraform plan
    ```

6.  Apply the Configuration:
    This will provision the resources in your AWS account. Confirm with `yes` when prompted.

    ```bash
    terraform apply
    ```

7.  Access Metabase:
    Once `terraform apply` completes, Terraform will output the public IP address of the Metabase instance.
    Navigate to `http://<Metabase_Public_IP>:8080` in your web browser.
    Complete the Metabase setup wizard.

8.  Clean Up:
    To deprovision the resources:

    ```bash
    terraform destroy
    ```

    Confirm with `yes` when prompted.
