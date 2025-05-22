### update hostname
sudo hostnamectl set-hostname controlplane
sudo hostnamectl set-hostname worker1
sudo hostnamectl set-hostname worker2

### check mac and uuid 
ip link
cat /sys/class/dmi/id/product_uuid

### turn swap off
swapoff -a

### enable ip packet forwarding 

echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/k8s.conf
sysctl --system
sysctl net.ipv4.ip_forward

### install containerd
apt update && sudo apt upgrade -y
apt-get install containerd
ctr --version

### Install cni plugins
mkdir -p /opt/cni/bin
wget https://github.com/containernetworking/plugins/releases/download/v1.6.1/cni-plugins-linux-amd64-v1.6.1.tgz
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.6.1.tgz

### configure containerd

mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
head /etc/containerd/config.toml
systemctl restart containerd

*** configure the systemd cgroup driver
vi /etc/containerd/config.toml

Within [plugins.”io.containerd.grpc.v1.cri”.containerd.runtimes.runc.options] section
SystemdCgroup = true
systemctl restart containerd

### Add Kubernetes repos and install tools
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm
apt-mark hold kubelet kubeadm

### Install kubectl on controlplane

apt-get install -y kubectl


### Intialize Cluster
kubeadm init --pod-network-cidr=192.168.0.0/16

### Configure a regular user for kubectl

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

### Install network plugin - calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
watch kubectl get pods -n calico-system
