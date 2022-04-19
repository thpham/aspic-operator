home_dir         := env_var('HOME')
operator_version := "latest"
operator_image   := "tpham/aspic-operator"+":"+operator_version

default:
  @just --list --unsorted

system-info:
  @echo "This is an {{arch()}} machine running on {{os()}}."

start: system-info create-k8s install-cluster-addons
  @echo "Middle steps..."
  just load-images remove-devs-additions helm-install

create-k8s:
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

create-microshift:
  #!/usr/bin/env bash
  docker pull quay.io/microshift/microshift-aio:latest
  docker run -d --rm --name microshift --privileged -p 6443:6443 -v microshift-data:/var/lib quay.io/microshift/microshift-aio:latest || true
  docker cp microshift:/var/lib/microshift/resources/kubeadmin/kubeconfig $HOME/.kube/config

install-cluster-addons:
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  helm upgrade --install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.7.2 \
  --set installCRDs=true

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
  helm -n aspic-operator upgrade --install --create-namespace -f helm/values.yaml --set image.tag=latest aspic-operator ./helm

helm-uninstall:
  helm -n aspic-operator delete aspic-operator

remove-devs-additions:
  #!/usr/bin/env bash
  kubectl delete -f helm//templates/crd-*.yaml || true
  kubectl delete MutatingWebhookConfiguration aspic-operator || true
  kubectl delete ValidatingWebhookConfiguration aspic-operator || true

deploy-example:
  kubectl apply -f examples/update-stream.yaml

delete-example:
  kubectl delete -f examples/update-stream.yaml

alias b := buildx
buildx:
  DOCKER_BUILDKIT=1 docker build -t {{operator_image}} .

destroy:
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

testing:
  {{justfile_directory()}}/scripts/testing.sh
