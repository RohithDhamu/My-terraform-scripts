#Vpc creation
resource "aws_vpc" "card-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "card_vpc"
  }
}

#Subnet config
resource "aws_subnet" "subnet-1a" {
  vpc_id                  = aws_vpc.card-vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-1a"
  }
}

resource "aws_subnet" "subnet-1b" {
  vpc_id                  = aws_vpc.card-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-1b"
  }
}

resource "aws_subnet" "subnet-1c" {
  vpc_id            = aws_vpc.card-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1c"

  tags = {
    Name = "subnet-1c"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "practice"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCpxJ9PJg9zHqp5uwh74aeTbrPARHeRDIlUb9/9PL9xn7yO5JgGLANCwa22OPVSdByTv6mAAJgHs5vWfT4E949pNZk8tvzgSUJj5d9/mPBB+lkivv4dqzFxDc5XT6G70d8ayqL/BpU4NAzXsf7uUbfvTaQKanOFQJw/tqH5ijxhJgeS0rIF+YLg+hxEqSkYAEN16eruYk9ZFxIxRG36YU60GmKEimINi4wImeWek8bnkH5ymiASMcEBggqSvHnr0H7WJK1ZEaNiGAcOHU5Hzh3zIIeWnPSevoYU9SuOvSSSEd/eiIRqmL3G/luIHsBA3GoEzFx14PXl7srehiPh+LwW/chaO1RisB5Ak3VEGsJUPNWYgcVyjyp/9DlypH8KHs5byJ9kMzwhUZMba9jCWCAtapfNbEuxGG/Mu6Ghfi7OcewETHuc0ElvpSFWf0bj2WNaEH9Q36ZGjOWBMMdEP2oAABCVXf073xjlIwRgDQvkZWUbimARt0zffkYePbZ4ZX0= ELCOT@Lenovo"
}

#security group
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.card-vpc.id

  ingress {
    description = "SSH from my laptop"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from my laptop"
    from_port   = 80
    to_port     = 80
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

#instance
resource "aws_instance" "card-website-01" {
  ami                    = "ami-0bdcf181df584b019"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  subnet_id              = aws_subnet.subnet-1a.id

  tags = {
    Name = "card-01"
  }
}

resource "aws_instance" "card-website-02" {
  ami                    = "ami-0bdcf181df584b019"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  subnet_id              = aws_subnet.subnet-1b.id

  tags = {
    Name = "card-02"
  }
}

#internet gateway
resource "aws_internet_gateway" "card-ig" {
  vpc_id = aws_vpc.card-vpc.id

  tags = {
    Name = "card-ig"
  }
}

#Route table
resource "aws_route_table" "card-rt" {
  vpc_id = aws_vpc.card-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.card-ig.id
  }
  tags = {
    Name = "card-rt"
  }
}

resource "aws_route_table_association" "card_RT_ASSO_Public-1" {
  subnet_id      = aws_subnet.subnet-1a.id
  route_table_id = aws_route_table.card-rt.id
}

resource "aws_route_table_association" "card_RT_ASSO_Public-2" {
  subnet_id      = aws_subnet.subnet-1b.id
  route_table_id = aws_route_table.card-rt.id
}

#Target group
resource "aws_lb_target_group" "card-tg" {
  name     = "card-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.card-vpc.id
}

#attach target group
resource "aws_lb_target_group_attachment" "card-attachment-01" {
  target_group_arn = aws_lb_target_group.card-tg.arn
  target_id        = aws_instance.card-website-01.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "card-attachment-02" {
  target_group_arn = aws_lb_target_group.card-tg.arn
  target_id        = aws_instance.card-website-02.id
  port             = 80
}

#LB
resource "aws_lb" "card-lb" {
  name               = "card-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_ssh.id]
  subnets            = [aws_subnet.subnet-1a.id, aws_subnet.subnet-1b.id]

  #enable_deletion_protection = true
  tags = {
    Environment = "production"
  }
}

#Listener
resource "aws_lb_listener" "card-listener" {
  load_balancer_arn = aws_lb.card-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.card-tg.arn
  }
}
