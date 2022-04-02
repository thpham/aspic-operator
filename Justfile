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
  python aspic/main.py service --k8s

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
  DOCKER_BUILDKIT=1 docker build -t tpham/aspic-operator:latest .

delete-k8s:
  kind delete cluster --name aspic
