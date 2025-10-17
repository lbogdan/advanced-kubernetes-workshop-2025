#!/bin/bash

set -euo pipefail

_ssh_config () {
  local username="$1"
  local type="$2"
  local ip="$3"
  cat <<EOT
Host $username-$type-0
  HostName $ip
  User $username
  Port 33133
EOT
}

while IFS= read -r user
do
  if USERNAME="$(echo "$user" | yq -e .username 2>/dev/null)"; then
    if CP_IP="$(echo "$user" | yq -e .cpIp 2>/dev/null)"; then
      _ssh_config "$USERNAME" cp "$CP_IP"
    fi
    if NODE_IP="$(echo "$user" | yq -e .nodeIp 2>/dev/null)"; then
      _ssh_config "$USERNAME" node "$NODE_IP"
    fi
  fi
done < <(yq -I 0 -o json .users[] workshop.yaml)
