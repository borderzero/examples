# Kubernetes via GitHub Actions with Border0

This directory contains supporting files to demonstrate how to install and configure
a Border0 node for Kubernetes using GitHub Actions.

## GH Action and complementary scripts

The `install-border0.sh` script performs the following steps:
1. Downloads the Border0 client binary.
2. Installs the client to `/usr/local/bin` and makes it executable.
3. Exports the `BORDER0_TOKEN` environment variable (from K8S_BORDER0_TOKEN in GitHub Secrets)
4. Installs and starts the Border0 node VPN.
5. Checks the status of the `border0-device` service.
6. Prints debug information about connected peers.

The `configure-kubectl.sh` script performs the following steps:
1. Installs `kubectl` to `/usr/local/bin` and makes it executable.
2. Sets the `KUBECONFIG` environment variable to the Border0-configured kubeconfig file.
2a. More details on `border0 client kubeconfig set --service $my-k8s-api-socket-name` command can be found [here](https://docs.border0.com/docs/kubernetes-api-sockets)
3. Verifies connectivity to the Kubernetes API server using `kubectl get nodes`.

The `deploy-to-k8s.sh` script performs the following steps:
1. Applies the sample deployments under `deployments/` (SSH, NGINX, Redis).

The `cleanup-border0-device.sh` script performs the following steps:
1. Stops and deregisters the Border0 node to free resources.
2. Deletes the Border0 device from the Border0 portal.


### Prerequisites

- A Border0 Service account and API token. More details [here](https://docs.border0.com/docs/service-accounts).
- A Border0 Socket for your Kubernetes API server (e.g., `fra-k8s-cluster`). More details [here](https://docs.border0.com/docs/kubernetes-api-sockets)
- Access Policy Allowing the Service Account to connect to the Socket. More details [here](https://docs.border0.com/docs/kubernetes-api-sockets#policy-based-access)

### Usage

## Set the Border0 API token in GitHub

In your repository under Settings → Secrets, add:
- `K8S_BORDER0_TOKEN`: Your Border0 API token. (we used this as an example, you can use any name or set it to BORDER0_TOKEN)


## GitHub Actions Workflow

The associated workflow is defined in:
```
workflows/k8s-border0-demo.yml
```

## Full Deployment Guide

This guide walks through the process of installing and configuring a Border0 node, 
setting up kubectl, deploying workloads, and cleaning up using both local scripts 
and GitHub Actions.

### 1. Prerequisites
 - A Border0 API token (store as `BORDER0_TOKEN` locally and `K8S_BORDER0_TOKEN` in GitHub).
 - A Border0 Service for your Kubernetes API server (e.g., `fra-k8s-cluster`).
 - Ubuntu host (or GitHub Actions runner) with `sudo`.

### 2. Local Deployment Steps

#### a. Install Border0 Node
```bash
git clone <repo-url>
cd k8s-via-gh-action
sudo env BORDER0_TOKEN=<YOUR_TOKEN> ./install-border0.sh
```
This installs the Border0 client, registers a node, and starts the VPN (`border0-device`). 

#### b. Configure kubectl
```bash
./configure-kubectl.sh
```
Installs `kubectl`, pings your cluster service, sets the kubeconfig via `border0 client kubeconfig set`, 
and verifies connectivity by listing nodes, pods, and services.

#### c. Deploy Workloads
```bash
./deploy-to-k8s.sh
```
Applies the sample deployments under `deployments/` (SSH, NGINX, Redis).

#### d. Cleanup
```bash
sudo env BORDER0_TOKEN=<YOUR_TOKEN> ./cleanup-border0-device.sh
```
Stops and deregisters the Border0 node to free resources.

### 3. GitHub Actions Deployment

The workflow `workflows/k8s-border0-demo.yml` automates all of the above:
1. Checkout code.
2. Make scripts executable.
3. Install Border0 node.
4. Install and configure `kubectl`.
5. Deploy workloads.
6. Cleanup device.

#### Setup
In your GitHub repo Settings → Secrets, add:
- `K8S_BORDER0_TOKEN`: Border0 API token.

#### Run
Go to Actions → Demo: Kubernetes via GitHub Actions with Border0 → Run workflow.

#### Customization
- Rename service (`fra-k8s-cluster`) in scripts and manifests.
- Add more YAMLs in `deployments/`.
- Adjust replicas, namespaces, etc.

### 4. Tips & Troubleshooting (using action tasks)
- Check Border0 service status: `service border0-device status`.
- Inspect peers: `border0 node debug peers`.
- Verify `/etc/hosts` entry for your service.
- Look at GitHub Actions logs for errors.