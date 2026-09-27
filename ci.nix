{lib, ...}: {
  perSystem = {
    pkgs,
    self',
    system,
    ...
  }: {
    checks =
      lib.mapAttrs' (name: lib.nameValuePair "package-${name}") self'.packages
      // {
        updater =
          pkgs.runCommand "helium-updater" {
            nativeBuildInputs = [pkgs.bash pkgs.jq];
          } ''
            cd ${./.}
            bash tests/update.sh
            touch "$out"
          '';
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        headless-browser =
          pkgs.runCommand "helium-headless-browser" {
            nativeBuildInputs = [self'.packages.helium];
          } ''
            export HOME="$TMPDIR"
            timeout 60 helium --headless --no-sandbox --disable-gpu --disable-dev-shm-usage \
              --dump-dom 'data:text/html,<p>helium-check</p>' > dom.html
            grep -F '<p>helium-check</p>' dom.html
            touch "$out"
          '';
      };
  };
}
