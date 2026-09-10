#!/bin/bash
set -o errexit

# Deploys the Flowable Platform locally on a single kind cluster.
# Usage:
#   ./create-env.sh --all          # deploy dev, test and stg into the local kind cluster
#   ./create-env.sh <namespace>    # deploy a single namespace (dev|test|stg)

CLUSTER_NAME="${CLUSTER_NAME:-local}"
DISABLE_ARC="${DISABLE_ARC:-true}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Rewriting env-specific values for local access"
for ns in dev test stg; do
	yq -i ".flowable.ingress.host = \"http://localhost/${ns}\"" "helm/${ns}/values.yaml"
done
yq -i '.flowable.work.envVariables."spring.security.oauth2.client.registration.github.redirect-uri" = "http://localhost/stg/work/login/oauth2/code/github"' helm/stg/values.yaml
yq -i '.flowable.work.envVariables."flowable.security.oauth2.post-logout-redirect-url" = "http://localhost/stg/work/#/"' helm/stg/values.yaml
yq -i '.flowable.control.envVariables."spring.security.oauth2.client.registration.github.redirect-uri" = "http://localhost/stg/control/login/oauth2/code/github"' helm/stg/values.yaml
yq -i '.flowable.control.envVariables."flowable.security.oauth2.post-logout-redirect-url" = "http://localhost/stg/control/#/"' helm/stg/values.yaml

if [ -n "$GITHUB_USER" ]; then
	yq -i ".flowable.design.envVariables.\"flowable.design.git.repo.uri\" = \"git@github.com:${GITHUB_USER}/flowable-models-repo.git\"" helm/dev/values.yaml
fi

if [ ! -d "docker/.ssh" ]; then
	echo "Setting up SSH keys for flowable-design's git repo access (reusing your own key, read-only mount)"
	mkdir -p docker/.ssh
	for key in id_ed25519 id_rsa; do
		[ -f "$HOME/.ssh/${key}" ] && cp "$HOME/.ssh/${key}" "$HOME/.ssh/${key}.pub" docker/.ssh/ 2>/dev/null || true
	done
	ssh-keyscan -t rsa,ed25519 github.com >> docker/.ssh/known_hosts 2>/dev/null
fi

echo "Starting shared Postgres + Elasticsearch containers"
docker-compose -f docker/docker-compose.yml up -d

echo "Setting up the local kind cluster"
export EXTRA_MOUNT_HOST_PATH="${REPO_DIR}/docker"
"$REPO_DIR/scripts/kind-cluster-setup.sh" "$CLUSTER_NAME" "$DISABLE_ARC"

echo "Connecting the shared Postgres/Elasticsearch containers to the kind network"
for container in docker-flowable-db-1 docker-flowable-index-1; do
	if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "$container" 2>/dev/null)" = 'null' ]; then
		docker network connect "kind" "$container"
	fi
done

kubectl config use-context "kind-${CLUSTER_NAME}"

deploy_flowable() {
	local namespace="$1"
	local release_name="$2"
	echo "Deploying Flowable Platform in namespace '$namespace' with release name '$release_name'"
	"$REPO_DIR/scripts/deploy-flowable-platform.sh" "$namespace" "$release_name"
}

if [[ "$1" == "--all" ]]; then
	for namespace in dev test stg; do
		deploy_flowable "$namespace" "flowable"
	done
else
	NAMESPACE="${1:-dev}"
	RELEASE_NAME="${2:-flowable}"
	deploy_flowable "$NAMESPACE" "$RELEASE_NAME"
fi

echo
echo "Flowable URLs (once all pods are Running):"
echo "  dev  - Work: http://localhost/dev/work/   Design: http://localhost/dev/design/   Control: http://localhost/dev/control/"
echo "  test - Work: http://localhost/test/work/  Control: http://localhost/test/control/"
echo "  stg  - Work: http://localhost/stg/work/   Control: http://localhost/stg/control/  (GitHub OAuth2 login)"
