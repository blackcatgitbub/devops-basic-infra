## Things not covered in the Video
- Setting up IRSA or pod identity to enable aws access for pods 
- No additional access points, means providing admin permissions to be whoever creates the cluster
- No logging or observability enable for the cluster, so will override default for modules
- not enabling encryption - not creating KMS

## Without Module

1. Create `0-provider.tf` file 
    - specify the provider using required providers block and region using provider block
    ```
    terraform {
    required_providers {
        aws = {
        source = "hashicorp/aws"
        version = "5.82.2"
        }
    }

    }
    provider "aws" {
    region = var.region
    }
    ```
2. create variables file `1-variable.tf` and add region variable
    ```
    variable "region" {
    type = string
    default = "us-east-1"
    description = "AWS region"
    }
    ```

3. Define variables for vpc cidr and cluster name
    ```
    variable "cidr_block" {
    type = string
    default = "10.10.0.0/16"
    
    }

    variable "tags" {
    type = map(string)
    default = {
        terraform  = "true"
        kubernetes = "demo-eks-cluster"
    }
    description = "Tags to apply to all resources"
    }
    ```

4. Create vpc file - `1-vpc.tf` 
    - Using data source get AZs names
    ```
    data "aws_availability_zones" "available" {
    state = "available"
    }
    ```
5. Create VPC and its components
    - define vpc, enable dns_hostnames
    ```
    resource "aws_vpc" "demo-eks-cluster-vpc" {
    cidr_block       = var.cidr_block
    enable_dns_hostnames = true
    tags = var.tags
    }
    ```
    - create 4 subnets - 2x public, 2x private
    ```
    resource "aws_subnet" "public-subnet-1" {
    vpc_id     = aws_vpc.demo-eks-cluster-vpc.id
    cidr_block = cidrsubnet(var.cidr_block, 8, 10)
    availability_zone = data.aws_availability_zones.available.names[0]
    tags = var.tags
    }

    resource "aws_subnet" "public-subnet-2" {
    vpc_id     = aws_vpc.demo-eks-cluster-vpc.id
    cidr_block = cidrsubnet(var.cidr_block, 8, 20)
    availability_zone = data.aws_availability_zones.available.names[1]
    tags = var.tags
    }

    resource "aws_subnet" "private-subnet-1" {
    vpc_id     = aws_vpc.demo-eks-cluster-vpc.id
    cidr_block = cidrsubnet(var.cidr_block, 8, 110)
    availability_zone = data.aws_availability_zones.available.names[0]
    tags = var.tags
    }

    resource "aws_subnet" "private-subnet-2" {
    vpc_id     = aws_vpc.demo-eks-cluster-vpc.id
    cidr_block = cidrsubnet(var.cidr_block, 8, 120)
    availability_zone = data.aws_availability_zones.available.names[1]

    tags = var.tags
    }
    ```
    - Define Internet gateway, NAT gateway, elastic IP for nat gw
    ```
    resource "aws_internet_gateway" "eks-igw" {
    vpc_id = aws_vpc.demo-eks-cluster-vpc.id

    tags = var.tags
    }

    resource "aws_eip" "eks-ngw-eip" {
    domain = "vpc"

    tags = var.tags
    depends_on = [aws_internet_gateway.eks-igw]
    }

    resource "aws_nat_gateway" "eks-ngw" {
    allocation_id = aws_eip.eks-ngw-eip.id
    subnet_id     = aws_subnet.public-subnet-1.id

    depends_on = [aws_internet_gateway.eks-igw]
    tags = var.tags
    }
    ```
    - create route tables 
    ```
    resource "aws_route_table" "public-rt" {
    vpc_id = aws_vpc.demo-eks-cluster-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.eks-igw.id
    }
    tags = var.tags
    }

    resource "aws_route_table"  "private-rt" {
    vpc_id = aws_vpc.demo-eks-cluster-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.eks-ngw.id
    }
    tags = var.tags
    }
    ```
    - Associate those route tables with subnets
    ```
    resource "aws_route_table_association" "public-rt-assoc-1" {
    subnet_id      = aws_subnet.public-subnet-1.id
    route_table_id = aws_route_table.public-rt.id
    }

    resource "aws_route_table_association" "public-rt-assoc-2" {
    subnet_id      = aws_subnet.public-subnet-2.id
    route_table_id = aws_route_table.public-rt.id
    }

    resource "aws_route_table_association" "private-rt-assoc-1" {
    subnet_id      = aws_subnet.private-subnet-1.id
    route_table_id = aws_route_table.private-rt.id
    }

    resource "aws_route_table_association" "private-rt-assoc-2" {
    subnet_id      = aws_subnet.private-subnet-2.id
    route_table_id = aws_route_table.private-rt.id
    }
    ```

