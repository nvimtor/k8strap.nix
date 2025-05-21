{ kubenix, nixhelm, nix-kube-generators, kubectl-slice-git, ... }:
{ root, inputs, lib, config, moduleWithSystem, ... }: let
  inherit (lib.attrsets) foldlAttrs mapAttrs' attrValues mapAttrsToList concatMapAttrs;
  inherit (lib.options) mkOption literalExpression;
  inherit (lib.lists) concatMap;
  inherit (lib) types mapAttrs genAttrs mkMerge pipe getExe;

  litExpr = literalExpression;
  cfg = config.k8strap;
in {
  options = {
    k8strap = {
      clusters = mkOption {
        description = "Kubernetes clusters";
        default = {};
        type = types.attrsOf (types.submodule ({ name, config, ... }: let
          cluster-name = name;
        in {
          options = {
            apps = mkOption {
              type = types.attrsOf (types.submodule ({ name, config, ... }: {
                options = {
                  crds = mkOption {
                    type = types.listOf types.anything;
                    description = ''
                      Custom Resource Definitions (CRDs) to use for ${cluster-name} and app ${name}.
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
                    description = "Kubenix modules to use for ${cluster-name} and app ${name}";
                    example = litExpr ''
                    { kubenix }: { inputs, ... }: {
                      imports = with kubenix.modules; [
                        k8s
                      ];

                      kubernetes.resources.namespaces.argocd = { };
                    }
                    '';
                  };
                };
              }));
            };

            specialArgs = mkOption {
              type = types.lazyAttrsOf types.raw;
              default = {};
              description = "${cluster-name}'s special arguments to be passed to all Kubenix modules.";
              example = literalExpression ''
                { foo = "bar"; }
              '';
            };

            template = mkOption {
              type = types.str;
              default = ''
                {{- $dir := (.metadata.namespace | default "_") -}}
                {{- $app := indexOrEmpty "kubenix/project-name" .metadata.annotations | default "" -}}
                {{- if $app -}}
                  {{- $dir = printf "%s" $app -}}
                {{- end -}}
                {{ printf "%s/%s-%s.yaml" $dir .kind .metadata.name }}
              '';
              description = ''
                By default, Kubenix generates a single file containing all resources.
                This option lets you break it up using kubectl-slice.
              '';
            };

            k3sHosts = mkOption {
              description = "Apply k3s.";
              type = types.attrsOf (types.submodule ({ name, config, ... }: {
                options = {
                  manifestsDir = mkOption {
                    type = types.str;
                    description = "Where k3s stores its manifests file for ${name}.";
                    default = "/var/lib/rancher/k3s/server/manifests";
                  };
                };
              }));
              default = {};
            };
            description = "Kubenix configuration for ${name}.";
          };
        }));
      };

      outputDir = mkOption {
        type        = types.str;
        default     = "outputs";
        description = "Where rendered manifests for clusters are stored. ";
      };
    };
  };
  config = {
    perSystem = { pkgs, system, lib, ... }: let
      inherit (lib.modules) importApply;
      inherit (pkgs) writeShellApplication buildGo124Module fetchFromGitHub;
      inherit (pkgs.stdenv) mkDerivation;

      kubectl-slice = buildGo124Module rec {
        name = "kubectl-slice";
        pname = "kubectl-slice";
        src = kubectl-slice-git;
        vendorHash = "sha256-eJTD93hO917x4fPxqT71geifkzwHFo57r/Q0GjuOcvQ=";
      };

      clusterPkgs =
        mapAttrs (cname: cluster: let
          charts = nixhelm.chartsDerivations.${system};

          mkManifestFor = app: (kubenix.evalModules.${system} {
            module = { kubenix, ... }: let
              kubelib = nix-kube-generators.lib { inherit pkgs; };

              kubenixProject = {
                kubenix.project = app.name;
              };

              data = {
                inherit kubenix charts kubelib;
              };

              callWithKubenix = m: importApply m data;

              crds = importApply ./kubenix/crd.nix
                (kubenix: map (m: importApply m data) app.crds);
            in {
              imports = [
                crds
                kubenixProject
              ] ++ (map callWithKubenix app.modules);
            };
            specialArgs = {
              inherit inputs;
              inputs' = inputs;
              kubenixPath = "${kubenix}";
            } // cluster.specialArgs;
          });

          sliceTpl = pkgs.writeText "slice.tpl" cluster.template;

          manifests = pkgs.linkFarm
            "k8strap-manifests"
            (mapAttrsToList (name: app: {
              name = "${name}.yaml";
              path = (mkManifestFor (app // { inherit name; })).config.kubernetes.resultYAML;
            }) cluster.apps);
        in mkDerivation {
          name = "${cname}-manifests";
          buildCommand = ''
            mkdir -p $out/${cname}
            ${kubectl-slice}/bin/kubectl-slice \
            -d ${manifests} \
            -r \
            -o $out/${cname}/ \
            -t "$(cat ${sliceTpl})"
          '';
        }) cfg.clusters;
    in {
      packages = clusterPkgs;
      apps = mapAttrs (cname: drv: {
        type = "app";
        program = writeShellApplication {
          name = "copy-${cname}";
          runtimeInputs = [ pkgs.rsync ];
          text = ''
            set -euo pipefail
            dest="$PWD/${cfg.outputDir}/${cname}"
            mkdir -p "$dest"
            rsync --recursive --delete -L --checksum "${drv}/${cname}/" "$dest/"
            echo "Copied → $dest"
          '';
        };
      }) clusterPkgs;
    };

    flake = {
      nixosModules = let
        readManifests = cname: let
        in builtins.path {
          path = (root + /${cfg.outputDir}/${cname});
        };

        mkModule = { cname, manifestsDir }: { pkgs, self, ... }: let
        in {
          system.activationScripts.kapp-deploy.text = ''
            KUBECONFIG=/etc/rancher/k3s/k3s.yaml \
            ${getExe pkgs.kapp} app-group deploy \
            -y \
            -g apps \
            --directory ${root + /${cfg.outputDir}/${cname}}
          '';
        };
      in
        mkMerge (mapAttrsToList
          (cname: cval: mapAttrs' (host: hostcfg: {
            name = "k8strap-${host}";
            value = mkModule {
              inherit cname;
              inherit (hostcfg) manifestsDir;
            };
          }) cval.k3sHosts)
          cfg.clusters);
    };
  };
}
