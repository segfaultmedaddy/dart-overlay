{
  description = "Dart binaries. Supporting stable, beta and dev channels.";

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
    let
      outputs =
        flake-utils.lib.eachSystem
          [
            "x86_64-linux"
            "aarch64-linux"
            "x86_64-darwin"
            "aarch64-darwin"
          ]
          (
            system:
            let
              pkgs = import nixpkgs { inherit system; };
            in
            rec {
              packages = import ./default.nix { inherit system pkgs; };

              apps = {
                default = apps.dart;
                dart = flake-utils.lib.mkApp { drv = packages.default; };
              };

              devShells.default = pkgs.mkShell {
                buildInputs = with pkgs; [
                  dart
                ];
              };

              formatter = pkgs.nixfmt-rfc-style;

              templates = {
                dev = {
                  path = ./templates/dev;
                  description = "An empty development environment with Dart binary from dev channel";
                };
              };
            }
          );
    in
    outputs
    // {
      overlays.default = final: prev: {
        dartpkgs = outputs.packages.${prev.system};
      };
    };
}
