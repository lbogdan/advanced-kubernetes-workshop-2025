#!/bin/bash

set -euo pipefail

_kubeadm_config () {
  mkdir -pv /etc/kubernetes/kubeadm
  cat <<EOT >/etc/kubernetes/kubeadm/config.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
controllerManager:
  extraArgs:
    - name: bind-address
      value: 0.0.0.0
etcd:
  local:
    extraArgs:
      - name: listen-metrics-urls
        value: http://0.0.0.0:2381
kubernetesVersion: v1.33.5
networking:
  podSubnet: 192.168.0.0/16
  serviceSubnet: 10.96.0.0/12
  dnsDomain: cluster.local
scheduler:
  extraArgs:
    - name: bind-address
      value: '0.0.0.0'
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
serverTLSBootstrap: true
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
metricsBindAddress: "0.0.0.0:10249"
mode: ipvs
EOT
  chmod 0600 /etc/kubernetes/kubeadm/config.yaml
}

systemctl enable kubelet
if [[ "$(hostname)" =~ -cp- ]]; then
  _kubeadm_config
fi

# check if not blocked by google
crictl pull registry.k8s.io/pause:3.10
