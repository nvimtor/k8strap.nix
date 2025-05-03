{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    terranix = {
      url = "github:terranix/terranix";
    };
  };

  outputs = inputs@{ flake-parts, nixpkgs, self, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
      ./internal
      ./flake-module.nix
    ];

    systems = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-linux"
      "aarch64-darwin"
    ];

    perSystem = { lib, config, system, ... }: let
      overlays = [];

      pkgs = import nixpkgs {
        inherit system overlays;
      };
    in {
      _module.args.pkgs = pkgs;
    };

    flake = {
      flakeModule = ./flake-module.nix;
      flakeModules.default = ./flake-module.nix;
    };
  };
}
