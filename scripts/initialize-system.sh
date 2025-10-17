#!/bin/bash

set -euo pipefail

export DEBIAN_FRONTEND='noninteractive'
export LC_ALL='en_US.UTF-8'
SSH_PORT='33133'
KUBERNETES_MINOR='1.33'
KUBERNETES_VERSION="${KUBERNETES_MINOR}.5" # 1.33.5
# CRUN_VERSION='1.9'
# OCI_RUNTIME='runc' # crun
CRI='crio' # containerd

_update_packages () {
  echo "* updating packages"
  apt-get -q update &>/dev/null
  apt-get -qy upgrade &>/dev/null
  apt-get -qy install ipvsadm jq mc &>/dev/null
}

_remove_unneeded_packages () {
  echo "* remove unneeded packages"
  apt-get -qy purge multipath-tools packagekit polkitd snapd &>/dev/null
  apt-get -qy autoremove &>/dev/null
}

# _install_kernel () {
#   echo "* installing mainline kernel 6.5.3"
#   local pwd="$PWD"
#   mkdir -v ~/kernel
#   cd ~/kernel
#   curl -LOOOO https://kernel.ubuntu.com/~kernel-ppa/mainline/v6.5.3/amd64/linux-headers-6.5.3-060503-generic_6.5.3-060503.202309130834_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v6.5.3/amd64/linux-headers-6.5.3-060503_6.5.3-060503.202309130834_all.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v6.5.3/amd64/linux-image-unsigned-6.5.3-060503-generic_6.5.3-060503.202309130834_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v6.5.3/amd64/linux-modules-6.5.3-060503-generic_6.5.3-060503.202309130834_amd64.deb
#   # shellcheck disable=SC2251
#   ! dpkg -i ./*.deb
#   sed -Ei 's/libc6 \(>= 2\.38\)/libc6 (>= 2.35)/' /var/lib/dpkg/status
#   apt-get -qf install
#   cd "$pwd"
# }

_get_public_interface () {
  ip ro | grep 'default via' | cut -d ' ' -f 5
}

_get_mac_address () {
  local interface="$1"
  ip add sh dev "$interface" | grep link/ether | tr -s ' ' | cut -d ' ' -f 3
}

# _disable_ipv6 () {
#   echo "* disabling ipv6"
#   sed -Ei 's/GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 ipv6.disable=1"/' /etc/default/grub
#   update-grub
#   local mac_address
#   mac_address="$(_get_mac_address "$(_get_public_interface)")"
#   cp -v /etc/netplan/50-cloud-init.yaml "/etc/netplan/50-cloud-init.yaml-$(date +%s).bak"
#   cat <<EOT >/etc/netplan/50-cloud-init.yaml
# network:
#   version: 2
#   ethernets:
#     eth0:
#       dhcp4: true
#       match:
#         macaddress: $mac_address
#       set-name: eth0
# EOT
# }

_install_chrony () {
  echo "* installing chrony"
  apt-get -qy install chrony &>/dev/null
}

_configure_ssh () {
  echo "* configuring ssh"
  mkdir -p /etc/systemd/system/ssh.socket.d
  cat >/etc/systemd/system/ssh.socket.d/port.conf <<EOF
[Socket]
ListenStream=
ListenStream=0.0.0.0:$SSH_PORT
ListenStream=[::]:$SSH_PORT
EOF
  systemctl daemon-reload
  systemctl restart ssh.socket
}

_enable_bash_completion () {
  echo "* enabling bash completion"
  sed -i '35,41s/^#//' /etc/bash.bashrc
}

_add_k8s_repositories () {
  echo "* adding kubernetes repositories"
  rm -fv /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/deb/ /" >/etc/apt/sources.list.d/kubernetes.list
  if [ "$CRI" = "crio" ] || [ "$CRI" = "cri-o" ]; then
    rm -fv /etc/apt/keyrings/cri-o-apt-keyring.gpg
    curl -fsSL "https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v$KUBERNETES_MINOR/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v$KUBERNETES_MINOR/deb/ /" >/etc/apt/sources.list.d/cri-o.list
  fi
  apt-get -q update &>/dev/null
}

