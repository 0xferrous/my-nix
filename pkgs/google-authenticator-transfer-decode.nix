{
  pkgs,
  lib ? pkgs.lib,
}:

pkgs.stdenvNoCC.mkDerivation {
  pname = "google-authenticator-transfer-decode";
  version = "0.1.0";

  src = ./google-authenticator-transfer-decode.py;

  dontUnpack = true;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    install -Dm755 "$src" "$out/libexec/google-authenticator-transfer-decode"
    patchShebangs "$out/libexec/google-authenticator-transfer-decode"

    makeWrapper "$out/libexec/google-authenticator-transfer-decode" \
      "$out/bin/google-authenticator-transfer-decode" \
      --prefix PATH : ${lib.makeBinPath [ pkgs.zbar ]}
  '';

  meta = with lib; {
    description = "Decode Google Authenticator transfer QR payloads to standard otpauth URIs";
    license = licenses.mit;
    mainProgram = "google-authenticator-transfer-decode";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
