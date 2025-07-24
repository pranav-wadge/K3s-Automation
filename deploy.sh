#!/bin/bash

set -e

# Set the path to your .pem file
KEY_PATH="/home/pranav/Downloads/kubers.pem"

# Check if the SSH key exists
if [ ! -f "$KEY_PATH" ]; then
  echo "❌ SSH key not found at: $KEY_PATH"
  exit 1
fi

chmod 400 "$KEY_PATH"

# Run Terraform to provision the EC2 instance
cd terraform
echo "🔨 Running Terraform..."
terraform init -input=false
terraform apply -auto-approve

# Get the public IP of the new EC2 instance
PUBLIC_IP=$(terraform output -raw instance_public_ip)

# Check if the IP was retrieved
if [[ -z "$PUBLIC_IP" ]]; then
  echo "❌ Failed to get public IP from Terraform."
  exit 1
fi

cd ..

# Wait for EC2 SSH to be ready
echo "⏳ Waiting for SSH on $PUBLIC_IP..."
until ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@$PUBLIC_IP 'echo "✅ SSH Ready"' 2>/dev/null; do
  sleep 5
done

# Run remote provisioning
echo "🔧 Running remote bootstrap directly on $PUBLIC_IP..."
ssh -i "$KEY_PATH" ubuntu@$PUBLIC_IP <<EOF
set -e

# Install prerequisites
sudo apt update -y
sudo apt install -y curl gnupg2 unzip apt-transport-https

# Clean previous K3s install if exists
sudo /usr/local/bin/k3s-uninstall.sh || true

# Get public IP from within the instance
PUBLIC_IP=\$(curl -s http://checkip.amazonaws.com)

# Install K3s with proper TLS SAN
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san \$PUBLIC_IP --write-kubeconfig-mode 644" sh -

# Wait for K3s node to be ready
until sudo k3s kubectl get nodes &>/dev/null; do
  echo "⏳ Waiting for K3s to be ready..."
  sleep 5
done

# Confirm TLS SAN was applied
echo "📄 K3s cert SANs:"
openssl s_client -connect \$PUBLIC_IP:6443 < /dev/null 2>/dev/null | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"

# Patch kubeconfig IP
sudo sed -i "s/127.0.0.1/\$PUBLIC_IP/" /etc/rancher/k3s/k3s.yaml
EOF

echo "✅ Remote bootstrap complete."

# Ensure .kube directory exists
mkdir -p ~/.kube

# Fetch kubeconfig from EC2 and save it
echo "📅 Fetching kubeconfig content over SSH and saving to ~/.kube/config..."
ssh -i "$KEY_PATH" ubuntu@$PUBLIC_IP "cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config

# Replace any internal IPs with public IP
sed -i "s/127.0.0.1/$PUBLIC_IP/" ~/.kube/config

# Confirm the IP was replaced correctly
CONFIG_IP=$(grep 'server:' ~/.kube/config | awk '{print $2}')
echo "✅ kubeconfig saved to ~/.kube/config"
echo "🌍 Cluster API Server set to: $CONFIG_IP"

# Set KUBECONFIG so following kubectl commands work
export KUBECONFIG=~/.kube/config

# Install cert-manager
echo "📦 Installing cert-manager..."
kubectl apply --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml

# Wait for cert-manager pods to be ready
echo "⏳ Waiting for cert-manager to become ready..."
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=120s

# Create required namespaces
kubectl create namespace simple-http || true
kubectl create namespace monitoring || true

# Apply app manifests
echo "📦 Applying Kubernetes manifests..."
kubectl apply -f manifests/letsencrypt-prod.yaml
kubectl apply -f manifests/traefik-https-redirect-middleware.yaml
kubectl apply -f manifests/middleware-redirect.yaml || true
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/grafana-ingress.yaml
kubectl apply -f manifests/prometheus-ingress.yaml
kubectl apply -f manifests/loki-ingress.yaml
kubectl apply -f manifests/simplehttp.yaml
kubectl apply -f manifests/uptime-deployment.yaml

# Show resources
echo "📊 Showing simple-http namespace resources:"
kubectl get pods,svc,ingress -n simple-http

echo "📊 Showing monitoring namespace resources:"
kubectl get pods,svc,ingress -n monitoring

# Final message
echo "🚀 Done! Run: kubectl get nodes"
echo "🌐 https://shoes.pranavwadge.cloud"
echo "🌐 https://simple.pranavwadge.cloud"
echo "🌐 https://uptime.pranavwadge.cloud"
echo "🌐 https://grafana.pranavwadge.cloud"
echo "🌐 https://prometheus.pranavwadge.cloud"
echo "🌐 https://loki.pranavwadge.cloud"
