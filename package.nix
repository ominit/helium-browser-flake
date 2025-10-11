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
        vulkan-loader
        libva
        libvdpau
        libglvnd
        mesa
        glib
        fontconfig
        freetype
        pango
        cairo
        libx11
        atk
        nss
        nspr
        libxcursor
        libxext
        libxfixes
        libxrender
        libxcb
        alsa-lib
        expat
        cups
        dbus
        gdk-pixbuf
        gcc-unwrapped.lib
        systemd
        libexif
        pciutils
        liberation_ttf
        curl
        util-linux
        wget
        flac
        harfbuzz
        icu
        libpng
        snappy
        speechd
        bzip2
        libcap
        at-spi2-atk
        at-spi2-core
        libkrb5
        libdrm
        libglvnd
        libgbm
        coreutils
        libxkbcommon
        pipewire
        wayland
      ];

      runtimeDependencies = with pkgs; [libGL];

      appendRunpaths = [
        "${pkgs.libGL}/lib"
        "${pkgs.mesa}/lib"
        "${pkgs.vulkan-loader}/lib"
        "${pkgs.libva}/lib"
        "${pkgs.libvdpau}/lib"
      ];

      patchelfFlags = ["--no-clobber-old-sections"];
      autoPatchelfIgnoreMissingDeps = ["libQt5Core.so.5" "libQt5Gui.so.5" "libQt5Widgets.so.5"];

      installPhase = ''
        runHook preInstall

        libExecPath="$prefix/lib/${pname}-bin-$version"
        mkdir -p "$libExecPath"
        cp -rv ./ "$libExecPath/"

        makeWrapper "$libExecPath/chrome-wrapper" "$out/bin/${pname}" \
          --prefix LD_LIBRARY_PATH : "$rpath"

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
