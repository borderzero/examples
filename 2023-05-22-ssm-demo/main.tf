variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_count" {
  description = "Number of instances to create"
  default     = 1
}


provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "border0-demo"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "private_subnet"
  }
}

resource "aws_eip" "nat" {
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "border0-demo"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "public_route_table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = {
    Name = "private_route_table"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_iam_role" "ssm_role" {
  name = "ssm_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm_profile"
  role = aws_iam_role.ssm_role.name
}

# Attached the AmazonSSMManagedInstanceCore policy to the role
resource "aws_iam_role_policy_attachment" "ssm_role_policy_attachment" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Ubuntu has the SSM agent pre-installed
data "aws_ami" "ubuntu-image" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477", ] # Canonical
}


# Now create the EC2 instance. Place it in the private subnet and attach the IAM role
resource "aws_instance" "main" {
  count = var.instance_count
  ami           = data.aws_ami.ubuntu-image.id  
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id 
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  
  tags = {
    Name = "ssm-border0-demo-${count.index}",
    border0 = "group=infra_team,type=ssh"
    
  }
}

# Now we'll create the connector.  It will be the ssm client 
# and needs ssm client iam permissions

# Firstly, create a new IAM role for the second EC2 instance:

resource "aws_iam_role" "connector_role" {
  name = "border0_connector_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#Then, create an IAM policy for the required permissions:

resource "aws_iam_policy" "connector_policy" {
  name = "border0_connector_policy"
  description = "Policy for SSM client permissions"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:StartSession",
        "ssm:TerminateSession",
        "ec2:Describe*",
        "iam:SimulatePrincipalPolicy"

      ],
      "Resource": "*"
    }
  ]
}
EOF
}

#Then, attach the policy to the role:

resource "aws_iam_role_policy_attachment" "connector_policy_attachment" {
  role       = aws_iam_role.connector_role.name
  policy_arn = aws_iam_policy.connector_policy.arn
}

# Create an instance profile for the role:

resource "aws_iam_instance_profile" "connector_profile" {
  name = "b0_connector_profile"
  role = aws_iam_role.connector_role.name
}


resource "aws_instance" "ssm_client" {
  ami           = data.aws_ami.ubuntu-image.id  
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  iam_instance_profile = aws_iam_instance_profile.connector_profile.name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  tags = {
    Name = "ssm-border0-connector"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}
