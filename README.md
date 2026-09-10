# flowable-deploy-template-local

This repository is #2 of 3 that is meant to serve as a "Best Practice Example" when it comes to Flowable DevOps. Below is the architecture and prescribed Git Branching strategy for the 3 repositories:

![Pipeline Diagram](assets/Pipeline.drawio.svg)

# Introduction

Zooming into the second portion of the diagram, we can focus on the purpose of this repository: Flowable deployments via Helm.

![Deploy Diagram](assets/deploy-pipeline.png)

This is a **local-hardware variant** of the original `flowable-deploy-template`: instead of two separate 3-node `kind` clusters running inside a GitHub Codespace (heavy enough to strain a Codespaces VM), everything here runs on a single 3-node `kind` cluster on your own machine (via Docker Desktop or any Docker engine `kind` supports). One cluster hosts all three demo environments as namespaces (`dev`, `test`, `stg`), and there's a single shared Traefik install instead of two duplicated ones.

## Prerequisites

- Docker (e.g. [Docker Desktop](https://www.docker.com/products/docker-desktop/)) and `kind` (`brew install kind` on macOS).
- `helm`, `kubectl`, `yq` (`brew install helm kubectl yq` on macOS).
- A Flowable Artifactory account (`FLOWABLE_REPO_USER` / `FLOWABLE_REPO_PASSWORD`) and a Flowable license file, needed to pull the Flowable Helm chart and images.
- Optional: [k9s](https://k9scli.io/) for browsing pods/logs (`brew install derailed/k9s/k9s`).

## Getting started

### Create Env

1) Clone this repo (with submodules) and enter it:
```
git clone --recurse-submodules <your-fork-url> flowable-deploy-template-local
cd flowable-deploy-template-local
```

2) Set the required environment variables in your shell (or let `create-env.sh` prompt you for them interactively the first time):
```
export FLOWABLE_REPO_USER=<your-flowable-artifactory-email>
export FLOWABLE_REPO_PASSWORD=<your-flowable-artifactory-password>
export FLOWABLE_LICENSE_KEY="$(cat /path/to/flowable.license)"
```

3) Run the create-env script:
```
./create-env.sh --all
```
This starts the shared Postgres + Elasticsearch containers via `docker-compose`, creates a single 3-node `kind` cluster named `local` (plus a local image registry and Traefik), and deploys Flowable into the `dev`, `test` and `stg` namespaces (dev: Work + Design + Control, test: Work + Control, stg: Work + Control with GitHub OAuth2 login). It takes a few minutes for everything to come up.

4) Observe with `k9s` (optional):
```
k9s
```
Since there's only one cluster now, `k9s` opens straight into the `kind-local` context (no cluster-picker step needed). Switch namespaces with `:ns` to watch `dev`/`test`/`stg` come up to `STATUS=Running`.

![alt text](assets/flowable-dev-boot.png)

### Access the deployment

The kind cluster's control-plane node maps host ports 80/443 straight through to the Traefik pod (via `kind-cluster-setup.sh`'s `extraPortMappings`), so `localhost` reaches it directly - no port-forwarding step needed:

- **dev**: [http://localhost/dev/work/](http://localhost/dev/work/), [http://localhost/dev/design/](http://localhost/dev/design/), [http://localhost/dev/control/](http://localhost/dev/control/)
- **test**: [http://localhost/test/work/](http://localhost/test/work/), [http://localhost/test/control/](http://localhost/test/control/)
- **stg**: [http://localhost/stg/work/](http://localhost/stg/work/), [http://localhost/stg/control/](http://localhost/stg/control/) (GitHub OAuth2 login - see below)

You should be greeted with a Flowable login page:

![alt text](assets/flowable-login.png)

Use `admin`/`test` for `dev` and `test`. `stg` uses GitHub OAuth2 instead of basic auth.

### stg's GitHub OAuth2 login (optional)

`stg` demonstrates logging in via a GitHub OAuth App instead of basic auth. To exercise it locally:
1. Create a GitHub OAuth App (Settings -> Developer settings -> OAuth Apps) with callback URLs `http://localhost/stg/work/login/oauth2/code/github` and `http://localhost/stg/control/login/oauth2/code/github`.
2. Export `OAUTH_CLIENT_ID` / `OAUTH_CLIENT_SECRET` before running `create-env.sh`, or `helm upgrade` the `stg` release afterwards with them set (they back the `oauth2-generic-config` ConfigMap consumed by `helm/templates/oauth2-configmap.yaml`).

### Optional: the CI/CD self-hosted-runner demo

The original Codespaces setup always installed `actions-runner-controller` (ARC) + `cert-manager` so a push to this repo would trigger an in-cluster Helm deploy via [.github/workflows/deploy-dev-qa.yml](.github/workflows/deploy-dev-qa.yml). Locally this is **opt-in**, since it adds real overhead (cert-manager + ARC controller + a runner pod) just to demo something a plain `./create-env.sh` already does:

```
DISABLE_ARC=false ./create-env.sh --all
```

You'll be prompted for a GitHub PAT (`ARC_TOKEN`) with permission to register a self-hosted runner on this repo. Verify it came up with `kubectl -n ci get pods` - you should see a `repo-runner-*` pod, and its logs should end with something like:
```
√ Connected to GitHub
Current runner version: '2.328.0'
Listening for Jobs
```

![alt text](assets/repo-runner.png)

### Tearing down

```
./delete-env.sh
```
This deletes the `local` kind cluster entirely and stops the shared Postgres/Elasticsearch containers.
