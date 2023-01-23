#Welcome to Border0 Terraform example
#Configure the AWS Provider
variable "aws_region" {
  type = string
  # default     = "us-west-2"
  description = "AWS region we are deploying to"
}

provider "aws" {
  region = var.aws_region
}

variable "empty_ec2_metadata" {
  type        = string
  default     = "false"
  description = "controlls which metadata variable is passed to EC2 instances"
}

variable "border0_org_cert" {
  type        = string
  default     = "ecdsa-sha2-nistp256 FakeDefaultCAKEyValue="
  description = "Our Border0 Organization SSH CA, use following command to get your org ssh key: $ border0 organization show | grep ecdsa-sha2-nistp256 | awk '{print $5,$6}' "
}

variable "border0_token" {
  type        = string
  default     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyDEM0fQ.5Lsz2zyiQjnTIZ-6XrpGPvGmatwxhsi-1W0Xk8bMDks"
  description = "Border0 token obtained from border0 login"
}

# Create border0 VPC to launch instances into
resource "aws_vpc" "border0-demo-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "border0-demo-vpc"
  }
}

# Create an internet gateway for subnet access to the internet
resource "aws_internet_gateway" "border0-default-gw" {
  vpc_id = aws_vpc.border0-demo-vpc.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.border0-demo-vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.border0-default-gw.id
}

resource "aws_route_table" "border0-public-subnet-rt" {
  depends_on = [
    aws_vpc.border0-demo-vpc,
    aws_internet_gateway.border0-default-gw
  ]
  vpc_id = aws_vpc.border0-demo-vpc.id

  # NAT access rule
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.border0-default-gw.id
  }
  tags = {
    Name = "border0-public-subnet-rt"
  }
}

# routing tables association
resource "aws_route_table_association" "border0-rt-to-gw-association" {

  depends_on = [
    aws_vpc.border0-demo-vpc,
    aws_internet_gateway.border0-default-gw,
    aws_route_table.border0-public-subnet-rt
  ]

  subnet_id      = aws_subnet.border0-public-subnet.id
  route_table_id = aws_route_table.border0-public-subnet-rt.id
}

# eIP for NAT
resource "aws_eip" "border0-eIP-nat-gw" {
  depends_on = [
    aws_route_table_association.border0-rt-to-gw-association
  ]
  vpc = true
}

# Create NAT GW!
resource "aws_nat_gateway" "border0-NAT-gw" {
  depends_on = [
    aws_eip.border0-eIP-nat-gw
  ]
  allocation_id = aws_eip.border0-eIP-nat-gw.id
  subnet_id     = aws_subnet.border0-public-subnet.id
  tags = {
    Name = "border0-NAT-gw"
  }
}

resource "aws_route_table" "border0-NAT-gw-rt" {
  depends_on = [
    aws_nat_gateway.border0-NAT-gw
  ]
  vpc_id = aws_vpc.border0-demo-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.border0-NAT-gw.id
  }

  tags = {
    Name = "border0-NAT-gw-rt"
  }

}

# NAT gw routing table
resource "aws_route_table_association" "Nat-Gateway-RT-Association-0" {
  depends_on     = [aws_route_table.border0-NAT-gw-rt]
  subnet_id      = aws_subnet.border0-private-subnet0.id
  route_table_id = aws_route_table.border0-NAT-gw-rt.id
}
resource "aws_route_table_association" "Nat-Gateway-RT-Association-1" {
  depends_on     = [aws_route_table.border0-NAT-gw-rt]
  subnet_id      = aws_subnet.border0-private-subnet1.id
  route_table_id = aws_route_table.border0-NAT-gw-rt.id
}

resource "aws_subnet" "border0-public-subnet" {
  availability_zone       = "${var.aws_region}a"
  vpc_id                  = aws_vpc.border0-demo-vpc.id
  cidr_block              = "10.0.254.0/24"
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.border0-default-gw]
}

resource "aws_subnet" "border0-private-subnet0" {
  availability_zone       = "${var.aws_region}a"
  vpc_id                  = aws_vpc.border0-demo-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  depends_on              = [aws_internet_gateway.border0-default-gw]
}
resource "aws_subnet" "border0-private-subnet1" {
  availability_zone       = "${var.aws_region}b"
  vpc_id                  = aws_vpc.border0-demo-vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  depends_on              = [aws_internet_gateway.border0-default-gw]
}

