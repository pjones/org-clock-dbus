{
  description = "DBus support for org-clock";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { self, ... }: {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        perSystem =
          { pkgs, system, ... }:
          let
            muslTarget =
              if system == "x86_64-linux" then
                "x86_64-unknown-linux-musl"
              else if system == "aarch64-linux" then
                "aarch64-unknown-linux-musl"
              else
                throw "Unsupported system: ${system}";

            toolchain =
              with inputs.fenix.packages.${system};
              combine [
                minimal.rustc
                minimal.cargo
                targets.${muslTarget}.latest.rust-std
              ];

            naersk = inputs.naersk.lib.${system}.override {
              cargo = toolchain;
              rustc = toolchain;
            };
          in
          {
            packages.default = self.packages.${system}.monitor;

            packages.monitor = naersk.buildPackage {
              src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;
              doCheck = true;

              nativeBuildInputs = with pkgs; [
                pkgsStatic.stdenv.cc
                pkg-config
              ];

              buildInputs = with pkgs; [
                (pkgsStatic.dbus.override (_: {
                  enableSystemd = false;
                  x11Support = false;
                }))
              ];

              CARGO_BUILD_TARGET = muslTarget;
              CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
            };

            packages.lisp = pkgs.emacs.pkgs.elpaBuild {
              pname = "org-clock-dbus";
              version = self.packages.${system}.monitor.version;
              src = ./lisp/org-clock-dbus.el;
              packageRequires = [ pkgs.emacs ];
            };

            packages.changelog = pkgs.stdenvNoCC.mkDerivation (final: {
              pname = "changelog";
              version = self.packages.${system}.monitor.version;
              src = ./CHANGELOG.yml;
              dontUnpack = true;
              dontBuild = true;

              buildInputs = with pkgs; [
                yaml2json
                jq
              ];

              installPhase = ''
                mkdir -p "$out"
                yaml2json < "$src" |
                  jq --raw-output --arg version "${final.version}" '
                    .versions.[$version].markdown
                  ' > "$out/changelog.md"
              '';
            });

            checks.changelog = self.packages.${system}.changelog;
            checks.lisp = self.packages.${system}.lisp;
            checks.monitor = self.packages.${system}.monitor;

            devShells.default = pkgs.mkShell {
              env.CARGO_BUILD_TARGET = self.packages.${system}.monitor.CARGO_BUILD_TARGET;
              env.CARGO_BUILD_RUSTFLAGS = self.packages.${system}.monitor.CARGO_BUILD_RUSTFLAGS;

              inputsFrom = [ self.packages.${system}.monitor ];
              buildInputs = [
                pkgs.rustfmt
                pkgs.rust-analyzer
              ];
            };
          };
      }
    );
}
