{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };

  outputs = {
    flake-parts,
    systems,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import systems;
      perSystem = {
        pkgs,
        system,
        ...
      }: let
        inherit (pkgs.beam.interpreters) erlang_27;
        inherit (pkgs.beam) packagesWith;

        beam = packagesWith erlang_27;

        elixir = beam.elixir.override {
          version = "1.17";
          rev = "ac64fba4eba654c3ae402a1e30f5a8bb185b88d7";
          sha256 = "FUTOpK3T0Q4RKDxSo85+iZjdIcW8rjTgacP6LX6hPII=";
        };
      in {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        devShells.default = with pkgs;
          mkShell {
            name = "peri";
            packages = with pkgs;
              [elixir]
              ++ lib.optional stdenv.isLinux [inotify-tools]
              ++ lib.optional stdenv.isDarwin [
                darwin.apple_sdk.frameworks.CoreServices
                darwin.apple_sdk.frameworks.CoreFoundation
              ];
          };
      };
    };
}
