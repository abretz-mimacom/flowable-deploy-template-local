#!/bin/bash

# Removes the Flowable Platform releases from the local docker-desktop cluster
# and stops the shared Postgres/Elasticsearch containers.
# The Docker Desktop Kubernetes cluster itself is left running (it's shared
# with anything else you use Docker Desktop's Kubernetes for).
#
# Usage:
#   ./delete-env.sh --all       # remove dev, test and stg
#   ./delete-env.sh <namespace> # remove a single namespace

delete_namespace() {
	local namespace="$1"
	echo "Removing Flowable Platform from namespace '$namespace'"
	helm uninstall flowable --namespace "$namespace" --ignore-not-found
	kubectl delete namespace "$namespace" --ignore-not-found
}

if [[ "$1" == "--all" ]]; then
	for namespace in dev test stg; do
		delete_namespace "$namespace"
	done
else
	delete_namespace "${1:-dev}"
fi

echo "Stopping shared Postgres + Elasticsearch containers"
docker-compose -f docker/docker-compose.yml down
