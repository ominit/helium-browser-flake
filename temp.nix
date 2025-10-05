{inputs, ...}: {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: let
    helium = pkgs.callPackage ./default.nix {};
  in {
    packages = {
      inherit helium;

      default = helium;
    };
  };
}
