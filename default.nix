{
  pkgs ? import <nixpkgs> { },
  system ? builtins.currentSystem,
}:
let
  inherit (pkgs) lib;

  src = {
    stable = builtins.fromJSON (lib.strings.fileContents "./sources/stable/sources.json");
    beta = builtins.fromJSON (lib.strings.fileContents "./sources/beta/sources.json");
    dev = builtins.fromJSON (lib.strings.fileContents "./sources/dev/sources.json");
  };

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

  mkChannel = lib.attrsets.mapAttrs (k: v: mkInstall { inherit (v.${system}) version url sha256; }) (
    lib.attrsets.filterAttrs (k: v: (builtins.hasAttr system v))
  );

  stable = mkChannel (src.stable);
  dev = mkChannel (src.dev);
  beta = mkChannel (src.beta);

  # latest stable versions. It is fine to take the first entry as
  # it is expected that the source map will be sorted in desc order by
  # version.
  latest = lib.lists.first stable;
in
stable
// {
  dev = dev;
}
// {
  beta = beta;
}
// {
  default = stable.${latest};
}
