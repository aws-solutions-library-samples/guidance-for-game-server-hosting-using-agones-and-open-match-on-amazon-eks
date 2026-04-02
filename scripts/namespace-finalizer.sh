#!/usr/bin/env bash
## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
set -euo pipefail

NAMESPACE="${1:?Usage: namespace-finalizer.sh <namespace>}"
MAX_RETRIES=5
RETRY_DELAY=5

for i in $(seq 1 "$MAX_RETRIES"); do
  # Check if namespace still exists
  if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
    echo "Namespace $NAMESPACE does not exist or is already deleted."
    exit 0
  fi

  # Check if namespace is stuck in Terminating
  PHASE=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [ "$PHASE" != "Terminating" ]; then
    echo "Namespace $NAMESPACE is in phase '$PHASE', not Terminating. Skipping finalizer removal."
    exit 0
  fi

  # Remove all finalizers from the namespace
  echo "Attempt $i/$MAX_RETRIES: Clearing finalizers on namespace $NAMESPACE..."
  if kubectl get namespace "$NAMESPACE" -o json \
    | jq '.spec.finalizers = []' \
    | kubectl replace --raw "/api/v1/namespaces/${NAMESPACE}/finalize" -f - > /dev/null 2>&1; then
    echo "Successfully cleared finalizers on namespace $NAMESPACE."
    exit 0
  fi

  echo "Attempt $i failed. Retrying in ${RETRY_DELAY}s..."
  sleep "$RETRY_DELAY"
done

echo "WARNING: Failed to clear finalizers on namespace $NAMESPACE after $MAX_RETRIES attempts."
exit 1
