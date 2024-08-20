{ rustPlatform
, pkg-config
, dbus
}:

rustPlatform.buildRustPackage {
  pname = "org-clock-db";
  version = "0.1.0";
  src = ./.;

  cargoHash = "sha256-OX1lerkBPcaopyltxuR5hJ3x8S+YffGSodTWh7Fz28U=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus
  ];
}
