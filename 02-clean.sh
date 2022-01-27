#!/bin/bash
export TEKTON_KNS="tekton-pipelines"
export PIPE_KNS="default"
export VAULT_KNS="vault"


if ! which tkn > /dev/null;then
  echo -e "\nPlease, install Tekton CLI tool...\n"
  exit 1
fi 

# Cleaning Tekton objects
tkn t delete --all -f -n $PIPE_KNS
tkn tr delete --all -f -n $PIPE_KNS
tkn p delete --all -f -n $PIPE_KNS
tkn pr delete --all -f -n $PIPE_KNS


# Uninstalling Tekton
kubectl delete --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Uninstall Tekton-Dashboard
kubectl delete --filename https://github.com/tektoncd/dashboard/releases/latest/download/tekton-dashboard-release.yaml

# Removing configs created
kubectl delete -f ./config

# Uninstalling Vault
helm uninstall vault -n $VAULT_KNS 

# Removing Vault PVCs in the namespace
kubectl delete pvc -n $VAULT_KNS --all

# Deleting namespaces
kubectl delete ns $TEKTON_KNS $VAULT_KNS

