#!/bin/bash

# Tears down the local kind cluster and stops the shared Postgres/
# Elasticsearch containers.
#
# Usage: ./delete-env.sh [CLUSTER_NAME]   (default cluster name: local)

CLUSTER_NAME="${1:-local}"

echo "Deleting kind cluster '$CLUSTER_NAME'"
kind delete cluster --name "$CLUSTER_NAME"

echo "Stopping shared Postgres + Elasticsearch containers"
docker-compose -f docker/docker-compose.yml down
