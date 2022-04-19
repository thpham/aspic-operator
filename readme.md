# Aspic Operator

Aspic is an update protocol designed to facilitate automatic updates. It describes a particular method for representing transitions between releases of a project and allowing a client to perform automatic updates between these releases.

This operator helps you declare projects and their install/update channel. It also acts as API endpoints which you can use with your CI to continuously update informations about new release version of your projects and their components.


> :warning: **This project is still in an early phase. Use it on your own risk but make sure to create issues for issues you encounter.**

## Todo

- ~~github workflow to create the docker image~~
- ~~helm chart~~
- ~~development automations (Justfile, kind, ...)~~
- ~~github workflow to publish the site that host the helm charts releases~~
- code the operator ;-)
- provide examples and deploy a live demo somewhere


## Development

Requirements:

- [Just](https://github.com/casey/just)
- docker + [Kind](https://github.com/kubernetes-sigs/kind)
- Python3 + [Poetry](https://python-poetry.org/)
- ...

Or simply use [Nix package manager](https://nixos.org/download.html#download-nix):

- type: `nix-shell` , and you get EVRYTHNG !

Discover:

```
just start
just deploy-example
```

Start coding:

```
just create-k8s
just install-crds

just libs-install
just run
just deploy-example

just delete-example
just buildx
just destroy
```

## Installation

```
helm repo add aspic-operator https://thpham.github.io/aspic-operator/helm
helm -n aspic-operator upgrade --install --create-namespace -f <your_values.yaml> aspic-opertor aspic-operator
```

The docker image produce by the CI/CD is published on [Docker Hub](https://hub.docker.com/r/tpham/aspic-operator/tags).
