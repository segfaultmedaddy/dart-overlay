{
  description = "An empty project that uses Dart from dev channel";

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
      overlays = [ inputs.dart.overlays.default ];
      systems = builtins.attrsets.attrNames inputs.dart.packages;
    in
    flake-utils.lib.eachSystem systems (
      system:
      let
        pkgs = import nixpkgs { inherit system overlays; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            dartpkgs.dev
          ];
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
