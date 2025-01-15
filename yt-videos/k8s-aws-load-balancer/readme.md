## What's in Here

This directory includes resources covered in this video.

Resources to create and configure self-hosted cluster with [terraform](tf-resources) and bash [script](scripts/create_cluster.sh). Then, deploy a blog [app](manifests/app.yaml) with multiple services and expose them to the internet using an [Ingress](manifests/ingress.yaml) and a load balancer.

Terraform creates the cluster in private subnets and also creates a bastion host for accessing the cluster.

Load balancer is created using aws-load-balancer [contoller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/)

## Steps

### Prerequisites
1. Ensure the AWS CLI and Terraform are installed and configured.
2. Create a new key pair or have an existing one accessible.
3. (Optional) Route 53 Domain
### Create EC2 Instances & Other Components for the Cluster Using Terraform

Resources created: \
__VPC__: 2 Private subnets, 2 Public subnets, 1 nat gw, 1 igw and 2 security groups(cluster and bastion node) \
__IAM role__: Permissions required to create load balancer \
__EC2 instances__: 1 master, 2 worker nodes (t2.medium), and 1 Bastian host(t2.micro)

1. cd to [tf-resources](tf-resources).
2. Most variables are defined [here](tf-resources/1-variable.tf). Adjust them if needed.
3. Amazon Linux image is the default AMI. Update the data resource in [here](tf-resources/4-ec2-instace.tf) for a different distro.
4. Initialize the dir and run `terraform plan` to check for error and then `terraform apply` to create resources.
5. Make note of IPs. Will need them to access nodes.

### Access EC2 Instnaces
__NOTE__: Only the bastion host is accessible from the external network. Cluster nodes reside in private subnets and can be accessed from the bastion host.

1. Copy the PEM key to the bastion host \
    `scp -i <key for ssh> <pem key> ec2-user@<bastin_public_ip>:<dst_location>` \
    _Example_: `scp -i demo-devops-avenue-ue2.pem demo-devops-avenue-ue2.pem ec2-user@$BASTIAN_IP:/home/ec2-user`
2. (Optional) Copy tmux or other personalized config to the bastion host. \
    _Example_: `scp -i demo-devops-avenue-ue2.pem ~/.tmux.conf ec2-user@$BASTIAN_IP:/home/ec2-user`
3. Connect to the bastain host via SSH. \
    _Example_: `ssh -i demo-devops-avenue-ue2.pem ec2-user@$BASTIAN_IP` \
    Install `tmux` and `git`:
    ```
    sudo yum update && sudo yum upgrade
    sudo hostnamectl set-hostname "bastian-node"
    sudo dnf install git tmux -y
    ```
4. Connect to each instance via SSH from th bastion host. 
5. (Tip) Install tmux, export IPs into variables and create multiple sessions in tmux to connect to all instance at once. \
    `ssh -i demo-devops-avenue-ue2.pem ec2-user@<MASTER_IP>` \
    `ssh -i demo-devops-avenue-ue2.pem ec2-user@<WORKER1_IP>` \
    `ssh -i demo-devops-avenue-ue2.pem ec2-user@<WORKER2_IP>`
 
### Create Kubernetes Cluster
Use a script to create a Kubernetes cluster with kubeadm.

1. Download the [create_cluster](scripts/create_cluster.sh) on each node. \  
    `wget https://raw.githubusercontent.com/gurlal-1/devops-avenue/refs/heads/main/yt-videos/k8s-aws-load-balancer/scripts/create_cluster.sh`
2. Change permissions for the script. \ `chmod +x create_cluster.sh` \
NOTE: This script prepares the nodes with kubeadm as the [docs](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/). The cluster is intialized with pod-network-cidr=192.168.0.0/16
3. Run the script on each node. \`sudo ./create_cluster.sh`
4. Select `yes` for control plane & `No` for worker nodes. \
__NOTE: Make note of cluster join command.__
5. Install the network CNI:
    ```
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
    ```
    NOTE: Download and update `custom-resources.yaml` with a different CIDR IF NEEDED.
5. Join worker nodes to the cluster.\ 
_Example_: `kubeadm join 172.31.25.150:6443 --token 2i8vrs.wsshnhe5zf87rhhu --discovery-token-ca-cert-hash sha256:eacbaf01cc58203f3ddd69061db2ef8e64f450748aef5620ec04308eac44bd77`

Exit the nodes and return to the bastion host.

### Configure kubectl on Bastian Host

1. Add the Kubernetes repo and install `kubectl`:
    ```
    RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt | sed 's/\.0//')"
    sudo bash -c "cat <<EOF > /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://pkgs.k8s.io/core:/stable:/${RELEASE}/rpm/
    enabled=1
    gpgcheck=1
    gpgkey=https://pkgs.k8s.io/core:/stable:/${RELEASE}/rpm/repodata/repomd.xml.key
    EOF"
    sudo dnf install kubectl -y
    ```
2. Create the config dir and move the kubernetes config from the master node: \
    ```
    mkdir -p $HOME/.kube
    scp -i demo-devops-avenue-ue2.pem ec2-user@$MASTER_IP:/home/ec2-user/.kube/config $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    ```
    NOTE: change Master_IP

### Install Load Balancer Controller

1. Install Helm and the AWS Load Balancer Controller:
    ```
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh

    #Install aws-load-balancer controller
    helm repo add eks https://aws.github.io/eks-charts
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=kubernetes #update cluster name if needed
    ```

### Create Deployment and Services for the Blog App.

1. Download app [manifest](manifests/app.yaml) \ 
`wget https://raw.githubusercontent.com/gurlal-1/devops-avenue/refs/heads/main/yt-videos/k8s-aws-load-balancer/manifests/app.yaml`
2. Apply the manifest: `kubectl -f app.yaml` \
NOTE: Update the URLs in the configmap with your domain.

### Set Up ACM certificate
Assumption: You have a domain.

1. Go to the AWS Certificate Manager service
2. Click __Request__ and select `Request a public certificate`
3. Provide FQDN, select `DNS validation`and select `RSA 2048`
4. Click __Request__

### Create Ingress and load balancer

1. Patch worker nodes with `Provider_ID`:
    `kubectl patch node <worker_node_name> -p '{"spec":{"providerID":"aws:///<Region>/<WORKER_ID>"}}'` \
    _Example_: `kubectl patch node worker1 -p '{"spec":{"providerID":"aws:///us-east-2/i-012373091f38897a1"}}'`

2. Download the Ingress manifest [here](manifests/ingress.yaml) \
 `wget https://raw.githubusercontent.com/gurlal-1/devops-avenue/refs/heads/main/yt-videos/k8s-aws-load-balancer/manifests/ingress.yaml`
3. Apply the Ingress manifest: \ `kubectl -f ingress.yaml` \
    NOTE: If a domain isn't available. Remove the host and HTTPS from ingress manifest:\
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80} ~~, {"HTTPS": 443}~~]' \
    ~~host: testblog.gurlal.com~~ \
    Without a domain, ACM setup won’t be applicable, and app redirects won’t work. You can access the app using the load balancer’s DNS name.
4. View Ingress logs:
    `kubectl describe ingress blog-app-ingress` \
    `kubectl logs -n kube-system -l=app.kubernetes.io/instance=aws-load-balancer-controller`

Wait for the load balancer to be created.

### Add a CNAME Record for the Subdomain

1. Go to Route 53 Service. Select __Hosted Zones__ and create a __new record__
2. Enter the subdomain in the __Record name__ 
3. Provide the load balancer DNS in __Value__.



