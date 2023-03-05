#VPC and Subnet Creation
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
}

resource "aws_subnet" "east1a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "east1b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
}

#NACL and SG Creation
resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.main.id

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
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
}

resource "aws_security_group" "allow_http_tls" {
  name        = "allow_http_tls"
  description = "Allow TLS and HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "allow_all" {
  type              = "egress"
  to_port           = 0
  from_port         = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_http_tls.id
}

resource "aws_security_group_rule" "allow_http" {
  type              = "ingress"
  to_port           = 80
  from_port         = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_http_tls.id
}

resource "aws_security_group_rule" "allow_tls" {
  type              = "ingress"
  to_port           = 443
  from_port         = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_http_tls.id
}

resource "aws_security_group_rule" "allow_ssh" {
   type             = "ingress"
   to_port          = 22
   from_port        = 22
   protocol         = "tcp"
   cidr_blocks      = ["174.52.122.195/32"]
   security_group_id = aws_security_group.allow_http_tls.id
}

#IGW Creation
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

#RTB Creation
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet" {
  route_table_id              = aws_route_table.main.id
  destination_cidr_block      = "0.0.0.0/0"
  gateway_id                  = aws_internet_gateway.igw.id
  depends_on                  = [aws_route_table.main, aws_internet_gateway.igw]
}