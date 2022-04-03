# shell.nix
with (import <nixpkgs> {});
let

  python-with-my-packages = python39.withPackages (ps: [
      ps.virtualenv
    ]);

  basePackages = [
    kind openshift kubernetes-helm 
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
