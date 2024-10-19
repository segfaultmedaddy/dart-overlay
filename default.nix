{
  pkgs ? import <nixpkgs> { },
  system ? builtins.currentSystem,
}:
let
  inherit (pkgs) lib;

  src = {
    stable = builtins.fromJSON (lib.strings.fileContents ./sources/stable/sources.json);
    beta = builtins.fromJSON (lib.strings.fileContents ./sources/beta/sources.json);
    dev = builtins.fromJSON (lib.strings.fileContents ./sources/dev/sources.json);
  };

  mkBinary =
    {
      url,
      version,
      sha256,
    }:
    pkgs.stdenv.mkDerivation {
      inherit version;

      pname = "dart";
      nativeBuildInputs = [ pkgs.unzip ];
      src = pkgs.fetchurl { inherit url sha256; };
      dontBuild = true;
      dontStrip = true;
      libPath = lib.makeLibraryPath [ pkgs.stdenv.cc.cc ];
      installPhase =
        ''
          mkdir -p $out
          cp -R * $out/
          echo $libPath
        ''
        + lib.optionalString (pkgs.stdenv.isLinux) ''
          find $out/bin -executable -type f -exec patchelf --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) {} \;
        '';
    };

  mkChannel =
    source:
    let
      result = lib.attrsets.mapAttrs (k: v: mkBinary { inherit (v.${system}) version url sha256; }) (
        lib.attrsets.filterAttrs (k: v: (builtins.hasAttr system v)) source
      );
      latest = lib.lists.last (
        builtins.sort (x: y: (builtins.compareVersions x y) < 0) (lib.attrsets.attrNames result)
      );
    in
    result // { "default" = result.${latest}; };

  stable = mkChannel src.stable;
  dev = mkChannel src.dev;
  beta = mkChannel src.beta;
in
{
  default = stable.default;
}
// stable
// {
  dev = dev.default;
  beta = beta.default;
}
// lib.mapAttrs' (name: value: lib.nameValuePair "dev-${name}" value) dev
// lib.mapAttrs' (name: value: lib.nameValuePair "beta-${name}" value) beta
