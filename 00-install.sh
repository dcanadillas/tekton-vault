#!/bin/bash
export VAULT_KNS="vault"

check_prereqs() {
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl could not be found"
        exit 1
    fi

    # Check if Helm is installed
    if ! command -v helm &> /dev/null; then
        echo "Helm could not be found"
        exit 1
    fi

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "jq could not be found"
        exit 1
    fi
}



install() {
  local vault_namespace=$1

  # Adding the HashiCorp Helm repository
  helm repo add hashicorp https://helm.releases.hashicorp.com
  helm repo update

  # Installing Vault in Development mode without the Vault Injector
  kubectl create ns $vault_namespace
  helm install vault --set injector.enabled=false --set server.dev.enabled=true -n $vault_namespace hashicorp/vault

  # Installing Tekton
  kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

  # Installing Tekton Dashboard
  kubectl apply --filename https://github.com/tektoncd/dashboard/releases/latest/download/tekton-dashboard-release.yaml
}

# FUN STARTS HERE
check_prereqs
install $VAULT_KNS
