#!/bin/bash


echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# show kubectl version
kubectl version --client

# ping and configure kubectl
ping fra-k8s-cluster -c 4
border0 client kubeconfig set --service fra-k8s-cluster

# show kubectl config
kubectl config view

# show nodes
kubectl get nodes

# show pods
kubectl get pods

# show services
kubectl get services

