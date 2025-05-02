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
    in {
      packages = mapAttrs (cname: cluster: let
        manifests = (inputs.kubenix.evalModules.${system} {
          module = { kubenix, ... }: let
            callWithKubenix = m: importApply m { inherit kubenix; };

            crds = importApply
              ./kubenix/crd.nix
              (kubenix: map callWithKubenix cluster.kubenix.crds);
          in {
            imports = (map callWithKubenix cluster.kubenix.modules) ++ [crds];
          };
          specialArgs = cluster.kubenix.specialArgs // {
            inherit inputs;
            kubenixPath = "${inputs.kubenix}";
          };
        }).config.kubernetes.resultYAML;
      in pkgs.stdenv.mkDerivation {
        name = "${cname}-manifests";
        buildCommand = ''
          mkdir -p $out/${cname}
          cp ${manifests} $out/${cname}/manifest.yaml
        '';
      }) cfg.clusters;
    };

    flake = {
      nixosModules.k8strap = moduleWithSystem (
        perSystem@{ config }:
        nixos@{ ... }: let
        in {

        }
      );
    };
  };
}

/*

{
        clusterName,
        manifestsDir ? "/var/lib/rancher/k3s/server/manifests"
      }: { lib, pkgs, ... }: let
        pkgName      = "${clusterName}-manifests";
        manifestPkg  = inputs.self.packages.${pkgs.stdenv.system}.${pkgName};
        manifestFile = "${manifestPkg}/${clusterName}/manifest.yaml";
      in
        {
          config.environment.etc."k8strap/${clusterName}.yaml".source = manifestFile;

          config.system.activationScripts.k8strap-link.text = ''
            install -d -m0755 ${lib.escapeShellArg manifestsDir}
            ln -sf /etc/k8strap/${clusterName}.yaml \
              ${lib.escapeShellArg manifestsDir}/${clusterName}.yaml
          '';
        };

*/
