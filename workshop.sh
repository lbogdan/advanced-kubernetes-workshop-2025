#!/usr/bin/env bash

set -euo pipefail

CP_IP='157.180.123.220'

install_metrics_server() {
  repo_name='metrics-server'
  repo_url='https://kubernetes-sigs.github.io/metrics-server/'
  app_name='metrics-server'
  chart_name='metrics-server'
  namespace='kube-system'
  helm repo add "$repo_name" "$repo_url"
  helm repo update "$repo_name"
  helm diff upgrade --color --install "$app_name" --namespace "$namespace" "$repo_name/$chart_name" | less -R
  helm upgrade --install "$app_name" --namespace "$namespace" "$repo_name/$chart_name"
}

install_ingress_nginx() {
  repo_name='ingress-nginx'
  repo_url='https://kubernetes.github.io/ingress-nginx'
  app_name='ingress-nginx'
  chart_name='ingress-nginx'
  namespace='ingress-nginx'
  helm repo add "$repo_name" "$repo_url"
  helm repo update "$repo_name"
  values="$(sed -e "s|\$CP_IP|$CP_IP|" manifests/helm/ingress-nginx-values.yaml)"
  helm diff upgrade --color --install "$app_name" --namespace "$namespace" "$repo_name/$chart_name" --values <(echo "$values") | less -R
  helm upgrade --create-namespace --install "$app_name" --namespace "$namespace" "$repo_name/$chart_name" --values <(echo "$values")
}

install_cert_manager() {
  repo_url='oci://quay.io/jetstack/charts/cert-manager'
  app_name='cert-manager'
  namespace='cert-manager'
  version='v1.19.1'
  # helm diff upgrade --color --install "$app_name" --namespace "$namespace" "$repo_url" --version "$version" --values manifests/helm/cert-manager-values.yaml | less -R
  helm upgrade --create-namespace --install "$app_name" --namespace "$namespace" "$repo_url" --version "$version" --values manifests/helm/cert-manager-values.yaml
}

EMAIL='luca.bogdan@gmail.com'

create_clusterissuer() {
  manifest="$(sed -e "s|\$EMAIL|$EMAIL|" manifests/clusterissuer.yaml)"
  echo "$manifest" | kubectl apply -f -
}

install_rook_ceph() {
  repo_name='rook-release'
  repo_url='https://charts.rook.io/release'
  app_name='rook-ceph'
  chart_name='rook-ceph'
  namespace='rook-ceph'
  helm repo add "$repo_name" "$repo_url"
  helm repo update "$repo_name"
  # helm diff upgrade --color --install "$app_name" --namespace "$namespace" "$repo_name/$chart_name" --values manifests/helm/rook-ceph-values.yaml | less -R
  helm upgrade --create-namespace --install "$app_name" --namespace "$namespace" "$repo_name/$chart_name" --values manifests/helm/rook-ceph-values.yaml
}

install_kube_prometheus_stack() {
  repo_url='oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack'
  app_name='kube-prometheus-stack'
  namespace='monitoring'
  helm diff upgrade --color --disable-validation --install "$app_name" --namespace "$namespace" "$repo_url" --values manifests/helm/kube-prometheus-stack-values.yaml | less -R
  helm upgrade --create-namespace --install "$app_name" --namespace "$namespace" "$repo_url" --values manifests/helm/kube-prometheus-stack-values.yaml
}

# install_metrics_server
# install_ingress_nginx
# install_cert_manager
# create_clusterissuer
# install_rook_ceph
install_kube_prometheus_stack
