withKubenix: { inputs, kubenixPath, config, pkgs, lib, ... }: let
  crds = (inputs.kubenix.evalModules.aarch64-darwin {
    module = { kubenix, ... }: {
      imports = (withKubenix kubenix) ++ [kubenix.modules.k8s];
    };
  }).config.kubernetes.objects;

  crdsFromEvaluation =
    builtins.filter (o: o.kind == "CustomResourceDefinition") crds;

  schemasFlattened = let
    processCrdVersion = crd: version: {
      group = crd.spec.group;
      version = version.name;
      kind = crd.spec.names.kind;
      attrName = crd.spec.names.plural;
      fqdn = "${crd.spec.group}.${version.name}.${crd.spec.names.kind}";
      schema = version.schema.openAPIV3Schema;
    };
    processCrd = crd:
      builtins.map (v: processCrdVersion crd v) crd.spec.versions;
  in builtins.concatMap processCrd crdsFromEvaluation;

  allCrdsOpenApiDefinition = pkgs.writeTextFile {
    name = "generated-kubenix-crds-schema.json";
    text = builtins.toJSON {
      definitions = builtins.listToAttrs (builtins.map (x: {
        name = x.fqdn;
        value = x.schema;
      }) schemasFlattened);
      paths = { };
    };
  };

  generated = import "${kubenixPath}/jobs/generators/k8s" {
    name = "kubenix-generated-for-crds";
    inherit pkgs lib;
    spec = "${allCrdsOpenApiDefinition}";
  };

  definitions = (import "${generated}" {
    inherit config lib;
    options = null;
  }).config.definitions;
in {
  kubernetes.customTypes = builtins.map (crdVersion: {
    inherit (crdVersion) group version kind attrName;
    module = lib.types.submodule (definitions."${crdVersion.fqdn}");
  }) schemasFlattened;
}
