{inputs, ...}: {
  imports = [inputs.treefmt-nix.flakeModule];
  perSystem = {...}: {
    treefmt = {
      projectRootFile = "flake.nix";

      programs.alejandra.enable = true;
      programs.nixf-diagnose.enable = true;
      programs.deadnix.enable = true;
      programs.yamlfmt.enable = true;
      programs.beautysh.enable = true;
    };
  };
}
