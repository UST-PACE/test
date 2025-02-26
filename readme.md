# AWS ECR Authentication for K3s

## Step 1: Install AWS CLI & Configure Credentials

### Install AWS CLI:
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip -y
unzip awscliv2.zip
sudo ./aws/install
```

### Configure AWS Credentials:
```bash
aws configure
```
Provide the following details:
- **AWS Access Key ID**
- **AWS Secret Access Key**
- **Default region:** `us-east-1`
- **Output format:** `json`

### Verify Authentication:
```bash
aws sts get-caller-identity
```

---

## Step 2: Install Amazon ECR Credential Helper

### Install via APT:
```bash
sudo apt install -y amazon-ecr-credential-helper
```

### Or Manually:
```bash
curl -Lo /usr/local/bin/docker-credential-ecr-login https://amazon-ecr-credential-helper-releases.s3.us-east-2.amazonaws.com/latest/linux-amd64/docker-credential-ecr-login
chmod +x /usr/local/bin/docker-credential-ecr-login
```

### Verify Installation:
```bash
docker-credential-ecr-login version
```

---

## Step 3: Configure `registries.yaml` for Persistent AWS ECR Authentication

```bash
sudo mkdir -p /etc/rancher/k3s
AWS_ECR_PASSWORD=$(aws ecr get-login-password --region us-east-1)

sudo tee /etc/rancher/k3s/registries.yaml > /dev/null <<EOF
mirrors:
  "442426895473.dkr.ecr.us-east-1.amazonaws.com":
    endpoint:
      - "https://442426895473.dkr.ecr.us-east-1.amazonaws.com"

configs:
  "442426895473.dkr.ecr.us-east-1.amazonaws.com":
    auth:
      username: AWS
      password: "$AWS_ECR_PASSWORD"
EOF
```

### Verify the File:
```bash
cat /etc/rancher/k3s/registries.yaml
```

---

## Step 4: Restart K3s to Apply Changes
```bash
sudo systemctl restart k3s
```

### Verify Updated `containerd` Configuration:
```bash
sudo cat /var/lib/rancher/k3s/agent/etc/containerd/config.toml
```

---

## Step 5: Test AWS ECR Image Pull
```bash
sudo crictl pull 442426895473.dkr.ecr.us-east-1.amazonaws.com/sftp-vc:pim-fe-env
```

If the pull fails, try restarting `containerd`:
```bash
sudo systemctl restart containerd
```

---

## Step 6: Setup Automatic ECR Login Renewal (Fix Token Expiry)

### Create an Update Script:
```bash
sudo nano /usr/local/bin/update-k3s-registry.sh
```

#### Add the Following Content:
```bash
#!/bin/bash
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin
export AWS_ECR_PASSWORD=$(aws ecr get-login-password --region us-east-1)

echo "AWS_ECR_PASSWORD is set to: ${AWS_ECR_PASSWORD:0:10}**********"  # Masked output for debugging

sudo bash -c 'cat <<EOF > /etc/rancher/k3s/registries.yaml
mirrors:
  "860602188711.dkr.ecr.us-east-1.amazonaws.com":
    endpoint:
      - "https://860602188711.dkr.ecr.us-east-1.amazonaws.com"
    auth:
      username: AWS
      password: "'$AWS_ECR_PASSWORD'"

configs:
  "442426895473.dkr.ecr.us-east-1.amazonaws.com":
    auth:
      username: AWS
      password: "'$AWS_ECR_PASSWORD'"
EOF'

sudo systemctl restart k3s
echo "$(date) - Updated ECR token" | sudo tee -a /var/log/update-k3s-registry.log
```

### Make the Script Executable:
```bash
sudo chmod +x /usr/local/bin/update-k3s-registry.sh
```

### Configure Cron Job for Automatic Execution:
```bash
sudo crontab -e
```

#### Add the Following Line:
```bash
0 */6 * * * /usr/local/bin/update-k3s-registry.sh >> /var/log/update-k3s.log 2>&1
```
This runs the script every 6 hours to refresh the ECR token.

### Save and Exit.

---

## Conclusion
This setup ensures that K3s can consistently authenticate with AWS ECR, preventing token expiration issues. The cron job automates the token renewal every 6 hours, avoiding manual interventions. 🚀