_install_k8s_packages () {
  local cri_package="cri-o"
  if [ "$CRI" != "crio" ] && [ "$CRI" != "cri-o" ]; then
    cri_package="containerd"
  fi
  echo "* installing kubernetes $KUBERNETES_VERSION packages and $cri_package"
  apt-get -qy install "kubeadm=${KUBERNETES_VERSION}-1.1" "kubectl=${KUBERNETES_VERSION}-1.1" "kubelet=${KUBERNETES_VERSION}-1.1" $cri_package &>/dev/null
  apt-mark hold kubeadm kubectl kubelet $cri_package
  systemctl disable kubelet
  # if [ "$cri_package" = "cri-o" ]; then
  #   curl -Lo /usr/sbin/crun https://github.com/containers/crun/releases/download/${CRUN_VERSION}/crun-${CRUN_VERSION}-linux-amd64
  #   chmod +x /usr/sbin/crun
  # fi
  if [ "$cri_package" = "containerd" ]; then
    systemctl stop containerd
  fi
}

_configure_crio () {
  echo "* configuring cri-o"
  rm -fv /etc/cni/net.d/*.conflist
  mkdir -pv /var/lib/crio
  systemctl enable crio
}

_configure_containerd () {
  echo "* configuring containerd"
  mkdir -v /etc/containerd
  containerd config default >/etc/containerd/config.toml
  sed -e 's/SystemdCgroup = false/SystemdCgroup = true/' -e 's/pause:3.8/pause:3.9/' -i /etc/containerd/config.toml
  cat <<EOT >/etc/crictl.yaml
runtime-endpoint: "unix:///run/containerd/containerd.sock"
timeout: 0
debug: false
EOT
}

_configure_kernel () {
  # rbd is needed, otherwise csi-rbdplugin fails to start with the following error:
  # csi-rbdplugin E1018 17:16:35.443611  259389 rbd_util.go:303] modprobe failed (an error (exit status 1) occurred while running modprobe args: [rbd]): "modprobe: ERROR: could not insert 'rbd': Exec format error\n"

#   echo "* configuring kernel"
#   cat <<EOF >/etc/modules-load.d/kubeadm.conf
# br_netfilter
# rbd
# EOF
  cat <<EOF >/etc/sysctl.d/kubeadm.conf
net.ipv4.ip_forward = 1
EOF
}

_configure_user () {
  local username="$1"
  local name="$2"
  local ssh_public_key="$3"
  adduser --disabled-password --gecos "$name" "$username"
  mkdir "/home/$username/.ssh"
  chmod 0700 "/home/$username/.ssh"
  echo "$ssh_public_key" >"/home/$username/.ssh/authorized_keys"
  chmod 0600 "/home/$username/.ssh/authorized_keys"
  chown -R "$username:$username" "/home/$username/.ssh"
  usermod -a -G sudo "$username"
  sed -i '/^%sudo/c\%sudo\tALL=(ALL) NOPASSWD:ALL' /etc/sudoers
}

_zap_ceph_disk () {
  # see https://rook.io/docs/rook/v1.12/Getting-Started/ceph-teardown/#zapping-devices
  if [ -b /dev/sdb ]; then
    sgdisk --zap-all /dev/sdb
    dd if=/dev/zero of=/dev/sdb bs=1M count=100 oflag=direct,dsync
  fi
}

if [ $# -ne 3 ]; then
  echo "Usage: $0 USERNAME NAME SSH_PUBLIC_KEY" >&2
  exit 1
fi

_remove_unneeded_packages
_update_packages
# _install_kernel
# _disable_ipv6
_install_chrony
_configure_ssh
_enable_bash_completion
_add_k8s_repositories
_install_k8s_packages
if [ "$CRI" = "crio" ] || [ "$CRI" = "cri-o" ]; then
  _configure_crio
else
  _configure_containerd
fi
_configure_kernel
_configure_user "$@"
_zap_ceph_disk
