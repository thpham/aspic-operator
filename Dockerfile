FROM python:3.9-slim as base-all
LABEL maintainer "info@aspic.io"

# add user
RUN useradd -m -s /bin/bash aspic && \
    echo "aspic ALL=(ALL:ALL) NOPASSWD: ALL" >>/etc/sudoers

RUN --mount=type=cache,target=/var/lib/apt/lists \
    --mount=type=cache,target=/var/cache,sharing=locked \
    apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes --no-install-recommends \
        python3-pip python3-wheel

# Used to convert the locked packages by poetry to pip requirements format
FROM base-all as poetry

# Install poetry
WORKDIR /tmp
COPY requirements.txt ./
RUN --mount=type=cache,target=/root/.cache \
    python3 -m pip install --disable-pip-version-check --requirement=requirements.txt \
    && rm requirements.txt

# Do the conversion
COPY poetry.lock pyproject.toml ./
RUN poetry export --without-hashes --output=requirements.txt \
    && poetry export --without-hashes --dev --output=requirements-dev.txt

# Do the lint, used by the tests
FROM base-all as test

RUN --mount=type=cache,target=/root/.cache \
    --mount=type=bind,from=poetry,source=/tmp,target=/poetry \
    python3 -m pip install --disable-pip-version-check --requirement=/poetry/requirements-dev.txt

WORKDIR /app
COPY * ./

# The image used to run the application
FROM base-all as runtime

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    ca-certificates \
    git bash curl jq pip wget && \
    rm -rf /var/lib/apt/lists/*

ARG HELM_VERSION="v3.8.1"
ARG HELM_LOCATION="https://get.helm.sh"
ARG HELM_FILENAME="helm-${HELM_VERSION}-linux-amd64.tar.gz"
ARG HELM_SHA256="d643f48fe28eeb47ff68a1a7a26fc5142f348d02c8bc38d699674016716f61cd"
RUN set -x && \
    curl --retry 5 --retry-connrefused -LO ${HELM_LOCATION}/${HELM_FILENAME} && \
    echo Verifying ${HELM_FILENAME}... && \
    sha256sum ${HELM_FILENAME} | grep -q "${HELM_SHA256}" && \
    echo Extracting ${HELM_FILENAME}... && \
    tar zxvf ${HELM_FILENAME} && mv /linux-amd64/helm /usr/local/bin/ && \
    rm ${HELM_FILENAME} && rm -r /linux-amd64

# using the install documentation found at https://kubernetes.io/docs/tasks/tools/install-kubectl/
# the sha256 sum can be found at https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256
# maybe a good idea to automate in the future?
ENV KUBECTL_VERSION="v1.23.5"
ENV KUBECTL_SHA256="715da05c56aa4f8df09cb1f9d96a2aa2c33a1232f6fd195e3ffce6e98a50a879"
RUN set -x && \
    curl --retry 5 --retry-connrefused -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    sha256sum kubectl | grep ${KUBECTL_SHA256} && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/kubectl

ENV KUSTOMIZE_VERSION="v4.5.3"
ENV KUSTOMIZE_SHA256="e4dc2f795235b03a2e6b12c3863c44abe81338c5c0054b29baf27dcc734ae693"
RUN set -x && \
    curl --retry 5 --retry-connrefused -LO https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
    sha256sum kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz | grep ${KUSTOMIZE_SHA256} && \
    tar zxf kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
    rm kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
    mv kustomize /usr/local/bin/kustomize

ENV HELMFILE_VERSION="v0.144.0"
ENV HELMFILE_SHA256="dcf865a715028d3a61e2fec09f2a0beaeb7ff10cde32e096bf94aeb9a6eb4f02"
RUN set -x && \
    curl --retry 5 --retry-connrefused -LO https://github.com/roboll/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_linux_amd64 && \
    sha256sum helmfile_linux_amd64 | grep ${HELMFILE_SHA256} && \
    chmod +x helmfile_linux_amd64 && \
    mv helmfile_linux_amd64 /usr/local/bin/helmfile

RUN python3 -m pip install sops

USER aspic
RUN helm plugin install https://github.com/databus23/helm-diff --version v3.4.2 && \
    helm plugin install https://github.com/jkroepke/helm-secrets --version v3.12.0 && \
    helm plugin install https://github.com/hypnoglow/helm-s3.git --version v0.10.0 && \
    helm plugin install https://github.com/aslafy-z/helm-git.git --version v0.11.1

USER root
RUN --mount=type=cache,target=/root/.cache \
    --mount=type=bind,from=poetry,source=/tmp,target=/poetry \
    python3 -m pip install --disable-pip-version-check --requirement=/poetry/requirements.txt

WORKDIR /home/aspic/aspic-operator
USER aspic
COPY --chown=aspic:aspic aspic/ .
CMD ["python", "main.py", "operator"]