output "CONTROL_PLANE_IP" {
  value = aws_instance.demo-k8s-aws-alb-master-node.private_ip
  description = "Private IP address of the master node"
}
output "WORKER_NODES_IPs" {
  value = {
    for key, instance in aws_instance.demo-k8s-aws-alb-worker-node :
    key => instance.private_ip
  }
  description = "Private IP addresses of the worker nodes"
}

output "BASTIAN_IP" {
  value = aws_instance.demo-k8s-aws-alb-bastian-node.public_ip
  description = "Private IP address of the master node"
}

output "CONTROL_PLANE_ID" {
  value = aws_instance.demo-k8s-aws-alb-master-node.id
  description = "Private IP address of the master node"
}
output "WORKER_NODES_IDs" {
  value = {
    for key, instance in aws_instance.demo-k8s-aws-alb-worker-node :
    key => instance.id
  }
  description = "Private IP addresses of the worker nodes"
}

output "BASTIAN_ID" {
  value = aws_instance.demo-k8s-aws-alb-bastian-node.id
  description = "Private IP address of the master node"
}