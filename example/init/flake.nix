{
  description = "An empty project that uses Dart";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    dart.url = "github:roman-vanesyan/dart-overlay";
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      overlays = [
        (final: prev: {
          dartpkgs = inputs.dart.packages.${prev.system};
        })
      ];
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system overlays; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            dart.dev."3.6.0-334.0.dev"
          ];
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
