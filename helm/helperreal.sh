#!/bin/bash

# Überprüfen, ob das k3s-Cluster "k3s-default" existiert, andernfalls erstellen
if ! k3d cluster list | grep -q "k3s-default"; then
  k3d cluster create --k3s-arg "--disable=traefik@server:*"
  echo "Warte, bis die Pods bereit sind"
  sleep 20
fi

# Überprüfen, ob der Namespace "argocd" existiert, andernfalls erstellen
if $(kubectl get namespace argocd >/dev/null 2>&1); then
  echo ArgoCD Namespace existiert
else
  kubectl create namespace argocd
fi

# Überprüfen, ob das Helm-Release "environment" existiert, andernfalls installieren oder aktualisieren
if helm status environment >/dev/null 2>&1; then
  helm upgrade environment ./environment
else
  helm install environment ./environment
fi
echo Umgebung installiert/aktualisiert
echo Warte auf die Bereitschaft des nginx-ingress-Controllers...

service="ingress-nginx-controller-admission"
namespace="ingress-nginx"
endpoints=""

# Warten, bis die Endpunkte des Services "ingress-nginx-controller-admission" bereit sind
while [ -z "$endpoints" ]; do
  echo "Warte auf die Bereitschaft der Endpunkte von $service..."
  endpoints=$(kubectl get endpoints $service -n $namespace -o jsonpath='{.subsets[*].addresses[*].ip}')
  if [ -z "$endpoints" ]; then
    sleep 10
  fi
done

echo "Endpunkte von $service sind bereit."

echo Warte auf die Bereitschaft der externen IP...
external_ip=""
while [ -z $external_ip ] ; do
  echo "Warte auf den Endpunkt..."
  external_ip=$(kubectl get svc ingress-nginx-controller -n ingress-nginx --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  [ -z "$external_ip" ] && sleep 10
done

echo 'Externe IP:' && echo $external_ip

# Überprüfen, ob das Helm-Release "frontend" existiert, andernfalls installieren oder aktualisieren
if helm status frontend >/dev/null 2>&1; then
  helm upgrade frontend ./frontend
else
  helm install frontend ./frontend
fi
echo Frontend installiert/aktualisiert

# Überprüfen, ob das Helm-Release "argocd" im Namespace "argocd" existiert, andernfalls installieren oder aktualisieren
if helm status argocd -n argocd >/dev/null 2>&1; then
  helm upgrade argocd ./argocd -n argocd
else
  helm install argocd ./argocd -n argocd --create-namespace
fi
echo ArgoCD installiert/aktualisiert
sleep 10

# ArgoCD-Application-CRD installieren 
# TODO: Featureflag als Parameter hinzufügen für syncPolicy
echo Synchronisiere das Repository mit Argo-CRD "Application"

kubectl apply -f ./argosetup.yml -n argocd

# Überprüfen, ob das Helm-Release "keycloak" im Namespace "keycloak" existiert, andernfalls installieren oder aktualisieren
if helm status keycloak -n keycloak >/dev/null 2>&1; then
  helm upgrade keycloak ./keycloak -n keycloak
else
  helm install keycloak ./keycloak -n keycloak --create-namespace 
fi
echo Keycloak installiert/aktualisiert

# Helm-Release "monitoring" auskommentiert

# kubectl apply -f ../argosetup.yml

# echo ArgoCD konfiguriert
