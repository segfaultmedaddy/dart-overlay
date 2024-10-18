# Nix Flake for Dart

This repository is a Nix flake packaging the Dart toolchain. The flake provides binaries built officially by the Dart team.

It supports three channels: stable, beta, and dev.

Currently, `aarch64-linux`, `x86_64-linux`, `aarch64-darwin`, and `x86_64-darwin` systems are supported. The flake doesn't provide binaries for versions that do not support any of these systems.

## Usage

- `packages."<version>"` for stable releases
- `packages.beta."<version>"` for beta releases
- `packages.dev."<version>"` for dev releases
- `packages.stable`, `packages.beta`, and `packages.dev` for the latest version from stable, beta, and dev correspondingly
- `overlays.default` is an overlay that adds `dartpkgs` to the packages exposed by the flake

In `flake.nix`:

```nix
{
  inputs = {
    dart.url = "github:roman-vanesyan/dart-overlay";
  };

  outputs = { dart, ... }: { ... };
}
```

In a shell:

```sh
nix run 'github:roman-vanesyan/dart-overlay' # latest stable
nix run 'github:roman-vanesyan/dart-overlay#beta' # latest beta
nix shell 'github:roman-vanesyan/dart-overlay#dev."3.7.0-27.0.dev"' # 3.7.0-27.0.dev from dev channel
```

## Acknowledgement

This repository is inspired by https://github.com/mitchellh/zig-overlay.

## License

MIT licensed.
