output "Node_Public_IP" {
  value = aws_instance.demo_cert_manager_node.public_ip
  description = "Public IP for the node"
}
