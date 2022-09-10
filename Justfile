home_dir         := env_var('HOME')
operator_version := "latest"
operator_image   := "tpham/aspic-operator"+":"+operator_version

default:
  @just --list --unsorted

system-info:
  @echo "This is an {{arch()}} machine running on {{os()}}."

start: system-info create-k8s
  @echo "Middle steps..."
  just load-images remove-devs-additions helm-install

create-k8s: create-regcache
  #!/usr/bin/env bash
  k3d version
  k3d cluster create aspic --config k3d-cluster.yaml --kubeconfig-update-default --kubeconfig-switch-context
  sleep 1
  echo "Waiting cluster beeing ready..."
  while [ $(kubectl get nodes -o json | jq -r '.items[].status.conditions[]? | select (.type == "Ready") | .status') != True ]
  do
    sleep 2
  done
  for node in $(kubectl get nodes -o name);
  do
    echo
    echo "     Node Name: ${node##*/}"
    echo "Type/Node Name: ${node}"
    echo  
  done
  just install-cluster-apps

create-regcache:
  #!/usr/bin/env bash
  mkdir -p ~/.local/share/registries
  k3d registry create docker-io \
    --proxy-remote-url https://registry-1.docker.io \
    -v ~/.local/share/registries/docker-io:/var/lib/registry || true
  k3d registry create ghcr-io \
    --proxy-remote-url https://ghcr.io \
    -v ~/.local/share/registries/ghcr-io:/var/lib/registry || true
  k3d registry create gcr-io \
    --proxy-remote-url https://gcr.io \
    -v ~/.local/share/registries/gcr-io:/var/lib/registry || true
  k3d registry create quay-io \
    --proxy-remote-url https://quay.io \
    -v ~/.local/share/registries/quay-io:/var/lib/registry || true
  k3d registry create k8s-io \
    --proxy-remote-url https://registry.k8s.io \
    -v ~/.local/share/registries/k8s-io:/var/lib/registry || true
  k3d registry create k8s-gcr-io \
    --proxy-remote-url https://k8s.gcr.io \
    -v ~/.local/share/registries/k8s-gcr-io:/var/lib/registry || true

delete-regcache:
  #!/usr/bin/env bash
  k3d registry del --all

create-microshift:
  #!/usr/bin/env bash
  docker pull quay.io/microshift/microshift-aio:latest
  docker run -d --rm --name microshift --privileged -p 6443:6443 -v microshift-data:/var/lib quay.io/microshift/microshift-aio:latest || true
  docker cp microshift:/var/lib/microshift/resources/kubeadmin/kubeconfig $HOME/.kube/config

install-cluster-apps:
  kubectl create ns argocd || true
  kubectl -n argocd apply -k bootstrap/apps/argocd || true
  kubectl -n argocd rollout status statefulset/argocd-application-controller
  kubectl -n argocd rollout status deployment/argocd-repo-server
  #kubectl -n argocd apply -f bootstrap/default.yaml
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

install-olm:
  operator-sdk olm install

install-olm-argocd:
  #!/usr/bin/env bash
  kubectl create -f olm/argocd/subscription.yaml || true
  kubectl -n operators get subscriptions
  while [[ -z $(kubectl -n operators wait deployment argocd-operator-controller-manager --for condition=Available=True --timeout=90s 2>/dev/null) ]]; do
    echo "still waiting for argocd-operator-controller-manager..."
    sleep 2
  done
  kubectl create namespace argocd || true
  kubectl create -f olm/argocd/argocd.yaml || true
  while [[ -z $(kubectl -n argocd wait deployment argocd-server --for condition=Available=True --timeout=90s 2>/dev/null) ]]; do
    echo "still waiting for argocd-server..."
    sleep 2
  done
  kubectl -n operators get csv

