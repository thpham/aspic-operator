# Aspic Operator

Aspic is an update protocol designed to facilitate automatic updates. It describes a particular method for representing transitions between releases of a project and allowing a client to perform automatic updates between these releases.

This operator helps you declare projects and their install/update channel. It also acts as API endpoints which you can use with your CI to continuously update informations about new release version of your projects and their components.


_This project is at an alpha (PoC) phase, which I work on my spare time to discover and experiment the various technologies & languages_

## Todo

- github workflow to create the docker image
- helm chart
- github workflow to publish the site that host the helm charts releases
- code the operator ;-)
- provide examples and deploy a live demo somewhere


## Development

Requirements:

- [Just](https://github.com/casey/just)
- docker + [Kind](https://github.com/kubernetes-sigs/kind)
- Python3 + [Poetry](https://python-poetry.org/)
- (optional) nix package manager if you want to use `shell.nix`

Start coding:

```
just create-k8s
just install-crds
mkvirtualenv aspic
just setup
just run
just deploy-example

just delete-example
just buildx
just delete-k8s
```

## Installation

```
helm repo add aspic-operator https://thpham.github.io/aspic-operator
helm upgrade --install --create-namespace -f helm/values.yaml aspic aspic-operator
```
