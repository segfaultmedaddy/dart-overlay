{
  pkgs ? import <nixpkgs> { },
  system ? builtins.currentSystem,
}:
let
  inherit (pkgs) lib;
  stableSources = builtins.fromJSON (lib.strings.fileContents "./sources-${system}-stable.json");
  betaSources = builtins.fromJSON (lib.strings.fileContents "./sources-${system}-beta.json");
  devSources = builtins.fromJSON (lib.strings.fileContents "./sources-${system}-dev.json");

  mkInstall =
    {
      url,
      version,
      sha256,
    }:
    pkgs.stdenv.mkDerivation {
      inherit version;

      pname = "dart";
      src = pkgs.fetchurl { inherit url sha256; };
      dontBuild = true;
      installPhase =
        ''
          cp -R * $out/
          echo $libPath
        ''
        + lib.optionalString (pkgs.stdenv.isLinux) ''
          find $out/bin -executable -type f -exec patchelf --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) {} \;
        '';
    };
in
{ }