install-olm-hive:
  #!/usr/bin/env bash
  kubectl create -f olm/hive/subscription.yaml || true
  kubectl -n operators get subscriptions
  while [[ -z $(kubectl -n operators wait deployment hive-operator --for condition=Available=True --timeout=90s 2>/dev/null) ]]; do
    echo "still waiting for hive-operator..."
    sleep 2
  done
  kubectl create namespace hive || true
  kubectl create -f olm/hive/hive_config.yaml || true
  while [[ -z $(kubectl -n hive wait deployment hive-controllers --for condition=Available=True --timeout=90s 2>/dev/null) ]]; do
    echo "still waiting for hive-controllers..."
    sleep 2
  done
  kubectl -n operators get csv

install-olm-ocm:
  #!/usr/bin/env bash
  kubectl create -f olm/ocm/subscription.yaml || true
  kubectl -n operators get subscriptions
  while [[ -z $(kubectl -n operators wait deployment cluster-manager --for condition=Available=True --timeout=90s 2>/dev/null) ]]; do
    echo "still waiting for cluster-manager..."
    sleep 2
  done
  kubectl create namespace open-cluster-management-hub || true
  kubectl create -f olm/ocm/cluster_manager.yaml || true
  while [[ -z $(kubectl -n open-cluster-management-hub wait deployment cluster-manager-registration-controller --for condition=Available=True --timeout=90s 2>/dev/null) ]]; do
    echo "still waiting for cluster-manager-registration-controller..."
    sleep 2
  done
  kubectl -n operators get csv

install-crds:
  kubectl apply -f helm//templates/crd-*.yaml

libs-install:
  poetry install

libs-update:
  poetry update

alias r := run
run: install-crds
  #!/usr/bin/env bash
  kubectl create ns aspic-operator
  export ASPIC_OPERATOR_WATCH_NAMESPACES=default,aspic-operator
  PROFILE=dev python aspic/main.py operator --api

load-images: buildx
  #!/usr/bin/env bash
  k3d image import {{operator_image}} --cluster aspic

# install local helm chart with latest image built locally
helm-install:
  helm -n aspic-operator upgrade --install --create-namespace \
    -f helm/values.yaml \
    --set image.tag=latest \
    --set api.enabled=True \
    --set ingress.enabled=True \
    --set ingress.hosts[0].host=aspic-operator.127.0.0.1.nip.io \
    aspic-operator ./helm

helm-uninstall:
  helm -n aspic-operator delete aspic-operator

remove-devs-additions:
  #!/usr/bin/env bash
  kubectl delete -f helm/templates/crd-*.yaml || true
  kubectl delete MutatingWebhookConfiguration aspic-operator || true
  kubectl delete ValidatingWebhookConfiguration aspic-operator || true

deploy-example:
  kubectl apply -f examples/update-stream.yaml

delete-example:
  kubectl delete -f examples/update-stream.yaml

alias b := buildx
buildx:
  DOCKER_BUILDKIT=1 docker build -t {{operator_image}} .

destroy: delete-regcache
  #!/usr/bin/env bash
  kubectl -n argocd delete -f bootstrap/default.yaml
  sleep 5
  k3d cluster delete aspic

e2e:
  #!/usr/bin/env bash
  echo "current-context:" $(kubectl config current-context)
  kubectl cluster-info
  count=0
  while [[ $(kubectl -n aspic-operator get pods -l 'app.kubernetes.io/name'=aspic-operator -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    echo "Waiting for aspic-operator pod ready..." && sleep 1;
    ((count++))
    if [[ "$count" == '30' ]]; then
      echo "Timeout... "
      echo "Get logs:"
      kubectl logs -n aspic-operator deploy/aspic-operator --all-containers=true --timestamps --tail=-1
      exit 1
    fi
  done
  echo
  echo "TODO python E2E test"
  # Example to call aspic-operator API
  curl http://aspic-operator.127.0.0.1.nip.io/health

testing:
  {{justfile_directory()}}/scripts/testing.sh
