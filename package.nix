{...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    info = (builtins.fromJSON (builtins.readFile ./sources.json)).${system};

    pname = "helium";
    version = info.version;

    meta = {
      description = "Privacy-focused web browser based on Chromium";
      homepage = "https://helium.computer";
      license = with pkgs.lib.licenses; [gpl3Only bsd3];
      maintainers = [{github = "ominit";}];
      platforms = ["x86_64-linux" "aarch64-linux"];
      sourceProvenance = [pkgs.lib.sourceTypes.binaryNativeCode];
      mainProgram = pname;
    };

    src-appimage = pkgs.fetchurl {
      url = info.appimage_url;
      hash = info.appimage_sha256;
    };

    helium-appimage = pkgs.appimageTools.wrapType2 {
      inherit version;
      pname = "${pname}-appimage";
      src = src-appimage;
      meta = meta // {mainProgram = "${pname}-appimage";};
      extraInstallCommands = let
        contents = pkgs.appimageTools.extract {
          inherit version;
          pname = "${pname}-appimage";
          src = src-appimage;
        };
      in ''
        install -Dm444 ${contents}/helium.desktop "$out/share/applications/helium-appimage.desktop"
        substituteInPlace "$out/share/applications/helium-appimage.desktop" \
          --replace-fail 'Exec=helium' "Exec=$out/bin/helium-appimage"
        install -Dm444 ${contents}/helium.png "$out/share/icons/hicolor/256x256/apps/helium.png"
      '';
    };

    src = pkgs.fetchurl {
      url = info.tar_url;
      hash = info.tar_sha256;
    };

    helium = pkgs.stdenv.mkDerivation {
      inherit pname version src meta;

      nativeBuildInputs = with pkgs; [
        autoPatchelfHook
        patchelfUnstable
        kdePackages.wrapQtAppsHook
        makeWrapper
      ];

      buildInputs = with pkgs; [
        alsa-lib
        at-spi2-core
        bzip2
        cairo
        coreutils
        cups
        curl
        dbus
        expat
        flac
        fontconfig
        freetype
        gcc-unwrapped.lib
        gdk-pixbuf
        glib
        gtk3
        harfbuzz
        icu
        liberation_ttf
        libcap
        libdrm
        libexif
        libglvnd
        libgbm
        libkrb5
        libpng
        libva
        libvdpau
        libx11
        libxcb
        libxcomposite
        libxcursor
        libxdamage
        libxext
        libxfixes
        libxkbcommon
        libxrandr
        libxrender
        mesa
        nspr
        nss
        pango
        pciutils
        pipewire
        qt6.qtbase
        snappy
        speechd
        systemd
        util-linux
        vulkan-loader
        wayland
        wget
      ];

      appendRunpaths = [
        "${pkgs.libGL}/lib"
        "${pkgs.mesa}/lib"
        "${pkgs.vulkan-loader}/lib"
        "${pkgs.lib.getLib pkgs.libva}/lib"
        "${pkgs.libvdpau}/lib"
      ];

      patchelfFlags = ["--no-clobber-old-sections"];
      autoPatchelfIgnoreMissingDeps = ["libQt5Core.so.5" "libQt5Gui.so.5" "libQt5Widgets.so.5"];

      installPhase = ''
        runHook preInstall

        libExecPath="$prefix/lib/${pname}-bin-$version"
        mkdir -p "$libExecPath"
        cp -rv ./ "$libExecPath/"

        mkdir -p "$out/bin"
        makeWrapper "$libExecPath/helium-wrapper" "$out/bin/${pname}" \
          --prefix LD_LIBRARY_PATH : "$rpath"

        mkdir -p "$out/share/applications"
        cp "$libExecPath/helium.desktop" "$out/share/applications/"
        substituteInPlace "$out/share/applications/helium.desktop" \
          --replace-fail 'Exec=helium' "Exec=$out/bin/helium"

        mkdir -p "$out/share/icons/hicolor/256x256/apps"
        cp "$libExecPath/product_logo_256.png" "$out/share/icons/hicolor/256x256/apps/helium.png"

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
