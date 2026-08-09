{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "0.49.0";
in
stdenvNoCC.mkDerivation {
  pname = "iron-proxy";
  inherit version;

  # iron-proxy is not in nixpkgs. Upstream publishes statically linked
  # (CGO_ENABLED=0) release binaries, so fetch those instead of building the
  # Go module tree locally; this mirrors the ironclaw packaging pattern.
  src = fetchurl {
    url = "https://github.com/ironsh/iron-proxy/releases/download/v${version}/iron-proxy_${version}_linux_amd64.tar.gz";
    sha256 = "sha256-vnMJDvrJ4gyX4RjECOZc2UIeFBsAFqcd/YPTXYg4KK0=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 iron-proxy -t $out/bin
    runHook postInstall
  '';

  meta = {
    description = "MITM egress proxy with DNS server, secret injection, and audit logging";
    homepage = "https://github.com/ironsh/iron-proxy";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "iron-proxy";
  };
}
