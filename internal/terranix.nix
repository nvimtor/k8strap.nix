{ inputs, ... }: {
  imports = [
    inputs.terranix.flakeModule
  ];

  perSystem = { system, lib, pkgs, ... }: let
    inherit (builtins) elem;
    inherit (lib) getExe getName;
    inherit (inputs.terranix.lib) terranixConfiguration;

    pkgs' = import inputs.nixpkgs {
      inherit system;
      config = {
        allowUnfreePredicate = pkg: elem (getName pkg) [
          "terraform"
        ];
      };
    };
  in {
    terranix = {
      terranixConfigurations = {
        github = {
          modules = [
            ./github.nix
          ];

          terraformWrapper.package = pkgs'.terraform.withPlugins (ps: with ps; [
            sops
            github
          ]);

          workdir = ".";
        };
      };
    };
  };
}
