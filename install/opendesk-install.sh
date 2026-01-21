#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: [YourGitHubUsername]
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: [SOURCE_URL e.g. https://github.com/example/app]

# Import Functions and Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# =============================================================================
# DEPENDENCIES
# =============================================================================
# Only install what's actually needed - curl/sudo/mc are already in the base image

msg_info "Installing Dependencies"
$STD apt install -y \
  git \
  curl \
  grep
msg_ok "Installed Dependencies"

# =============================================================================
# INSTALL K3S
# =============================================================================

msg_info "Installing k3s (Lightweight Kubernetes)"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik --write-kubeconfig-mode 644" sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >>/root/.bashrc
sleep 10
kubectl wait --for=condition=Ready nodes --all --timeout=120s
msg_ok "Installed k3s"

# =============================================================================
# INSTALL HELM, HELMFILE, HELMDIFF, CERT-MANAGER, INGRESS-NGINX
# =============================================================================
msg_info "Installing Helm, Helmfile, Helmdiff, Cert-Manager, Ingress-NGINX"
# Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash
# Helmfile
HELMFILE_VERSION=$(curl -s "https://api.github.com/repos/helmfile/helmfile/releases/latest" | jq -r .tag_name)
curl "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_linux_amd64.tar.gz" -o /tmp/helmfile_linux_amd64.tar.gz
tar -xzf /tmp/helmfile_linux_amd64.tar.gz -C /tmp
mv /tmp/helmfile /usr/local/bin/helmfile
chmod +x /usr/local/bin/helmfile
rm /tmp/helmfile_linux_amd64.tar.gz

# Helmdiff
helm plugin install https://github.com/databus23/helm-diff --verify=false

# Cert-Manager cert-manager.io
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.19.2 \
  --set crds.enabled=true

# Ingress-NGINX
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.watchIngressWithoutClass=true
kubectl wait --namespace ingress-nginx --for=condition=available deployment/ingress-nginx-controller --timeout=120s

# =============================================================================
# INSTALL OPENDESK VIA HELMFILE
# =============================================================================
msg_info "Installing openDesk"
WORKDIR="/opt/opendesk"
mkdir -p $WORKDIR
git clone https://gitlab.opencode.de/bmi/opendesk/deployment/opendesk.git $WORKDIR
cd $WORKDIR

# =============================================================================
# Finishing Up
# =============================================================================

motd_ssh
customize

# cleanup_lxc handles: apt autoremove, autoclean, temp files, bash history
cleanup_lxc
