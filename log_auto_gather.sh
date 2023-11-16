#!/bin/bash

# This script will gather logs from all pods in a given namespace and context
# It will then tar and gzip the logs and place them in the current directory

# Initialize variables
K8CONTEXT="aws"
K8NAMESPACE="default"

# Get input from command line options to set variables
# while getopts ":c:n:" opt; do
#   case $opt in
#     c) K8CONTEXT="$OPTARG"
#     ;;
#     n) K8NAMESPACE="$OPTARG"
#     ;;
#     \?) echo "Invalid option -$OPTARG" >&2
#     ;;
#   esac
# done

# Get pods in context and namespace
PODS=$(kubectl get pods -n $K8NAMESPACE --context $K8CONTEXT | awk '{print $1}' | grep -v NAME)

echo "PODS: $PODS"








