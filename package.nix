{...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    info = (builtins.fromJSON (builtins.readFile ./sources.json)).${system};

    pname = "helium";
    version = info.version;

    src = pkgs.fetchurl {
      inherit (info) url;
      hash = info.sha256;
    };

    helium = pkgs.appimageTools.wrapType2 {
      inherit pname version src;

      nativeBuildInputs = [pkgs.copyDesktopItems];
      desktopItems = [
        (pkgs.makeDesktopItem {
          })
      ];
    };
  in {
    packages = {
      inherit helium;

      default = helium;
    };
  };
}
