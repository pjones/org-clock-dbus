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

  cargoHash = "sha256-8GwzFeyS6fdw3lChApFDuijN9vpZIf91IhWxcOdrVRM=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus
  ];
}
