resource "aws_iam_role" "demo-eks-fargate-profile-role" {
  name = "demo-eks-fargate-profile-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "fargate-execution-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.demo-eks-fargate-profile-role.name
}

resource "aws_eks_fargate_profile" "demo-eks-fg-prof" { 
cluster_name           = aws_eks_cluster.demo-eks-cluster.name
fargate_profile_name   = "demo-eks-fargate-profile-1"
pod_execution_role_arn = aws_iam_role.demo-eks-fargate-profile-role.arn
selector {
    namespace = "kube-system"
    #can further filter by labels
}
selector {
    namespace = "default"
}
#these subnets must be labeled with kubernetes.io/cluster/{cluster-name} = owned
subnet_ids             = [
    aws_subnet.private-subnet-1.id, 
    aws_subnet.private-subnet-2.id
    ]

depends_on = [ aws_iam_role_policy_attachment.fargate-execution-policy ]

}
