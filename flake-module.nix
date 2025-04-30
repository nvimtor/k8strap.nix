{ lib, ... }: let
  inherit (lib.options) mkOption;
  inherit (lib) types;
in {
  options = {
    clusters = {
      modules = mkOption {
        type = types.listOf types.deferredModule;
      };
    };
  };
}
