{
  rustPlatform,
  pkg-config,
  dbus,
}:

rustPlatform.buildRustPackage {
  pname = "org-clock-db";
  version = "1.0.0";
  src = ./.;

  cargoHash = "sha256-8GwzFeyS6fdw3lChApFDuijN9vpZIf91IhWxcOdrVRM=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus
  ];
}
