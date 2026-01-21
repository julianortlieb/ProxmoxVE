#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: [YourGitHubUsername]
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: [SOURCE_URL e.g. https://github.com/example/app]

# App Default Values
APP="openDesk"
var_tags="${var_tags:-documents}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-16384}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

# =============================================================================
# CONFIGURATION GUIDE
# =============================================================================
# APP           - Display name, title case (e.g. "Koel", "Wallabag", "Actual Budget")
# var_tags      - Max 2 tags, semicolon separated (e.g. "music;streaming", "finance")
# var_cpu       - CPU cores: 1-4 typical
# var_ram       - RAM in MB: 512, 1024, 2048, 4096 typical
# var_disk      - Disk in GB: 4, 6, 8, 10, 20 typical
# var_os        - OS: debian, ubuntu, alpine
# var_version   - OS version: 12/13 (debian), 22.04/24.04 (ubuntu), 3.20/3.21 (alpine)
# var_unprivileged - 1 = unprivileged (secure, default), 0 = privileged (for docker etc.)

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  # Check if installation exists
  if [[ ! -d /opt/opendesk ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating ${APP} LXC"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:[PORT]${CL}"
