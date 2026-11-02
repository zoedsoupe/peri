{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11-small";
    beam-overlay.url = "github:zeeetech/beam-overlay";
  };

  outputs = {
    nixpkgs,
    beam-overlay,
    ...
  }: let
    inherit (nixpkgs.lib) genAttrs;
    inherit (nixpkgs.lib.systems) flakeExposed;
    forAllSystems = f:
      genAttrs flakeExposed (system:
        f (import nixpkgs {
          inherit system;
          overlays = [beam-overlay.overlays.default];
        }));
  in {
    devShells = forAllSystems (pkgs: let
      inherit (pkgs) mkShell;
      inherit (pkgs.beam.interpreters) erlang_28;
    in {
      default = mkShell {
        name = "peri";
        packages = with pkgs;
          [
            (pkgs.beam-overlay.mkToolchain {
              elixir.version = "1.20.2";
            })
            erlang_28
          ]
          ++ lib.optional stdenv.isLinux [inotify-tools];
      };
    });
  };
}
