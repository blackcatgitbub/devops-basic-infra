# retrieve the latest AMI
data "aws_ami" "latest_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["amazon"]
}

# create EC2 resource
resource "aws_instance" "demo_cert_manager_node" {
  ami           = data.aws_ami.latest_ami.id
  instance_type = var.cluster_node_type
  key_name      = var.key_pair
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.demo_cert_manager.id
  ]
  root_block_device {
    volume_size = 20
  }
  tags =  merge(var.tags, {
    Name = var.node_name
} )
}

resource "aws_security_group" "demo_cert_manager" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}