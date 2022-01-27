#!/bin/bash
export VAULT_KNS="vault"
export TKNS="tektoncd"

kubectl create ns $VAULT_KNS
#kubectl create ns $TKNS

# Installing Vault in Development mode without the Vault Injector
helm install vault --set injector.enabled=false --set server.dev.enabled=true -n $VAULT_KNS hashicorp/vault

# Installing Tekton
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Installing Tekton Dashboard
kubectl apply --filename https://github.com/tektoncd/dashboard/releases/latest/download/tekton-dashboard-release.yaml

