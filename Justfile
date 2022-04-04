home_dir         := env_var('HOME')
operator_version := "latest"
operator_image   := "tpham/aspic-operator"+":"+operator_version

default:
  @just --list --unsorted

system-info:
  @echo "This is an {{arch()}} machine running on {{os()}}."

start: system-info create-k8s
  @echo "Middle steps..."
  just load-images helm-install

create-k8s:
  #!/usr/bin/env bash
  kind create cluster --name aspic --config kind-cluster.yaml
  sleep 1
  kubectl cluster-info --context kind-aspic
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

install-crds:
  kubectl apply -f helm//templates/crd-*.yaml

libs-install:
  poetry install

libs-update:
  poetry update

alias r := run
run:
  python aspic/main.py service --k8s

load-images: buildx
  #!/usr/bin/env bash
  kind --name aspic load docker-image {{operator_image}}

helm-install:
  helm -n aspic-operator upgrade --install --create-namespace -f helm/values.yaml aspic-operator ./helm

helm-uninstall:
  helm -n aspic-operator delete aspic-operator

deploy-example:
  kubectl apply -f examples/update-stream.yaml

delete-example:
  kubectl delete -f examples/update-stream.yaml

alias b := buildx
buildx:
  DOCKER_BUILDKIT=1 docker build -t {{operator_image}} .

destroy:
  kind delete cluster --name aspic

e2e:
  #!/usr/bin/env bash
  echo "current-context:" $(kubectl config current-context)
  kubectl cluster-info
  count=0
  while [[ $(kubectl -n aspic-operator get pods -l 'app.kubernetes.io/name'=aspic-operator -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    echo "Waiting for aspic-operator pod ready..." && sleep 1;
    ((count++))
    if [[ "$count" == '5' ]]; then
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
