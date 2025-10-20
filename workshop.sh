#!/usr/bin/env bash

set -euo pipefail

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

install_metrics_server
