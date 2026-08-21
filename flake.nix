{
  description = "DBus support for org-clock";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

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
            naersk = pkgs.callPackage inputs.naersk { };
          in
          {
            packages.default = self.packages.${system}.monitor;

            packages.monitor = naersk.buildPackage {
              src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;

              nativeBuildInputs = with pkgs; [
                pkg-config
                dbus
              ];
            };

            packages.lisp = pkgs.emacs.pkgs.elpaBuild {
              pname = "org-clock-dbus";
              version = self.packages.${system}.monitor.version;
              src = ./lisp/org-clock-dbus.el;
              packageRequires = [ pkgs.emacs ];
            };

            devShells.default = pkgs.mkShell {
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
