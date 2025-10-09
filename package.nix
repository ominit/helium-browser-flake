{...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    info = (builtins.fromJSON (builtins.readFile ./sources.json)).${system};

    pname = "helium";
    version = info.version;

    src-appimage = pkgs.fetchurl {
      url = info.appimage_url;
      hash = info.appimage_sha256;
    };

    helium-appimage = pkgs.appimageTools.wrapType2 {
      inherit version;
      pname = "${pname}-appimage";
      src = src-appimage;

      nativeBuildInputs = [pkgs.copyDesktopItems];
      desktopItems = [
        (pkgs.makeDesktopItem {
          })
      ];
    };

    src = pkgs.fetchurl {
      url = info.tar_url;
      hash = info.tar_sha256;
    };

    helium = pkgs.stdenv.mkDerivation {
      inherit pname version src;

      nativeBuildInputs = with pkgs; [
        autoPatchelfHook
        patchelfUnstable
        copyDesktopItems
        kdePackages.wrapQtAppsHook
        makeWrapper
      ];

      buildInputs = with pkgs; [
        libgbm
        glibc
        glib
        dbus
        expat
        cups
        nspr
        nss
        libx11
        libxcb
        libxext
        libxfixes
        libxrandr
        cairo
        pango
        at-spi2-atk
        atk
        gtk3
        alsa-lib
        at-spi2-core
        qt6.qtbase
      ];

      runtimeDependencies = with pkgs; [libGL];

      appendRunpaths = ["${pkgs.libGL}/lib"];

      patchelfFlags = ["--no-clobber-old-sections"];
      autoPatchelfIgnoreMissingDeps = ["libQt5Core.so.5" "libQt5Gui.so.5" "libQt5Widgets.so.5"];

      installPhase = ''
        runHook preInstall

        mkdir -p "$prefix/lib/${pname}-bin-$version"
        ls
        cp -r "./" "$prefix/lib/${pname}-bin-$version"

        mkdir -p $out/bin
        makeWrapper "$prefix/lib/${pname}-bin-$version/chrome-wrapper" "$out/bin/${pname}"

        runHook postInstall
      '';
    };
  in {
    packages = {
      inherit helium helium-appimage;

      default = helium;
    };
  };
}
