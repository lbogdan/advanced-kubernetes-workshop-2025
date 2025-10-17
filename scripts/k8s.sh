#!/bin/bash

set -euo pipefail

_init_ssh () {
  local ip="$1"
  local port="$2"
  echo "* initializing ssh to $ip:$port"
  if [ "$port" = 22 ]; then
    ssh-keygen -R "$ip" &>/dev/null
  else
    ssh-keygen -R "[$ip]:$port" &>/dev/null
  fi
  ssh -o StrictHostKeyChecking=accept-new -p "$port" "root@$ip" hostname &>/dev/null
}

_initialize_system () {
  local ip="$1"
  local username="$2"
  local name="$3"
  local ssh_public_key="$4"
  echo "* initializing system: ip: [$ip], username: [$username], name: [$name], key: [$ssh_public_key]"
  # shellcheck disable=SC2029
  ssh "root@$ip" 'bash -s' <./initialize-system.sh "'$username'" "'$name'" "'$ssh_public_key'"
}

_wait_for_down () {
  local ip="$1"
  local count=0
  echo "* waiting for $ip to go down"
  while ping -c 1 -W 1 "$ip" &>/dev/null; do
    sleep 1
    ((count=count+1))
  done
  echo "  done in ${count}s"
}

_wait_for_up () {
  local ip="$1"
  local count=0
  echo "* waiting for $ip to come up"
  while ! ping -c 1 -W 1 "$ip" &>/dev/null; do
    ((count=count+1))
  done
  echo "  done in ${count}s"
}

_reboot () {
  local ip="$1"
  echo "* rebooting $ip"
  # shellcheck disable=SC2251
  ! ssh -p 33133 "root@$ip" systemctl reboot
  _wait_for_down "$ip"
  _wait_for_up "$ip"
}

_after () {
  local ip="$1"
  ssh -p 33133 "root@$ip" 'bash -s' <final.sh
}

if [ $# -ne 4 ]; then
  echo "Usage: $0 VPS_IP USERNAME NAME PUBLIC_SSH_KEY" >&2
  exit 1
fi

VPS_IP="$1"

_init_ssh "$VPS_IP" 22
_initialize_system "$@"
_reboot "$VPS_IP"
sleep 5
_init_ssh "$VPS_IP" 33133
_after "$VPS_IP"
