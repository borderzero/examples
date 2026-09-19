# Using Border0 to access EC2 instances using SSM

1. First create an SSH service
```
border0 socket create -t ssh -n ec2ssm
```

2. connect to the service. Make sure the machine you're connecting from has the proper IAM permissions to access the EC2 instance. If needed set the correct AWS enviroment variables. For example, if you're using the AWS CLI, you can set the AWS_PROFILE and AWS_REGION variables.

```
AWS_PROFILE=dev AWS_REGION=us-west-2 border0 socket connect ec2ssm --aws_ec2_target i-0f918c9007b111f04
Welcome to Border0.com
ec2ssm - ssh://ec2ssm.border0.app

=======================================================
Logs
=======================================================
207.102.57.34:42860 [Mon, 22 May 2023 19:09:07 UTC] TCP 200 bytes_sent:4125 bytes_received:4944 session_time: 8.09
```

3. Troubleshoot
if needed test if you can connect from the EC2 console or better, from the cli you run `border0 connect` like this. This will make sure you have the proper IAM permissions to access the EC2 instance.

```
$ aws ssm start-session --target i-0f918c9007b111f04 --region us-west-2

Starting session with SessionId: andree@border0.com-03c4342ee6d82f9d0
$ cat /etc/hostname
ip-10-0-2-46
$
```

# Terraform AWS EC2 with SSM Access

This repository contains Terraform scripts for creating an AWS EC2 instance that resides within a private subnet and can be accessed via AWS Systems Manager (SSM).

## Architecture

The Terraform scripts will set up the following resources:

- A VPC with CIDR block `10.0.0.0/16`.
- A public subnet and a private subnet within the created VPC.
- An Internet Gateway attached to the VPC.
- A NAT Gateway deployed into the public subnet.
- Two Route Tables for public and private subnets.
- An IAM role with the `AmazonSSMManagedInstanceCore` policy attached.
- An EC2 instance running Ubuntu 22.04 within the private subnet.

The EC2 instance is placed within the private subnet, thus it can't be accessed directly via SSH. Instead, we use AWS Systems Manager (SSM) to manage and access this instance. This is a secure method that doesn't require SSH keys.

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads.html) installed on your local machine.
2. An AWS account and your AWS credentials (Access Key ID and Secret Access Key) configured via the AWS CLI or environment variables.

## Usage

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/your-repository.git
   cd your-repository
   ```

2. Initialize the Terraform working directory:

   ```bash
   terraform init
   ```

3. Validate the scripts:

   ```bash
   terraform validate
   ```

4. Review the execution plan:

   ```bash
   terraform plan
   ```

5. Apply the changes:

   ```bash
   terraform apply
   ```


If no region is specified, the default region (`us-east-1`) is used.

## Accessing the EC2 Instance

Since the EC2 instance resides in a private subnet, you need to use AWS SSM to connect to it. Go to the AWS SSM console, navigate to `Instances & Nodes > Session Manager` and start a new session to connect to the instance.
