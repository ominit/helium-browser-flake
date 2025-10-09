Flake for [imput's Helium browser](https://helium.computer/)

The source is kept up to date via a Github Action.

There are two outputs: `helium` and `helium-appimage`.
They are both different ways of packaging the latest release.

You should most likely pick the `helium` version.
The AppImage version exists primarily for compatibility reasons.

```nix
helium-browser = {
  url = "github:ominit/helium-browser-flake";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

```nix
inputs.helium-browser.packages."${pkgs.system}".helium
```
