#!/bin/bash

set -e  # Exit for non-zerop

#Install kind using binary:
# For AMD64 / x86_64
echo "Installing kind"
KIND_VERSION=$(curl -sSL "https://api.github.com/repos/kubernetes-sigs/kind/releases/latest" | jq -r '.tag_name')

[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind


# Install kubectl
echo "Installing kubectl"
RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
RELEASE="${RELEASE%.*}"
sudo tee /etc/yum.repos.d/kubernetes.repo > /dev/null <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/${RELEASE}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${RELEASE}/rpm/repodata/repomd.xml.key
EOF

sudo dnf install -y kubectl

#create the cluster and map ports with kind container
echo "Creating kind cluster"
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
EOF

source <(kubectl completion bash)
kubectl completion bash > ~/.kube/completion.bash.inc
source ~/.bashrc


