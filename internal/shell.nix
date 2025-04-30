{
  perSystem = { pkgs, ... }: {
    devShells = {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          git-crypt
        ];
      };
    };
  };
}
