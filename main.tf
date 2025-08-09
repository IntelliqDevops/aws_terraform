terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.54.1"
    }
  }
}
provider "aws" {
  region = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "myvpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name="myvpc"
  }
}
resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = var.public_subnet_cidr
  map_public_ip_on_launch = var.public_ip
  availability_zone = var.availability_zone
  tags = {
    Name="public_subnet"
  }
}
resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = var.private_subnet_cidr
  availability_zone = var.availability_zone
  tags = {
    Name="private_subnet"
  }
}
resource "aws_internet_gateway" "my_gateway" {
  vpc_id = aws_vpc.myvpc.id
  tags = {
    Name="my_gateway"
  }
}

resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.myvpc.id
  tags = {
    Name="my_route_table"
  }
}
resource "aws_route" "my_route" {
  route_table_id = aws_route_table.my_route_table.id
  destination_cidr_block = var.all_traffic
  gateway_id = aws_internet_gateway.my_gateway.id
}
resource "aws_route_table_association" "my_association" {
  route_table_id = aws_route_table.my_route_table.id
  subnet_id = aws_subnet.public_subnet.id
}
resource "aws_security_group" "my_security" {
  name = var.security_group_name
  vpc_id = aws_vpc.myvpc.id
  ingress {
    from_port = var.port
    to_port = var.port
    protocol = var.protocol
    cidr_blocks = [var.all_traffic]
  }
  egress {
    from_port = var.port
    to_port = var.port
    protocol = var.protocol
    cidr_blocks = [var.all_traffic]
  }
  tags = {
    Name="my_security"
  }
}

resource "aws_instance" "myinstance" {
  ami = var.ami
  instance_type = var.instance_type
  subnet_id = aws_subnet.public_subnet.id
  associate_public_ip_address = var.public_ip
  vpc_security_group_ids = [aws_security_group.my_security.id]
  key_name = var.key_name

  user_data = <<-EOF
           #!/bin/bash
           apt-get update
           apt-get install -y tomcat10
           systemctl start tomcat10
           systemctl enable tomcat10
           apt-get install -y apache2
           systemctl start apache2
           systemctl enable apache2
           EOF
  tags = {
    Name="myinstance"
  }
}

resource "aws_ami_from_instance" "tomcat-apache" {
  name               = "tomcat-apache"
  source_instance_id = aws_instance.myinstance.id
}
resource "aws_launch_template" "mytemplate" {
  name = "mytemplate"
  image_id = aws_ami_from_instance.tomcat-apache.id
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.my_security.id]
  
}
resource "aws_autoscaling_group" "mygroup" {
  max_size = 4 
  min_size = 2 
  desired_capacity = 2 
  vpc_zone_identifier = [aws_subnet.public_subnet.id]
  launch_template {
    id = aws_launch_template.mytemplate.id
    version = "$Latest"
  }
  
}




