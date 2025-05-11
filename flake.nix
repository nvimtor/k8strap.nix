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

    kubenix = {
      url = "github:hall/kubenix";
    };

    nixhelm = {
      url = "github:farcaller/nixhelm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }: flake-parts.lib.mkFlake
    { inherit inputs; }
    ({ flake-parts-lib, ... }: let
      inherit (flake-parts-lib) importApply;

      module = importApply
        ./flake-module.nix
        { inherit (inputs) kubenix nixhelm; };
    in {
      imports = [
        ./internal
        module
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
        flakeModules.default = module;
        flakeModule = module;
      };
    });
}
