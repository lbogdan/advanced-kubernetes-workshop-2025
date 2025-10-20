#!/usr/bin/env bash

set -euo pipefail

CP_IP=''

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

# install_metrics_server
install_ingress_nginx
