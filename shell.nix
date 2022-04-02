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
    VIRTUALENVS="$HOME/.virtualenvs"
    mkdir -p $VIRTUALENVS
    virtualenv -p $(which python) .venv
    source .venv/bin/activate

    just libs-install
  '';

in mkShell {
  buildInputs = inputs;
  shellHook = shellHooks;
}
