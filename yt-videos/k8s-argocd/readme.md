## What's in Here?
This dir contains resources covered in this video

**Overview:** A tutorial on how to get started with argocd. Start by creating an EC2 instance and a security group with Terraform. Configure the instance with Kind, setup argocd and deploy a web app using argocd

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
```
sudo yum install docker -y
sudo systemctl start docker.service
sudo usermod -aG docker $(logname)
```
2. Log out and login back for membership to take in effect.
3. Test:  
```
docker ps
```

### Create kind cluster
Use a bash script to: 1) Install kind 2) kubectl 3) Create kind cluster and map host ports with kind container
  
1. Download [setup_cluster](script/set_cluster.sh) script on your node.  
```
wget https://raw.githubusercontent.com/gurlal-1/devops-avenue/refs/heads/main/yt-videos/k8s-argocd/script/set_cluster.sh
```
3. Change permissions for the script and run it.  
```
chmod +x set_cluster.sh
./set_cluster.sh 
```

### Install Argo CD

1. Create a new namespace and install Argo CD
```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
2. Forward host port to Argo CD API server (running it in background with `&`)

```
kubectl port-forward svc/argocd-server -n argocd --address 0.0.0.0 8080:443 >/dev/null 2>&1 &
```
3. Access Argo CD Server on any browser

```
https://<instance_public_ip>:8080
```
4. Retrieve login password
```
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo
```
5. Login to argo CD  
Enter in `admin` as username and password retrieved in step 4 above.
6. (Optional) Change password  
Click **User Info** --> Click **UPDATE PASSWORD**

### Deploy a web app Via UI

1. Click **Applications** , click **+ NEW APP**  
2. Enter in required fields:  
Application: `blog-app`  
Project Name: `default`  
SYNC POLICY: `Manual`  
Auto-Create Namespace: `CHECK`  
Repository URL: `https://github.com/gurlal-1/devops-avenue.git`  
Revision: `HEAD`  
Path: `yt-videos/k8s-argocd/manifests`  
Cluster URL: `https://kubernetes.default.svc`  
Namespace: `blog-app01`  
Leave everything as it is.
4. Click `CREATE`
5. Click `SYNC` ,leave options as it is and click `SYNCRONIZE`
6. Access the deployed app  
```
https://<instance_public_ip>:30011
```

### Deploy a web app Via Argo CD application CRD - Declarative

1. Application spec are [here](argocd-app/argocd_app.yaml)
2. Deploy the application CRD with kubectl
```
kubectl apply -f https://raw.githubusercontent.com/gurlal-1/devops-avenue/refs/heads/main/yt-videos/k8s-argocd/argocd-app/argocd_app.yaml
```

### Additional application config

Additional fields for application [CRD](https://argo-cd.readthedocs.io/en/stable/operator-manual/application.yaml)


### Clean
1. Delete argocd namespace and its resources
```
kubectl delete namespace argocd
```
2. Exit ssh connection and destroy terraform resources.(Ensure you are in [terraform](terraform) dir)
```
terraform destroy
```
