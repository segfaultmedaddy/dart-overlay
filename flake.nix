{
  description = "Dart versions overlay";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    let outputs = flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = import ./default.nix {inherit system pkgs;}

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            dart
          ];
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
    in outputs // {
        overlays.default = final: prev: {

        };
    };
}
