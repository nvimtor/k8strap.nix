{ inputs, lib, config, moduleWithSystem, ... }: let
  inherit (lib.attrsets) foldlAttrs;
  inherit (lib.options) mkOption literalExpression;
  inherit (lib.lists) concatMap;
  inherit (lib) types mapAttrs genAttrs mkMerge;

  litExpr = literalExpression;
  cfg = config.k8strap;
in {
  options = {
    k8strap = {
      clusters = mkOption {
        description = "Kubernetes clusters";
        default = {};
        type = types.attrsOf (types.submodule ({ name, config, ... }: {
          options = {
            kubenix = mkOption {
              type = types.submodule {
                options = {
                  crds = mkOption {
                    type = types.listOf types.anything;
                    description = ''Custom Resource Definitions (CRDs) to use for ${name}.
                These will populate `kubenix.customTypes`.
                    '';
                    example = litExpr ''
                      { kubenix }: { inputs, ... }: {
                    imports = with kubenix.modules; [
                      helm
                    ];

                    kubernetes.helm.releases.traefik = {
                      namespace = "argocd";
                      chart = kubenix.lib.helm.fetch {
                      repo = "https://traefik.github.io/charts";
                      chart   = "traefik-crds";
                      version = "1.7.0";
                      sha256 = "15ck4dljk2vv3k35cqbhximq3rh5kj83z3g3mmxq32m9laszmxq6";
                      };
                    };
                  }
                    '';
                    default = [];
                  };
                  modules = mkOption {
                    type = types.listOf types.anything;
                    default = [];
                    description = "Kubenix modules to use for ${name}";
                    example = litExpr ''
                      { kubenix }: { inputs, ... }: {
                    imports = with kubenix.modules; [
                       k8s
                    ];

                    kubernetes.resources.namespaces.argocd = { };
                  }
                    '';
                  };
                  specialArgs = mkOption {
                    type = types.lazyAttrsOf types.raw;
                    default = {};
                    description = "${name}'s special arguments to be passed to Kubenix modules.";
                    example = literalExpression ''
                      { foo = "bar"; }
                    '';
                  };
                };
              };
              description = "Kubenix configuration for ${name}.";
            };

            k3sHosts = mkOption {
              description = "Apply k3s.";
              type = types.listOf types.str;
              default = [];
            };
          };
        }));
      };
    };
  };
  config = {
    perSystem = { pkgs, system, lib, ... }: let
      inherit (lib.modules) importApply;
      inherit (pkgs) writeShellApplication;
      inherit (pkgs.stdenv) mkDerivation;

      clusterPkgs =
        mapAttrs (cname: cluster: let
          manifests =
            (inputs.kubenix.evalModules.${system} {
              module = { kubenix, ... }: let
                callWithKubenix = m: importApply m { inherit kubenix; };
                crds = importApply ./kubenix/crd.nix
                  (kubenix: map callWithKubenix cluster.kubenix.crds);
              in {
                imports = [ crds ] ++ (map callWithKubenix cluster.kubenix.modules);
              };
              specialArgs = {
                inherit inputs;
                kubenixPath = "${inputs.kubenix}";
              } // cluster.kubenix.specialArgs;
            }).config.kubernetes.resultYAML;
        in mkDerivation {
          name = "${cname}-manifests";
          buildCommand = ''
            mkdir -p $out/${cname}
            cp ${manifests} $out/${cname}/manifest.yaml
          '';
        }) cfg.clusters;
    in {
      packages = clusterPkgs;
      apps = mapAttrs (cname: drv: {
        type = "app";
        program = (writeShellApplication {
          name = "copy-${cname}";
          runtimeInputs = [ pkgs.rsync ];
          text = ''
            set -euo pipefail
            dest="$PWD/manifests/${cname}"
            mkdir -p "$dest"
            rsync -aL --delete "${drv}/${cname}/" "$dest/"
            echo "Copied → $dest"
          '';
        });
      }) clusterPkgs;
    };

    flake = {
      nixosModules.default = "abc";
      # nixosModules.default = ({ ... }: {
      #   services.openssh.enable = true;
      # });
      # nixosModules.k8strap = moduleWithSystem (
      #   perSystem@{ config }:
      #   nixos@{ ... }: let
      #   in {
      #     services.openssh.enable = true;
      #   }
      # );
    };
  };
}
