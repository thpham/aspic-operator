# shell.nix
with (import <nixpkgs> {});
let

  python-with-my-packages = python38.withPackages (ps: [
      ps.virtualenv
    ]);

  basePackages = [
    kube3d kubectl openshift kubernetes-helm kuttl
    just jq hadolint poetry python-with-my-packages
    operator-sdk
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
