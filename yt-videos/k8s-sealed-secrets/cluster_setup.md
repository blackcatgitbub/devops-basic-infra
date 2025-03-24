## Setup Kind Cluster 

### Prerequisites
1. Ensure the AWS CLI and Terraform are installed and configured.
2. Create a new key pair or have an existing one accessible.

### Create EC2 Instance and Security Group with Terraform

1. Switch to [terraform](terraform) dir
2. IMPORTANT: Provide your keypair [here](terraform/1-variables.tf). Otherwise you will get an error.
2. Initialize the dir and run `terraform plan` to check for errors and then `terraform apply` to create resources.
3. Make note of the IP address, as you will need them to access the node

### Connect to the EC2 Instance

1. Connect to the node via ssh: `ssh -i <ssh key> ec2-user@<PUBLIC_IP>`  
*Example:* ```ssh -i demo-devops-avenue-ue2.pem ec2-user@3.15.44.218 ```

#### Install Docker

1. Install docker, start the service and add it docker group:

```bash
sudo yum install docker -y
sudo systemctl start docker.service
sudo usermod -aG docker $(logname)
```
2. Log out and login back for membership to take in effect.
3. Test:

```bash
docker ps
```

### Create kind cluster
Use a bash script to: 1) Install kind 2) kubectl 3) Create kind cluster and map host ports with kind container
  
1. Download [setup_cluster](script/set_cluster.sh) script on your node, change permissions for the script file and run it. 

```bash
wget https://raw.githubusercontent.com/gurlal-1/devops-avenue/refs/heads/main/yt-videos/k8s-argocd/script/set_cluster.sh 
chmod +x set_cluster.sh
./set_cluster.sh 
```
