# shell.nix

## To PIN dependencies in time
#with (import (builtins.fetchGit {
  # Descriptive name to make the store path easier to identify
#  name = "nixos-unstable-2022-04-26";
#  url = "https://github.com/nixos/nixpkgs/";
  # Commit hash for nixos-unstable as of 2022-04-26
  # `git ls-remote https://github.com/nixos/nixpkgs nixos-unstable`
#  ref = "refs/heads/nixos-unstable";
#  rev = "6a323903ad07de6680169bb0423c5cea9db41d82";
#}) {});

with (import <nixpkgs> {});

let

  python-with-my-packages = python38.withPackages (ps: [
      ps.virtualenv
    ]);

  basePackages = [
    kube3d kubectl openshift kubernetes-helm kuttl
    just jq hadolint poetry python-with-my-packages
  ];

  inputs = basePackages;

  shellHooks = ''
    virtualenv -p $(which python) .venv
    source .venv/bin/activate
  '';

in mkShell {
  buildInputs = inputs;
  shellHook = shellHooks;
}
