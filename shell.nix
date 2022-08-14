with (import <nixpkgs> {});
with python38Packages;

let
  inherit (pkgs.lib) optional optionals;

  my-python = pkgs.python38;
  my-poetry = pkgs.poetry.override { python = my-python; };
  my-app = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    python = my-python;

    editablePackageSources = {
      aspic = ./aspic;
    };
    
    preferWheels = true;
    extraPackages = ps: with ps; [
      pip
    ];

    #overrides = poetry2nix.overrides.withDefaults (
    #  self: super: {
    #    oscrypto = null;
    #  }
    #);
  };
in
pkgs.mkShell {

  LD_LIBRARY_PATH = lib.makeLibraryPath [
    stdenv.cc.cc
    openssl
  ];

  buildInputs = with pkgs; [
    kube3d kubectl openshift kubernetes-helm kuttl
    just jq hadolint my-poetry
    operator-sdk argocd
  ]
  ++
  (if builtins.pathExists ./poetry.lock then [ my-app ]
  else []);

  shellHook = with pkgs;
    if builtins.pathExists ./poetry.lock then ''
      echo "Yay poetry.lock exists. I'll honor it"
      echo "You have a perfectly usable environment now :)"
    ''
    else ''
      echo "Boo! You don't have a lock file - so I'll make it now"
      poetry lock || exit 1
      echo "Lockfile created. But this nix-shell is unusable; start it again. Exiting for now."
    ''
  ;
}