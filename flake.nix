{
  description = "DBus support for org-clock";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "i686-linux"
      ];

      # Function to generate a set based on supported systems:
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Attribute set of nixpkgs for each system:
      nixpkgsFor = forAllSystems (system:
        import nixpkgs { inherit system; });
    in
    {
      packages = forAllSystems (system:
        let pkgs = nixpkgsFor.${system}; in {
          monitor = pkgs.callPackage ./monitor { };

          lisp = pkgs.emacs.pkgs.elpaBuild {
            pname = "org-clock-dbus";
            version = "0.1.0";
            src = ./lisp/org-clock-dbus.el;
            packageRequires = [ pkgs.emacs ];
          };
        });

      devShells = forAllSystems (system:
        let pkgs = nixpkgsFor.${system}; in {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.monitor ];
            buildInputs = [ pkgs.rustfmt ];
          };
        });
    };
}
