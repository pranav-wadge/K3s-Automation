#!/bin/bash

set -e
sudo apt update -y
sudo apt install -y curl gnupg2 apt-transport-https unzip

# Install K3s
curl -sfL https://get.k3s.io | sh -

# Safely access kubeconfig as non-root
sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/k3s.yaml
sudo chown ubuntu:ubuntu /home/ubuntu/k3s.yaml
export KUBECONFIG=/home/ubuntu/k3s.yaml

# Wait for K3s to settle
sleep 20

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml
sleep 30

# Apply user manifests
kubectl create namespace simple-http || true
kubectl apply -f manifests/letsencrypt-prod.yaml
kubectl apply -f manifests/traefik-https-redirect-middleware.yaml
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/uptime-deployment.yaml

echo "✅ Kubernetes setup finished."
