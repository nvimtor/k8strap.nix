{ lib, ... }: let
  inherit (lib.options) mkOption literalExpression;
  inherit (lib) types;

  litExpr = literalExpression;
in {
  options = {
    clusters = {
      description = "Kubernetes clusters";
      type = types.attrsOf (types.submodule ({ name, config, ... }: {
        options = {
          kubenix = mkOption {
            type = types.attrsOf {
              crds = mkOption {
                type = types.listOf (types.functionTo (types.deferredModule));
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
                type = types.listOf (types.functionTo (types.deferredModule));
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
            description = "Kubenix configuration for ${name}.";
          };
        };
      }));
      modules = mkOption {
        type = types.listOf types.deferredModule;
      };
    };
  };
  config = {

  };
}
