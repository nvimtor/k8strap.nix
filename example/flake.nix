{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };

    k8strap = {
      url = "github:nvimtor/k8strap.nix";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
  };

  outputs = inputs@{ flake-parts, nixpkgs, self, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
      inputs.k8strap.flakeModule
    ];

    systems = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-linux"
      "aarch64-darwin"
    ];

    flake = {
      nixosConfigurations = {
        test = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            inputs.k8strap.nixosModules.k8strap
          ];
        };
      };
    };
  };
}
