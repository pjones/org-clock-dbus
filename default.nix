{
  dbus,
  nix-gitignore,
  pkg-config,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "org-clock-db";
  version = "1.0.0";
  src = nix-gitignore.gitignoreSource [ ] ./.;

  cargoHash = "sha256-25qM/1vIsKxEll+WLCSi6pUozmuxMQrM/iubXSh2XY8=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus
  ];
}
