{
  lib,
  buildGoModule,
  fetchFromGitHub,
  fetchpatch,
}:
let
  version = "0.49.0";
in
buildGoModule {
  pname = "iron-proxy";
  inherit version;

  # iron-proxy is not in nixpkgs. Build the release source locally so we can
  # carry the expired-certificate cache fix until it lands in an upstream
  # release.
  src = fetchFromGitHub {
    owner = "paradigmxyz";
    repo = "iron-proxy";
    tag = "v${version}";
    hash = "sha256-bZC3u4V2q9T/URgGbxzfizLbGUt4ERCAxWRidNQ4g8I=";
  };

  patches = [
    (fetchpatch {
      name = "regenerate-expired-cached-certificates.patch";
      url = "https://github.com/paradigmxyz/iron-proxy/commit/15c72756cc7133bdd22aa72e68776efc439c6d00.patch";
      hash = "sha256-hmUoPTUzsGNoS7nzanSjj8TAvOLzyUNvIVQE2GnbxKQ=";
    })
  ];

  vendorHash = "sha256-6KUQeShcgeOJwlP/aE8RlgfmtmGNC9MJjJtJ1BMREe4=";

  subPackages = [ "cmd/iron-proxy" ];

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "MITM egress proxy with DNS server, secret injection, and audit logging";
    homepage = "https://github.com/ironsh/iron-proxy";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "iron-proxy";
  };
}
