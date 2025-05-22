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
resource "aws_instance" "demo_argocd_node" {
  ami           = data.aws_ami.latest_ami.id
  instance_type = var.cluster_node_type
  key_name      = var.key_pair
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.demo_argocd_sg.id
  ]
  root_block_device {
    volume_size = 20
  }
  tags =  merge(var.tags, {
    Name = var.node_name
} )
}

resource "aws_security_group" "demo_argocd_sg" {
  # argocd port
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # blog app port
  ingress { 
    from_port   = 30011
    to_port     = 30011
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