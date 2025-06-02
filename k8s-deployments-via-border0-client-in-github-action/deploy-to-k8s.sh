#! /bin/bash

# update fra-k8s-cluster using the fra-k8s-cluster-config.yaml file
for config in k8s-via-gh-action/deployments/*.yaml k8s-via-gh-action/deployments/*.yml; do
  [ -e "$config" ] || continue
  echo "Applying $config"
  kubectl apply -f "$config"
  echo "Pods:"
  kubectl get pods
  echo "Services:"
  kubectl get services
done