6. Creating EKS Cluster, create `3-eks.tf` file
    - Define IAM role - role that allows eks cluster to assume [role](https://docs.aws.amazon.com/eks/latest/userguide/cluster-iam-role.html)
    ```
    resource "aws_iam_role" "demo-eks-cluster-role" {
    name = "demo-eks-cluster-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = [
            "sts:AssumeRole",
            ]
            Effect = "Allow"
            Principal = {
            Service = "eks.amazonaws.com"
            }
        },
        ]
    })
    }
    ```
    - attach the required policy - this provides Kubernetes the permissions it requires to manage resources on your behalf
    ```
    resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role       = aws_iam_role.demo-eks-cluster-role.name
    }
    ```
    - add variable for eks version in `1-variables.tf`
    ```
    variable "eks_version" {
    type = string
    default = "1.31"
    description = "EKS version"
    }
    ```
    - cluster config 
    ```
    resource "aws_eks_cluster" "demo-eks-cluster" {
        name = var.cluster_name
        role_arn = aws_iam_role.demo-eks-cluster-role.arn
        vpc_config {
        endpoint_private_access = true
        endpoint_public_access = true
        subnet_ids = [
            aws_subnet.private-subnet-1.id,
            aws_subnet.private-subnet-2.id,
            aws_subnet.public-subnet-1.id,
            aws_subnet.public-subnet-2.id
        ]
        }
        access_config {
        authentication_mode = "API"
        bootstrap_cluster_creator_admin_permissions = true
        }
        bootstrap_self_managed_addons = true
        tags = var.tags
        version = var.eks_version
        upgrade_policy {
        support_type = "STANDARD"
        }
        depends_on = [ aws_iam_role_policy_attachment.eks_cluster_policy ]
    }
    ```
    - vpc config - vpc configuration, define its id and subnets that cluster would use
    - define public and private endpoints for kubernetes clusters
    - defines security group for the cluster
        - access config - how to access my cluster. either via API or config map or both.
        - bootstrap self_managed add ons - this tells if worker nodes should have default add-ons installed, if set to false, we need to define what we need. 
        - what get installed by [default](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html#:~:text=Amazon%20EKS%20automatically%20installs%20self%2Dmanaged%20add%2Dons%20such%20as%20the%20Amazon%20VPC%20CNI%20plugin%20for%20Kubernetes%2C%20kube%2Dproxy%2C%20and%20CoreDNS%20for%20every%20cluster)
        - upgrade policy - not required but good to define on how we want to upgrade our clusters.
    - terraform EKS [resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)
    
7. Connecting to cluster as an admin user
    - run this command on your laptop
    ```
    aws eks update-kubeconfig --region us-east-1 --name demo-eks-cluster
    ```


8. Create a fargate profile, create `4-fargate.tf` file
    - define a role and attach the required [policy](https://docs.aws.amazon.com/eks/latest/userguide/using-service-linked-roles-eks-fargate.html)
    - create a fargate profile and select kube-system and default namespace
    ```
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
    ```
    - subnets should be labeled with kubernetes.io/cluster/{cluster-name} = owned
    - add local variable in `1-vpc.tf` (didn't add variable in variable file cuz string interpolation can't be used within the key of the map.)
    ```
    locals {
    additional_tags = {
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
    }
    ```
    - Now add these tags to private subnets in `1-vpc.tf`
    ```
    tags = merge( var.tags, local.additional_tags)
    ```

9. Create a managed node group, create `5-nodegroup.tf`
    - define an IAM [role](https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html)
    - If you don’t use IRSA or EKS Pod Identity to give permissions to the VPC CNI pods, then you must provide permissions for the VPC CNI on the instance role
    ```
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
    ```
    - create the node group
    ```
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
    ```
    - default options of the nodes:
        - disk size - 20 GiB for linux n 50 for windows
        - instance types - t3.medium
        - define `remote access` for ssh, if security groups is used to specify where to allow ssh access from

## With module
1. Create `0-provider.tf` file 
    - specify the provider using required providers block and region using provider block
    ```
    terraform {
    required_providers {
        aws = {
        source = "hashicorp/aws"
        version = "5.82.2"
        }
    }
    }

    provider "aws" {
    region = var.region
    }
    ```
2. create variables file `1-variable.tf` and add region variable
    ```
    variable "region" {
    type = string
    default = "us-east-1"
    description = "AWS region"
    
    }
    ```
3. create VPC, define variables for vpc cidr and cluster name
    - define variable for vpc cidr and tags 
    ```
    variable "cidr_block" {
    type = string
    default = "10.10.0.0/16"
    
    }

    variable "tags" {
    type = map(string)
    default = {
        terraform  = "true"
        kubernetes = "demo-eks-cluster"
    }
    description = "Tags to apply to all resources"
    }
    ```

4. create vpc file  `1-vpc.tf` 
    - Using data source get AZs
    ```
    data "aws_availability_zones" "available" {
    state = "available"
    }
    ```
    - use module to create the vpc. specify the version
    ```
    module "eks-vpc" {
    source = "terraform-aws-modules/vpc/aws"
    version = "5.17.0"

    name = var.vpc_name
    cidr = var.cidr_block

    azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
    private_subnets = [cidrsubnet(var.cidr_block, 8, 110), cidrsubnet(var.cidr_block, 8, 120)]
    public_subnets  = [cidrsubnet(var.cidr_block, 8, 10), cidrsubnet(var.cidr_block, 8, 20)]
    
    create_igw = true # Default is true

    enable_dns_hostnames = true # Default is true
    
    # nat_gateway configuration
    enable_nat_gateway = true
    single_nat_gateway = true
    one_nat_gateway_per_az = false

    create_private_nat_gateway_route = true # Default is true

    tags = var.tags
    }
    ```
    - go over the inputs in [module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest?tab=inputs)

5. Creating EKS cluster. Create `2-eks.tf`
    - add variable for cluster name and its version
    ```
    variable "cluster_name" {
        type = string
        default = "demo-eks-cluster"
    
    }

    variable "eks_version" {
    type = string
    default = "1.31"
    description = "EKS version"
    }
    ```
    - add the eks module and define cluster configuration
    ```
    module "eks" {
    source  = "terraform-aws-modules/eks/aws"
    version = "~> 20.0"

    cluster_name    = var.cluster_name
    cluster_version = var.eks_version

    vpc_id = module.eks-vpc.vpc_id
    
    create_iam_role = true # Default is true
    attach_cluster_encryption_policy = false  # Default is true

    cluster_endpoint_private_access = true
    cluster_endpoint_public_access = true
    
    control_plane_subnet_ids = concat(module.eks-vpc.public_subnets, module.eks-vpc.private_subnets)

    create_cluster_security_group = true
    cluster_security_group_description = "EKS cluster security group"

    bootstrap_self_managed_addons = true

    authentication_mode = "API"
    enable_cluster_creator_admin_permissions = true

    dataplane_wait_duration = "40s"

    # some defaults
    enable_security_groups_for_pods = true
    
    #override defaults

    create_cloudwatch_log_group = false
    create_kms_key = false
    enable_kms_key_rotation = false
    kms_key_enable_default_policy = false
    enable_irsa = false 
    cluster_encryption_config = {}
    enable_auto_mode_custom_tags = false

    # EKS Managed Node Group(s)
    create_node_security_group = false
    node_security_group_enable_recommended_rules = false
    }
    ```
6. Connecting to cluster as an admin user
    ```
    aws eks update-kubeconfig --region us-east-1 --name demo-eks-cluster
    ```

7. creating eks managed node group
    - set the security group input to true, otherwise it will use cluster security group for nodes
    ```
    # EKS Managed Node Group(s)
    create_node_security_group = true
    node_security_group_enable_recommended_rules = true
    node_security_group_description = "EKS node group security group - used by nodes to communicate with the cluster API Server"
    
    node_security_group_use_name_prefix = true

    subnet_ids = module.eks-vpc.private_subnets
    eks_managed_node_groups = {
        group1 = {
        name         = "demo-eks-node-group"
        ami_type       = "AL2023_x86_64_STANDARD"
        instance_types = ["t3.medium"]
        capacity_type = "SPOT"

        min_size     = 2
        max_size     = 4
        desired_size = 2
        }
    }
    ```
    - creates a launch template, attach the security group to it
    - adds all ports as recommended by kubernetes [source](https://kubernetes.io/docs/reference/networking/ports-and-protocols/) 
    - it also creates ingress for dns port 53 or 443 as well

8. creating a fargate profile
    - define the selctor and profile name
    ```
    fargate_profiles = {
        profile1 = {
        selectors = [
            {
            namespace = "kube-system"
        }
        ]
        }
    }
    ```
    - it uses the same subnets that specified in subnet_ids = module.eks-vpc.private_subnets
    - this is what used by nodegroup as well 

## What To Pick
    - Infra requirements 
    - Smaller projects tend to not go with modules
    - directly writing the terraform resources could be useful
    - modules require getting know as well.
    - modules are good for reusability 
