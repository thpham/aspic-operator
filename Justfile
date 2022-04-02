set shell := ["zsh", "-cu"]

default:
  @just --list --unsorted

create-k8s:
  kind create cluster --name aspic --config kind-cluster.yaml

install-crds:
  kubectl apply -f helm//templates/crd-*.yaml

setup:
  poetry install

alias r := run
run:
  kopf run --all-namespaces aspic/main.py --verbose

deploy-example:
  kubectl apply -f examples/simple-project.yaml

delete-example:
  kubectl delete -f examples/simple-project.yaml

alias b := buildx
buildx:
  DOCKER_BUILDKIT=1 docker build -t tpham/aspic-operator:latest .

delete-k8s:
  kind delete cluster --name aspic
