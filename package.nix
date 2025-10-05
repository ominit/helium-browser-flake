{...}: {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: let
    pname = "helium";
    version = "0.5.2.1";

    architectures = {
      "x86_64-linux" = {
        arch = "x86_64";
        hash = "sha256-3h0GMMl58NX+PuZRwmksOvlwPuZZwiQJdM5YXkaxlDk=";
      };
      # "aarch64-linux" = {
      #   arch = "arm64";
      #   hash = "sha256-";
      # };
    };

    src = let
      inherit (architectures.${system}) arch hash;
    in
      pkgs.fetchurl {
        url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-${arch}.AppImage";
        inherit hash;
      };

    helium = pkgs.appimageTools.wrapType2 {
      inherit pname version src;

      nativeBuildInputs = [pkgs.copyDesktopItems];
      desktopItems = [
        (pkgs.makeDesktopItem {
          })
      ];
      meta = {
        platforms = lib.attrNames architectures;
      };
    };
  in {
    packages = {
      inherit helium;

      default = helium;
    };
  };
}
