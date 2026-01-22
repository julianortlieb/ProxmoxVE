#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Julian Ortlieb (julianortlieb)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://gitlab.opencode.de/bmi/opendesk/

# Import Functions and Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# =============================================================================
# VARIABLES
# =============================================================================
export DOMAIN="opendesk-pve.internal"
echo "export DOMAIN=${DOMAIN}" >>/etc/profile.d/opendesk.sh

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
$STD curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik --write-kubeconfig-mode 644" sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
$STD echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >>/root/.bashrc
sleep 10
$STD kubectl wait --for=condition=Ready nodes --all --timeout=120s
msg_ok "Installed k3s"

# =============================================================================
# INSTALL HELM, HELMFILE, HELMDIFF, CERT-MANAGER, INGRESS-NGINX
# =============================================================================
msg_info "Installing Helm, Helmfile, Helmdiff, Cert-Manager, Ingress-NGINX"
# Helm
$STD curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash
# Helmfile
HELMFILE_VERSION=$($STD curl -s "https://api.github.com/repos/helmfile/helmfile/releases/latest" | jq -r .tag_name)
$STD curl "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz" -o /tmp/helmfile_linux_amd64.tar.gz
$STD tar -xzf /tmp/helmfile_linux_amd64.tar.gz -C /tmp
mv /tmp/helmfile /usr/local/bin/helmfile
chmod +x /usr/local/bin/helmfile
rm /tmp/helmfile_linux_amd64.tar.gz

# Helmdiff
$STD helm plugin install https://github.com/databus23/helm-diff --verify=false

# Cert-Manager cert-manager.io
$STD helm repo add jetstack https://charts.jetstack.io --force-update
$STD helm repo update
$STD helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.19.2 \
  --set crds.enabled=true

# Ingress-NGINX
$STD helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
$STD helm repo update
$STD helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.watchIngressWithoutClass=true
$STD kubectl wait --namespace ingress-nginx --for=condition=available deployment/ingress-nginx-controller --timeout=120s

# =============================================================================
# INSTALL OPENDESK VIA HELMFILE
# =============================================================================
msg_info "Installing openDesk"
WORKDIR="/opt/opendesk"
mkdir -p $WORKDIR
$STD git clone https://gitlab.opencode.de/bmi/opendesk/deployment/opendesk.git $WORKDIR
cd $WORKDIR/helmfile || exit

$STD helmfile apply -e default -n opendesk

# =============================================================================
# Finishing Up
# =============================================================================

motd_ssh
customize

# cleanup_lxc handles: apt autoremove, autoclean, temp files, bash history
cleanup_lxc
