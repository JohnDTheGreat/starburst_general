#!/bin/bash

# This script will gather logs from all pods in a given namespace and context
# It will then tar and gzip the logs and place them in the current directory

# Initialize variables
K8CONTEXT=""
K8NAMESPACE=""

#Get input from command line options to set variables
while getopts ":c:n:" opt; do
  case $opt in
    c) K8CONTEXT="$OPTARG"
    ;;
    n) K8NAMESPACE="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

# Check if variables are set
if [ -z "$K8CONTEXT" ]; then
  echo "kubernetes context is unset"
  echo "Please enter a context with the -c option"
  exit 1
fi

if [ -z "$K8NAMESPACE" ]; then
  echo "kubernetes namespace is unset"
  echo "Please enter a namespace with the -n option"
  exit 1
fi

# Function for printing message to stdout with preceding timestamp
function print_msg {
  printf "$(date +%Y-%m-%d" "%H:%M:%S) $1\n"
}

# Create directory to store logs with K8NAMESPACE and K8CONTEXT and timestamp
LOGDIR="namespace-$K8NAMESPACE"'_'"context-$K8CONTEXT"'_'"$(date +%Y-%m-%d_%H-%M-%S)"
print_msg "Log directory is: $LOGDIR"
mkdir $LOGDIR

# Get pods in context and namespace
PODS=$(kubectl get pods -n $K8NAMESPACE --context $K8CONTEXT | awk '{print $1}' | grep -v NAME)

# # For testing
# PODS="coordinator-9b999cd76-tz9mf worker-5d58dd7855-7m2nr"

print_msg "Pods we will be collecting information against: \n$PODS"

# Loop through pods and get container names then get logs for each container
for pod in $PODS
do
  print_msg "Getting logs for pod: \n$pod"
  CONTAINERS=$(kubectl get pods $pod -n $K8NAMESPACE --context $K8CONTEXT -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}')
  print_msg "Containers in pod $pod:"
  for container in $CONTAINERS 
  do
    print_msg "$container"
  done
  for container in $CONTAINERS
  do
    print_msg "Getting logs for container: \n$container"
    FILENAME="$pod-$container.$(date +%Y-%m-%d_%H-%M-%S).log"
    kubectl logs $pod -n $K8NAMESPACE -c $container --context $K8CONTEXT > $LOGDIR/$FILENAME
    print_msg "Log collected for container: $container and saved to: $LOGDIR/$FILENAME"
  done
done










