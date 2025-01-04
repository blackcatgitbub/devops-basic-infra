resource "aws_iam_role" "demo-eks-ng-role" {
name = "demo-eks-node-group-role"

assume_role_policy = jsonencode({
    Statement = [{
    Action = "sts:AssumeRole"
    Effect = "Allow"
    Principal = {
        Service = "ec2.amazonaws.com"
    }
    }]
    Version = "2012-10-17"
})
}

resource "aws_iam_role_policy_attachment" "eks-demo-ng-WorkerNodePolicy" {
policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
role       = aws_iam_role.demo-eks-ng-role.name 
}

resource "aws_iam_role_policy_attachment" "eks-demo-ng-AmazonEKS_CNI_Policy" {
policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
role       = aws_iam_role.demo-eks-ng-role.name 
}

resource "aws_iam_role_policy_attachment" "eks-demo-ng-ContainerRegistryReadOnly" {
policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
role       = aws_iam_role.demo-eks-ng-role.name 
}

resource "aws_eks_node_group" "eks-demo-node-group" {
cluster_name    = var.cluster_name
node_role_arn   = aws_iam_role.demo-eks-ng-role.arn
node_group_name = "demo-eks-node-group"
subnet_ids      = [
    aws_subnet.private-subnet-1.id, 
    aws_subnet.private-subnet-2.id
    ]
scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
}
update_config {
    max_unavailable = 1
}

# Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
# Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
depends_on = [
    aws_iam_role_policy_attachment.eks-demo-ng-WorkerNodePolicy,
    aws_iam_role_policy_attachment.eks-demo-ng-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-demo-ng-ContainerRegistryReadOnly,
]
}