resource "aws_security_group" "border0-demo-public-access-group" {
  tags = {
    "Name" = "border0-demo-public-access-group"
  }
  name   = "border0-demo-public-access-group"
  vpc_id = aws_vpc.border0-demo-vpc.id
  ingress {
    description = "Allow ICMP Echo requests"
    from_port   = 8
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # outbound internet access
  egress {
    description = "Allow ALL traffic out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "border0-demo-private-access-group" {
  tags = {
    "Name" = "border0-demo-private-access-group"
  }
  name   = "border0-demo-private-access-group"
  vpc_id = aws_vpc.border0-demo-vpc.id
  ingress {
    description = "Allow ICMP Echo requests"
    from_port   = 8
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8"]
  }
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
  # outbound internet access
  egress {
    description = "Allow ALL traffic out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


##### EC2 instances and structures #######

resource "aws_iam_instance_profile" "border0-demo-connector-instance-profile" {
  name = "border0-demo-connector-instance-profile"
  role = aws_iam_role.border0-demo-connector-instance-role.name
}

resource "aws_iam_role" "border0-demo-connector-instance-role" {
  name               = "border0-demo-connector-instance-role"
  description        = "instance instance Role for EC2 to assume"
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
  tags = {
    "Name" = "border0-demo-connector-instance-role"
  }
}


data "aws_caller_identity" "current" {}
resource "aws_iam_role_policy" "border0-demo-connector-ssm_access" {
  name = "border0-demo-connector-ssm_access"
  #   description = "Grants access to SSM"
  role = aws_iam_role.border0-demo-connector-instance-role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:DescribeParameters"
      ],
      "Resource": [
        "arn:aws:ssm:*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": [
        "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/border0/demo-rds-secret-params"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "border0-demo-connector-ec2-describe" {
  name = "border0-demo-connector-ec2-describe"
  # description = "Grants EC2 describe to border0 connector instance"
  role = aws_iam_role.border0-demo-connector-instance-role.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ec2:Describe*",
            "Resource": "*"
        }
    ]
}
EOF
}


resource "aws_iam_instance_profile" "border0-demo-client-instance-profile" {
  name = "border0-demo-client-instance-profile"
  role = aws_iam_role.border0-demo-client-instance-role.name
}

resource "aws_iam_role" "border0-demo-client-instance-role" {
  name               = "border0-demo-client-instance-role"
  description        = "instance instance Role for EC2 to assume"
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
  tags = {
    "Name" = "border0-demo-client-instance-role"
  }
}


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


locals {
  border0-empty-userdata = <<EOF
#!/bin/bash
#I have been wiped
EOF
}

locals {
  border0-demo-connector-userdata = <<EOF
#!/bin/bash
if [[ ! -e /border0-provisioned ]]
then
  echo -e "# provisioned: $(date)\n# region=${var.aws_region}" > /border0-provisioned
  if [[ ! -d ~/.border0 ]] ; then mkdir -p ~/.border0 ; fi
  echo "${var.border0_token}" > ~/.border0/token
  curl -s https://download.border0.com/demo/border0-install.sh -o ~/border0-install.sh
  chmod +x ~/border0-install.sh
  INSTALL_CONNECTOR=True ~/border0-install.sh | tee -a ~/border0-install.sh.log
else
 echo "nothing to see here"
fi
EOF
}

locals {
  border0-demo-client-userdata = <<EOF
#!/bin/bash
if [[ ! -e /border0-provisioned ]]
then
  echo -e "# provisioned: $(date)\n# region=${var.aws_region}" > /border0-provisioned
  echo -e "${var.border0_org_cert}" > /etc/ssh/border0-ca.pub
  echo "TrustedUserCAKeys /etc/ssh/border0-ca.pub" >/etc/ssh/sshd_config.d/border0.conf
  echo "AuthorizedPrincipalsFile %h/.ssh/authorized_principals" >>/etc/ssh/sshd_config.d/border0.conf
  mkdir /root/.ssh
  echo "mysocket_ssh_signed" > /root/.ssh/authorized_principals

  for HOME_DIR in $(ls /home); do
    SSH_DIR="/home/$${HOME_DIR}/.ssh"
    echo checking $${SSH_DIR}
    if [[ -d $${SSH_DIR} ]]; then echo we have $${SSH_DIR} dir; else echo createing $${SSH_DIR}; mkdir $${SSH_DIR}; fi
    echo "mysocket_ssh_signed" > $${SSH_DIR}/authorized_principals
    chown $${HOME_DIR} $${SSH_DIR} 
  done
  systemctl restart ssh
else
 echo "nothing to see here"
fi

EOF
}


variable "connector_compute_count" {
  type        = string
  description = "Number of Conenctor EC2 instances"
  default     = "1"
}

resource "aws_instance" "border0-demo-connector-instance" {
  depends_on                  = [aws_db_instance.border0-demo-mysql-rds, aws_ssm_parameter.border0-rds-secret-params]
  instance_type               = "t3.nano"
  ami                         = data.aws_ami.ubuntu-image.id
  iam_instance_profile        = aws_iam_instance_profile.border0-demo-connector-instance-profile.name
  vpc_security_group_ids      = [aws_security_group.border0-demo-private-access-group.id]
  subnet_id                   = aws_subnet.border0-private-subnet1.id
  associate_public_ip_address = false
  tags = {
    Name = "border0-connector"
    # border0_ssh = "group=infra_team,port=22,type=ssh"
  }
  count            = var.connector_compute_count
  user_data_base64 = var.empty_ec2_metadata == "false" ? base64encode(local.border0-demo-connector-userdata) : base64encode(local.border0-empty-userdata)

  root_block_device {
    volume_type = "gp3"
  }

  lifecycle {
    create_before_destroy = true
  }
}

variable "client_compute_count" {
  type        = string
  description = "Number of Client EC2 instances"
  default     = "2"
}

resource "aws_instance" "border0-demo-client-instance" {
  instance_type               = "t3.nano"
  ami                         = data.aws_ami.ubuntu-image.id
  iam_instance_profile        = aws_iam_instance_profile.border0-demo-client-instance-profile.name
  vpc_security_group_ids      = [aws_security_group.border0-demo-private-access-group.id]
  subnet_id                   = aws_subnet.border0-private-subnet0.id
  associate_public_ip_address = false
  tags = {
    Name        = "${format("server%02d", count.index)}"
    border0_ssh = "group=infra_team,port=22,type=ssh"
  }
  count            = var.client_compute_count
  user_data_base64 = var.empty_ec2_metadata == "false" ? base64encode(local.border0-demo-client-userdata) : base64encode(local.border0-empty-userdata)
  root_block_device {
    volume_type = "gp3"
  }

  lifecycle {
    create_before_destroy = false
  }
}


##### RDS INSTANCE #####

resource "aws_db_subnet_group" "border0-db-subnet-group" {
  name = "border0-db-subnet-group"
  subnet_ids = [aws_subnet.border0-private-subnet0.id, aws_subnet.border0-private-subnet1.id]

  tags = {
    Name = "border0-db-subnet-group"
  }
}

resource "aws_security_group" "border0-rds" {
  name = "border0-demo_rds"
  vpc_id = aws_vpc.border0-demo-vpc.id

  ingress {
    # pgsql ports
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
  }

  egress {
    # pgsql ports
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
  }

  ingress {
    # mysql ports
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
  }

  egress {
    # mysql ports
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
  }

  tags = {
    Name = "border0-demo_rds"
  }
}

variable "database_name" {
  description = "The name of the database"
  type        = string
  default     = "border0"
}
variable "engine_name" {
  description = "The name of database engine"
  type        = string
  default     = "mysql"
}

variable "family" {
  description = "The family of our database"
  type        = string
  default     = "mysql5.7"
}
variable "major_engine_version" {
  description = "major and minor versions of mysql engine"
  type        = string
  default     = "5.7"
}
variable "engine_version" {
  description = "The version ofdb to be launched"
  default     = "5.7.40"
  type        = string
}

resource "aws_db_option_group" "border-option-group" {
  name                 = var.database_name
  engine_name          = var.engine_name
  major_engine_version = var.major_engine_version

  tags = {
    Name = var.database_name
  }

  option {
    option_name = "MARIADB_AUDIT_PLUGIN"

    option_settings {
      name  = "SERVER_AUDIT_EVENTS"
      value = "CONNECT"
    }
  }
}
resource "aws_db_parameter_group" "border0-parameter-group" {
  name   = var.database_name
  family = var.family

  tags = {
    Name = var.database_name
  }

  parameter {
    name  = "general_log"
    value = "0"
  }
}

# we want to generate a fairly strong and rather long DB password, it will be put into SSM:/border0/demo-rds-secret-params
resource "random_password" "random-rds-password" {
  length  = 40
  special = true
  override_special = "!#$%&-_=:"
}

# this is our RDS mysql instance
resource "aws_db_instance" "border0-demo-mysql-rds" {
  identifier             = var.database_name
  engine                 = var.engine_name
  engine_version         = var.engine_version
  port                   = "3306"
  username               = "border0"
  password               = random_password.random-rds-password.result
  db_name                = var.database_name
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  skip_final_snapshot    = true
  license_model          = "general-public-license"
  db_subnet_group_name   = aws_db_subnet_group.border0-db-subnet-group.name
  vpc_security_group_ids = [aws_security_group.border0-rds.id]
  parameter_group_name   = aws_db_parameter_group.border0-parameter-group.id
  option_group_name      = aws_db_option_group.border-option-group.id
  publicly_accessible    = false

  tags = {
    Name = var.database_name
  }
}

# SSM secret parameter for the connector to consume, will contain RDS credentials and other config params
resource "aws_ssm_parameter" "border0-rds-secret-params" {
  name        = "/border0/demo-rds-secret-params"
  description = "Border0 demo Database sensitive parameters"
  type        = "SecureString"
  depends_on  = [aws_db_instance.border0-demo-mysql-rds]
  value = jsonencode({
    "username" : aws_db_instance.border0-demo-mysql-rds.username,
    "password" : aws_db_instance.border0-demo-mysql-rds.password,
    "engine" : aws_db_instance.border0-demo-mysql-rds.engine,
    "dbname" : aws_db_instance.border0-demo-mysql-rds.identifier,
    "host" : aws_db_instance.border0-demo-mysql-rds.address,
    "port" : aws_db_instance.border0-demo-mysql-rds.port,
  })

  tags = {
    Env  = "demo"
    User = "border0"
  }
}

