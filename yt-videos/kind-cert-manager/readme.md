## What's in Here?
This dir contains resources covered in this video

**Overview:** A tutorial on how cert-manager's certificate issuance works with lets encrypt. Start by creating an EC2 instance and a security group with Terraform. Configure the instance with Kind, deploy a web app with ingress and apply certificates for domain

### Prerequisites
1. Ensure the AWS CLI and Terraform are installed and configured.
2. Create a new key pair or have an existing one accessible.
3. A valid Domain

### Create EC2 Instance and Security Group with Terraform

1. Switch to [terraform](terraform) dir
2. IMPORTANT: Provide your keypair [here](terraform/1-variables.tf). Otherwise you will get an error.
2. Initialize the dir and run `terraform plan` to check for errors and then `terraform apply` to create resources.
3. Make note of the IP address, as you will need them to access the node

### Connect to the EC2 Instance

1. Connect to the node via ssh: `ssh -i <ssh key> ec2-user@<PUBLIC_IP>`  
*Example:* `ssh -i demo-devops-avenue-ue2.pem ec2-user@3.15.44.218`

#### Install Docker

1. Install docker, start the service and add it docker group:
```
sudo yum install docker -y
sudo systemctl start docker.service
sudo usermod -aG docker $(logname)
```
2. Log out and login back for membership to take in effect.
3. Test:  
`docker ps`

### Create kind cluster

1. Download [setup_cluster](script/set_cluster.sh) script on your node.  
<past link here>
    This bash script:
    - Install docker (pre req for kind)
    - Install kind
    - kubectl
    - Create kind cluster and map host ports with kind container

2. Change permissions for the script and run it.  
```
chmod +x set_cluster.sh
sudo ./set_cluster.sh 
```

### Deploy Nginx Ingress controller and a Web App with Ingress

1. Download Ingress Controller:  
`wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/cloud/deploy.yaml`
2. Map host ports to NGINX Controller Pods:
```
  name: controller
  ports:
  - containerPort: 80
    name: http
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    name: https
    hostPort: 443
    protocol: TCP
```
3. Deploy the NGINX Controller::
`kubectl create -f deploy.yaml`
4. Wait for the Controller to Become Ready:
Once ready, visit the IP address of the node to verify if the NGINX Controller is working:
`<http://<node_IP_address>`
5. Download the web app Manifest [here](manifest/app_n_ingress.yaml)
<wget link here>
6. Deploy the Web App and Ingress::  
`kubectl apply -f app_n_ingress.yaml`
4. IP address alone won't resolve to the app. Ingress relies on a hostname. Domain A record is required. 

### Add A type domain record

Go to your domain provider. Create a 'A' type record. Provide your subdomain and IP of the EC2 for value.
**Steps to Configure Route 53:**
1. Go to Route 53 service. Click on Hosted zones, and select your domain.
2. Click Create record. Provide Record name for your subdomain, select A record type and enter in public IP for the value and click Create records. An A record maps a domain name to an IP address
3. Wait for it propagate and access your app using the domain.

### Install cert-manager

1. Deploy cert-manager and its components using kubectl:
`kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.3/cert-manager.yaml`  
*helm [option](https://cert-manager.io/docs/installation/helm/)*
2. List pods in cert-manager namespace  
`kubectl get pods --namespace cert-manager`

### Download cert-dir for issuer and CA configurations
<Download the dir>

### Create Self-signed certificate 
Test TLS functionality before setting up public TLS.

1. Switch to the downloaded cert-manager directory, which contains all the necessary YAML files required for the steps below.
2. Create self-signed issuer:  
`kubectl create -f self-signed-issuer.yaml`
3. Create self-signed certificate:  
`kubectl create -f self-signed-cert.yaml`
4. Status of the certificate:  
`kubectl describe certificates da-selfsigned-cert`
5. Edit Ingress app yaml and uncomment tls config for the ingress:  
```
spec:
  ingressClassName: nginx
  # tls:
  # - secretName: da-ss-sec
  #   hosts:
  #     - blog2.gurlal.com
```
6. Access the app and verify self-signed certificate
7. Logs of other resources:  
Describe Issuer:  
`kubectl describe clusterissuers da-selfsigned-issuer`  
Check the secret
`kubectl get secrets`  &&  `kubectl describe secrets da-ss-sec`  
   ** Type: kubernetes.io/tls indicates it is a valid TLS secret. **
Ingress controller logs:  
`kubectl logs -n ingress-nginx <controller_pod_name>`

### Let's Encrypt (ACME Server) signed certificate

#### HTTP01 Challenge Solver - Staging (Non-validated)

1. Switch to the downloaded cert-manager directory, which contains all the necessary YAML files required for the steps below.
2. Create lets encrypt signed staging issuer:  
`kubectl create -f acme-http-stag-issuer.yaml`
3. Create lets encrypt staging certificate:  
`kubectl create -f acme-http-stag-cert.yaml`
4. Status of the certificate:  
`kubectl describe certificates acme-http-stag-cert`
5. Once cert issued. Edit the secret for ingress app:  
```
....
  - secretName: da-acme-http-stag-sec
    hosts:
      - blog2.gurlal.com
....
```
6. Access the app and verify lets encrypt staging certificate
7. Logs of other resources:  
Describe Issuer:  
`kubectl describe clusterissuers da-acme-http-stag`  
Check the secret
`kubectl get secrets`  &&  `kubectl describe secrets da-acme-http-stag-sec`  
   ** Type: kubernetes.io/tls indicates it is a valid TLS secret. **
Ingress controller logs:  
`kubectl logs -n ingress-nginx <controller_pod_name>`

#### HTTP01 Challenge Solver - Prod (Validated)

1. Switch to the downloaded cert-manager directory, which contains all the necessary YAML files required for the steps below.
2. Create lets encrypt signed prod issuer:  
`kubectl create -f acme-http-prod-issuer.yaml`
3. Create lets encrypt prod certificate:  
`kubectl create -f acme-http-prod-cert.yaml`
4. Status of the certificate:  
`kubectl describe certificates acme-http-prod-cert`
** Takes longer to issue this certificate **
5. Once cert issued. Edit the secret for ingress app:  
```
....
  tls:
  - secretName: da-acme-http-prod-sec
    hosts:
      - blog2.gurlal.com
....
```
6. Access the app and verify acme prod server signed certificate
7. Logs of other resources:  
Describe Issuer:  
`kubectl describe clusterissuers da-acme-http-prod`  
Check the secret
`kubectl get secrets`  &&  `kubectl describe secrets da-acme-http-prod-sec`  
   ** Type: kubernetes.io/tls indicates it is a valid TLS secret. **
Ingress controller logs:  
`kubectl logs -n ingress-nginx <controller_pod_name>`

