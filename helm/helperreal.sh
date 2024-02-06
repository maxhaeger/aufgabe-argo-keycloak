#!/bin/bash

if ! k3d cluster list | grep -q "k3s-default"; then
  k3d cluster create --k3s-arg "--disable=traefik@server:*"
  echo "Wait to set the pods"
  sleep 20
fi

if $(kubectl get namespace argocd >/dev/null 2>&1); then
  echo ArgoCD Namespace Exists
else
  kubectl create namespace argocd
fi

if helm status frontend >/dev/null 2>&1; then
  helm upgrade frontend ./frontend
else
  helm install frontend ./frontend
fi
echo Frontend Installed/Upgraded

if helm status environment >/dev/null 2>&1; then
  helm upgrade environment ./environment
else
  helm install environment ./environment
fi
echo Environment Installed/Upgraded

external_ip=""
while [ -z $external_ip ]; do
  echo "Waiting for end point..."
  external_ip=$(kubectl get svc ingress-nginx-controller -n ingress-nginx --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  [ -z "$external_ip" ] && sleep 10
done
echo 'End point ready:' && echo $external_ip

if helm status argocd >/dev/null 2>&1; then
  helm upgrade argocd ./argocd -n argocd
else
  helm install argocd ./argocd -n argocd --create-namespace
fi
echo ArgoCD Installed/Upgraded
 sleep 30
 echo Sync Repo with Argo-CRD "Application"
 kubectl apply -f ./argosetup.yml -n argocd

if helm status keycloak >/dev/null 2>&1; then
  helm upgrade keycloak ./keycloak -n keycloak
else
  helm install environment ./environment -n keycloak --create-namespace 
fi
echo Environment Installed/Upgraded
# if helm status monitoring >/dev/null 2>&1; then
#   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
#   helm upgrade monitoring ./monitoring -n monitoring
# else
#  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
#  helm install monitoring prometheus-community/prometheus -n monitoring
#  helm install monitoring ./monitoring -n monitoring
# fi
# echo Monitoring Installed/Upgraded

  

# kubectl apply -f ../argosetup.yml

# echo ArgoCD configured

