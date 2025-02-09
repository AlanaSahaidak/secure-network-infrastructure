resource "aws_vpc" "nebo_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "vpc_nebo"
  }
}

resource "aws_subnet" "nebo_public_subnet" {
  vpc_id                  = aws_vpc.nebo_vpc.id
  cidr_block              = var.subnet_public_cidr
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_nebo"
  }
}

resource "aws_subnet" "nebo_private_subnet" {
  vpc_id     = aws_vpc.nebo_vpc.id
  cidr_block = var.subnet_private_cidr
  tags = {
    Name = "private_subnet_nebo"
  }
}

resource "aws_internet_gateway" "nebo_igw" {
  vpc_id = aws_vpc.nebo_vpc.id
  tags = {
    Name = "igw-vnet-nebo"
  }
}

resource "aws_route_table" "nebo_route_table" {
  vpc_id = aws_vpc.nebo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nebo_igw.id
  }
}

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.nebo_public_subnet.id
  route_table_id = aws_route_table.nebo_route_table.id
}

resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.nebo_vpc.id

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
    Name = "bastion_sg"
  }
}

resource "aws_instance" "bastion" {
  ami           = var.linux_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.nebo_public_subnet.id
  key_name      = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "bastion"
  }
}

resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.nebo_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private_sg"
  }
}

resource "aws_key_pair" "main" {
  key_name   = "nebo_key"
  public_key = file("${var.ssh_key_path}.pub")
}

resource "aws_instance" "linux" {
  ami           = var.linux_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.nebo_private_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name      = aws_key_pair.main.key_name

  tags = {
    Name = "vm-nebo-linux"
  }
}

resource "aws_network_acl" "public_acl" {
  vpc_id = aws_vpc.nebo_vpc.id

  ingress {
    protocol   = "icmp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 400
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
  protocol   = "-1"
  rule_no    = 500
  action     = "allow"
  cidr_block = "10.0.0.0/16"
  from_port  = 0
  to_port    = 0
 }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  
  tags = {
    Name = "main-nacl"
  }
}

resource "aws_network_acl_association" "public_association" {
  network_acl_id = aws_network_acl.public_acl.id
  subnet_id      = aws_subnet.nebo_public_subnet.id
}

resource "aws_network_acl" "private_acl" {
  vpc_id = aws_vpc.nebo_vpc.id

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.subnet_public_cidr
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "-1"
    rule_no    = 200
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "private-nacl-nebo"
  }
}

resource "aws_network_acl_association" "private_association" {
  network_acl_id = aws_network_acl.private_acl.id
  subnet_id      = aws_subnet.nebo_private_subnet.id
}

resource "aws_iam_user" "nebo_user" {
  name = "nebo"
  tags = {
    Name = "nebo_user"
  }
}

resource "aws_iam_policy" "nebo_policy" {
  name        = "nebo_policy"
  description = "Policy for limited access to Bastion server"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ec2:DescribeSecurityGroups"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:Connect"]
        Resource = "*"
        Condition = {
          "StringEquals" : {
            "ec2:ResourceTag/Name": "bastion"
          }
        }
      },
      {
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "nebo_user_policy_attachment" {
  user       = aws_iam_user.nebo_user.name
  policy_arn = aws_iam_policy.nebo_policy.arn
}

resource "aws_iam_access_key" "nebo_access_key" {
  user = aws_iam_user.nebo_user.name
}
