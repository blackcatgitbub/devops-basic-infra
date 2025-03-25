## What's in Here?
This dir contains resources covered in this video

**Overview:** A tutorial on getting started with Sealed Secrets. Check out the official documentation for more [info](https://github.com/bitnami-labs/sealed-secrets)

## Setup a Kind Cluster (Optional)

If you don't have a functional kubernetes cluster. Follow the instructions [here](cluster_setup.md) to setup a kind cluster

## Sealed Secrets

- Encrypts Kubernetes Secrets, allowing you to store them safely in version control
- Allows you to integrate this encrypted secrets into GitOps pipelines to manage secrets declaratively

### Visual representation of how Sealed Secrets [work](HowSealedSecretsWork.jpg). Explained in the video.


## Set Up Sealed Secrets Components

### Install Sealed Secrets controller

```bash
SEALED_SECRETS_TAG=$(curl -sSL "https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest" | jq -r '.tag_name')
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/$SEALED_SECRETS_TAG/controller.yaml
watch -n 2 kubectl get pods -n kube-system -l name=sealed-secrets-controller
```
### Install Kubeseal CLI

Setup Kubeseal on linux machine

```bash
KUBESEAL_VERSION=$(curl -sSL "https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION:?}/kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
kubeseal --version
```

## Create a Sealed Secrets

1. Create a regular secret
    
    ```bash
    kubectl create secret generic da-secret \
    --from-literal=username=da-user \
    --from-literal=password=da-ss-password \
    --dry-run=client -o yaml > da-secret.yaml
    ```
    
2. Encrypt the secret
    
    ```bash
    kubeseal --format yaml < da-secret.yaml > da-sealed-secret.yaml
    ```
    
3. Now you can store this secret anywhere 
4. Apply the sealed secret
    
    ```bash
    kubectl apply -f da-sealed-secret.yaml
    ```
    
5. Verify the secret
    
    ```bash
    kubectl get secret da-secret -o yaml
    ```
    
6. Avoid creating a generic secret. Create a sealed secret in 1 go

    ```bash
    kubectl create secret generic da-secret \
    --from-literal=username=da-user \
    --from-literal=password=da-ss-password \
    --dry-run=client -o yaml | \
    kubeseal --format yaml > da-sealed-secret.yaml
    ```

### Deleting Sealed secrets vs generic secrets

1. List Sealed secret
    
    ```bash
    kubectl get sealedsecrets --all-namespaces
    ```
    
2. List Kubernetes secrets
    
    ```bash
    kubectl get secrets --all-namespaces
    ```
    
3. Deleting a regular secret. A new secret would get auto recreated
    
    ```bash
    kubectl delete secret da-secret
    ```
    
4. Delete a sealed secret. This deletes the regular secret as well
    
    ```bash
    kubectl delete sealedsecret da-secret
    ```
    
## Secrets metadata

1. Create a secret 
    
    ```bash
    kubectl create secret generic da-secret-metadata \
    --from-literal=username=da-user-metadata \
    --from-literal=password=da-ss-password-metadata \
    --dry-run=client -o yaml > da-secret-metadata.yaml
    ```
    
2. Add metadata
    
    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: da-secret-metadata
      labels:
        app: da-app
        env: production
    ```
    
3. Create a sealed secret with metadata
    
    ```bash
    kubeseal --format yaml < da-secret-metadata.yaml > da-sealed-secret-metadata.yaml
    ```
    
4. View the metadata. It shows under template
    
    ```bash
    cat da-sealed-secret-metadata.yaml
    ```
    
## Restrict a Secret to a namespace

1. Create the namespace
    
    ```bash
    kubectl create ns da-namespace
    ```
    
2. Specify the namespace when creating a secret and sealed secret
    
    ```bash
    kubectl create secret generic da-ns-secret \
    --from-literal=username=da-ns-user \
    --from-literal=password=da-ns-password \
    --namespace=da-namespace \
    --dry-run=client -o yaml | \
    kubeseal --format yaml --scope namespace-wide > da-ns-sealed-secret.yaml
    ```
    
3. Apply the sealed secret
    
    ```bash
    kubectl apply -f da-ns-sealed-secret.yaml -n da-namespace
    ```
    

## Namespace-wide vs Strict Scope

### namespace scope

1. Edit the `da-ns-sealed-secret.yaml` and update the name
    
    ```bash
    metadata:
      name: da-ns-secret-2
    ```
2. Different name of secret would work in expected namespace
    
    ```bash
    kubectl apply -f da-ns-sealed-secret.yaml -n da-namespace
    ``` 
3. Create in different namespace - WOULDN’T WORK
    
    ```bash
    kubectl apply -f da-ns-sealed-secret.yaml -n default
    ```

### Strict scope:

1. Edit the name of `da-sealed-secret-metadata.yaml`

    ```bash
    metadata:
    name: da-secret-metadata-2
    ```
2. Now apply the sealed secret. Sealed would get created but regular secret won’t

    ```bash
    kubectl apply -f da-sealed-secret-metadata.yaml
    ```
3. Review the logs for errors

    ```
    kubectl logs -n kube-system -l name=sealed-secrets-controller
    ```

## Manually fetch a Public Key For Encryption 

1. Download the public key

    ```bash
    kubeseal --fetch-cert > public-key.pem
    ```

### Use Public key Offline
1. Create a secret
    
    ```bash
    kubectl create secret generic da-offline-secret \
    --from-literal=username=da-user \
    --from-literal=password=da-password \
    --dry-run=client -o yaml > da-offline-secret.yaml
    ```
    
2. Using the public key key to create a sealed secret

    ```bash
    kubeseal --format yaml --cert public-key.pem < da-offline-secret.yaml > da-offline-sealed-secret.yaml
    ```

## Audit Sealed secrets

- Helps you identify unused or outdated secrets  
    ```bash
    kubectl get sealedsecrets --all-namespaces
    ```

## Rotate controller keys

1. Delete the pod. New pod would have a new key

    ```bash
    kubectl get pods -n kube-system -l name=sealed-secrets-controller
    ```

2. Now fetch the public key to see different public key
    
    ```bash
    kubeseal --fetch-cert > public-key2.pem
    ```

### Cleanup

1. Remove controller

    ```bash
    kubectl delete -f https://github.com/bitnami-labs/sealed-secrets/releases/download/$SEALED_SECRETS_TAG/controller.yaml
    ```

2. Remove kubeseal

    ```bash
    sudo rm /usr/local/bin/kubeseal
    ```

3. Destroy the cluster (optional)

    ```
    terraform destroy
    ```
