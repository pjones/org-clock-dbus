{ rustPlatform
, pkg-config
, dbus
}:

rustPlatform.buildRustPackage {
  pname = "org-clock-db";
  version = "1.0.0";
  src = ./.;

  cargoHash = "sha256-dWyN4HRYHwNAzaa5ulfHdi61OHfQRC6qk31Kzih4zZ0=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus
  ];
}
