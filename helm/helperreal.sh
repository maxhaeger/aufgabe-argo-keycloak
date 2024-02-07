#!/bin/bash

# This script sets up a Kubernetes cluster using k3d, creates the ArgoCD namespace if it doesn't exist,
# installs or upgrades the environment, waits for the nginx-ingress-controller to be ready,
# waits for the external IP to be ready, installs or upgrades the frontend, installs or upgrades ArgoCD,
# syncs the repository with ArgoCD, and installs or upgrades Keycloak.

# Command to create a k3d cluster if it doesn't exist
create_k3d_cluster() {
  if ! k3d cluster list | grep -q "k3s-default"; then
    k3d cluster create --k3s-arg "--disable=traefik@server:*"
    echo "Wait to set the pods"
    sleep 20
  fi
}

# Command to create the ArgoCD namespace if it doesn't exist
create_argocd_namespace() {
  if $(kubectl get namespace argocd >/dev/null 2>&1); then
    echo ArgoCD Namespace Exists
  else
    kubectl create namespace argocd
  fi
}

# Command to install or upgrade the environment
install_or_upgrade_environment() {
  if helm status environment >/dev/null 2>&1; then
    helm upgrade environment ./environment
  else
    helm install environment ./environment
  fi
  echo Environment Installed/Upgraded
}

# Command to wait for nginx-ingress-controller to be ready
wait_for_ingress_controller() {
  service="ingress-nginx-controller-admission"
  namespace="ingress-nginx"
  endpoints=""

  while [ -z "$endpoints" ]; do
    echo "Waiting for $service endpoints to be ready..."
    endpoints=$(kubectl get endpoints $service -n $namespace -o jsonpath='{.subsets[*].addresses[*].ip}')
    if [ -z "$endpoints" ]; then
      sleep 10
    fi
  done

  echo "$service endpoints are ready."
}

# Command to wait for external IP to be ready
wait_for_external_ip() {
  echo Waiting for external IP to be ready...
  external_ip=""
  while [ -z $external_ip ] ; do
    echo "Waiting for end point..."
    external_ip=$(kubectl get svc ingress-nginx-controller -n ingress-nginx --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
    [ -z "$external_ip" ] && sleep 10
  done

  echo 'End point ready:' && echo $external_ip
}

# Command to install or upgrade the frontend
install_or_upgrade_frontend() {
  if helm status frontend >/dev/null 2>&1; then
    helm upgrade frontend ./frontend
  else
    helm install frontend ./frontend
  fi
  echo Frontend Installed/Upgraded
}

# Command to install or upgrade ArgoCD
install_or_upgrade_argocd() {
  if helm status argocd -n argocd >/dev/null 2>&1; then
    helm upgrade argocd ./argocd -n argocd
  else
    helm install argocd ./argocd -n argocd --create-namespace
  fi
  echo ArgoCD Installed/Upgraded
  sleep 10
}

# Command to sync the repository with ArgoCD
sync_repo_with_argocd() {
  echo Sync Repo with Argo-CRD "Application"
  kubectl apply -f ./argosetup.yml -n argocd
}

# Command to install or upgrade Keycloak
install_or_upgrade_keycloak() {
  if helm status keycloak -n keycloak >/dev/null 2>&1; then
    helm upgrade keycloak ./keycloak -n keycloak
  else
    helm install keycloak ./keycloak -n keycloak --create-namespace 
  fi
  echo Keycloak Installed/Upgraded
}

