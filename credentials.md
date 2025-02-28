# AWS ECR Authentication with K3s Using Credential Provider

This guide explains how to configure **K3s** to authenticate with **AWS ECR** using the **Kubernetes Credential Provider** mechanism.

## **🛠 Prerequisites**
- A **K3s** cluster running on your infrastructure.
- AWS IAM credentials with the `AmazonEC2ContainerRegistryReadOnly` policy.
- The `ecr-credential-provider` binary installed on the K3s node.

## **1️⃣ Install the AWS ECR Credential Provider**

```sh
sudo mkdir -p /etc/kubernetes/credential-provider-bin
cd /etc/kubernetes/credential-provider-bin

# Download the ecr-credential-provider
sudo curl -o ecr-credential-provider https://amazon-ecr-credential-provider-url

# Make it executable
sudo chmod +x ecr-credential-provider
```

## **2️⃣ Configure the Credential Provider**
Create a configuration file for the credential provider:

```sh
sudo nano /etc/kubernetes/credential-provider.yaml
```

Add the following content:

```yaml
apiVersion: credentialprovider.kubelet.k8s.io/v1
kind: CredentialProviderConfig
providers:
  - name: ecr-credential-provider
    matchImages:
      - "*.dkr.ecr.*.amazonaws.com"
    defaultCacheDuration: "12h"
    apiVersion: credentialprovider.kubelet.k8s.io/v1
    args: []
    env:
      - name: AWS_REGION
        value: "us-east-1"
```
Save and exit (`CTRL+X`, then `Y` + `ENTER`).

## **3️⃣ Verify the Credential Provider**

Test the credential provider manually:

```sh
echo '{"image": "442426895473.dkr.ecr.us-east-1.amazonaws.com/sftp-vc:pim-fe-env"}' | \
    /etc/kubernetes/credential-provider-bin/ecr-credential-provider
```

✅ Expected output should contain `username: AWS` and `password` (a temporary auth token).

## **4️⃣ Configure K3s to Use the Credential Provider**

Edit the K3s systemd service file:

```sh
sudo nano /etc/systemd/system/k3s.service
```

Modify the `ExecStart` line to explicitly pass **kubelet arguments**:

```sh
ExecStart=/usr/local/bin/k3s \
    server \
        '--disable=traefik' \
        --kubelet-arg=image-credential-provider-config=/etc/kubernetes/credential-provider.yaml \
        --kubelet-arg=image-credential-provider-bin-dir=/etc/kubernetes/credential-provider-bin
```

Save and exit (`CTRL+X`, then `Y` + `ENTER`).

## **5️⃣ Apply Changes and Restart K3s**

```sh
sudo systemctl daemon-reload
sudo systemctl restart k3s
```

## **6️⃣ Verify That the Credential Provider is Working**

Check logs for credential provider activity:

```sh
sudo journalctl -u k3s | grep 'credential-provider'
```

If no output, verify that K3s is running with the correct arguments:

```sh
ps aux | grep k3s
```

Ensure you see `--kubelet-arg=image-credential-provider-config` and `--kubelet-arg=image-credential-provider-bin-dir`.

## **7️⃣ Test Image Pull from AWS ECR**

Deploy a test pod using an ECR image:

```sh
kubectl run test-pod --image=442426895473.dkr.ecr.us-east-1.amazonaws.com/sftp-vc:pim-fe-env --restart=Never
```

Check the pod status:

```sh
kubectl get pods -w
```

✅ Expected: The pod should enter `Running` state instead of `ImagePullBackOff`.

## **🎯 Summary**
✔️ Installed and configured the **ECR credential provider**.  
✔️ Updated **K3s systemd service** with credential provider arguments.  
✔️ Restarted **K3s** and verified logs.  
✔️ Successfully **tested ECR authentication** by pulling an image.  

Now, K3s will **automatically authenticate** with AWS ECR without requiring a `docker login` or stored credentials! 🚀

