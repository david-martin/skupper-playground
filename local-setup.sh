#!/bin/bash

# shellcheck shell=bash

set -xe

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/bin"
KIND_CLUSTER_PREFIX="skupper-cluster-"

KIND="${BIN_DIR}/kind"
KUSTOMIZE="${BIN_DIR}/kustomize"

METALLB_KUSTOMIZATION_DIR=${LOCAL_SETUP_DIR}/config/metallb
SKUPPER_RESOURCES_DIR=${LOCAL_SETUP_DIR}/config/skupper
EXAMPLES_DIR=${LOCAL_SETUP_DIR}/config/examples

kindCreateCluster() {
  local cluster=$1;
  local port80=$2;
  local port443=$3;
  cat <<EOF | ${KIND} create cluster --name ${cluster} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.26.0
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: ${port80}
    protocol: TCP
  - containerPort: 443
    hostPort: ${port443}
    protocol: TCP
EOF
mkdir -p ./tmp/kubeconfigs
${KIND} get kubeconfig --name ${cluster} > ./tmp/kubeconfigs/${cluster}.kubeconfig
${KIND} export kubeconfig --name ${cluster} --kubeconfig ./tmp/kubeconfigs/internal/${cluster}.kubeconfig --internal
}

deployMetalLB () {
  clusterName=${1}
  metalLBSubnet=${2}

  kubectl config use-context kind-${clusterName}
  echo "Deploying MetalLB to ${clusterName}"
  ${KUSTOMIZE} build ${METALLB_KUSTOMIZATION_DIR} | kubectl apply -f -
  while (test $(kubectl -n metallb-system get pod --selector=app=metallb -o name | wc -l) -le 1)
  do
    echo "Waiting for metallb pods to exist"
    sleep 3
  done
  echo "Waiting for deployments to be ready ..."
  kubectl -n metallb-system wait --for=condition=ready pod --selector=app=metallb --timeout=90s
  echo "Creating MetalLB AddressPool"
  cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - 172.18.${metalLBSubnet}.0/24
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
}

cleanClusters() {
	# Delete existing kind clusters
	clusterCount=$(${KIND} get clusters | grep ${KIND_CLUSTER_PREFIX} | wc -l)
	if ! [[ $clusterCount =~ "0" ]] ; then
		echo "Deleting previous kind clusters."
		${KIND} get clusters | grep ${KIND_CLUSTER_PREFIX} | xargs ${KIND} delete clusters
	fi	
}

createSkupperClusterPolicyCRDs() {
  clusterName=${1}
  kubectl config use-context kind-${clusterName}
  kubectl apply -f ${SKUPPER_RESOURCES_DIR}/skupper_cluster_policy_crd.yaml
}

port80=9090
port443=8445
metalLBSubnetStart=200

cleanClusters

for ((i = 1; i <= 2; i++)); do
  kindCreateCluster ${KIND_CLUSTER_PREFIX}${i} $((${port80} + ${i} - 1)) $((${port443} + ${i} - 1))
  createSkupperClusterPolicyCRDs ${KIND_CLUSTER_PREFIX}${i}
  deployMetalLB ${KIND_CLUSTER_PREFIX}${i} $((${metalLBSubnetStart} + ${i} - 1))
done;

# Initialise Skupper
export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-1.kubeconfig
kubectl create namespace west
kubectl config set-context --current --namespace west
skupper init --enable-console --enable-flow-collector
kubectl apply -f ${EXAMPLES_DIR}/skupperclusterpolicy_1.yaml
skupper status

export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-2.kubeconfig
kubectl create namespace east
kubectl config set-context --current --namespace east
skupper init
kubectl apply -f ${EXAMPLES_DIR}/skupperclusterpolicy_1.yaml
skupper status

# Link Sites
export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-1.kubeconfig
skupper token create ~/west.token

export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-2.kubeconfig
skupper link create ~/west.token

# Output status
export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-1.kubeconfig
skupper status

export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-2.kubeconfig
skupper status