{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libcap_ng,
}:

let
  version = "0.7.2";
  releaseBase = "https://github.com/superradcompany/microsandbox/releases/download/v${version}";

  platform =
    {
      "x86_64-linux" = {
        arch = "x86_64";
        msbHash = "sha256-vapsb8WPo9joXVL8KZEGoBPZee3Qp4G0vG3dIdoPixY=";
        libkrunfwHash = "sha256-zpp0noRx6Jql4q2I3gwVgcM4TBALyxB6dbsSc5oS1ZA=";
      };
      "aarch64-linux" = {
        arch = "aarch64";
        msbHash = "sha256-M+T1J0ue76OgiNDwyLgKXkQP1glAwEafcaOJxpmMtxQ=";
        libkrunfwHash = "sha256-mNARNxkN5wIqMTLG9VwkXvQ9AtZ9XX5pfuGcMD/Oh2k=";
      };
    }
    .${stdenv.hostPlatform.system}
      or (throw "microsandbox is unsupported on ${stdenv.hostPlatform.system}");

  msb = fetchurl {
    url = "${releaseBase}/msb-linux-${platform.arch}";
    hash = platform.msbHash;
  };

  libkrunfw = fetchurl {
    url = "${releaseBase}/libkrunfw-linux-${platform.arch}.so";
    hash = platform.libkrunfwHash;
  };
in
stdenv.mkDerivation {
  pname = "microsandbox";
  inherit version;

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    libcap_ng
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    install -Dm755 ${msb} $out/bin/msb
    install -Dm755 ${libkrunfw} $out/lib/libkrunfw.so.5.6.1
    ln -s libkrunfw.so.5.6.1 $out/lib/libkrunfw.so.5
    ln -s libkrunfw.so.5.6.1 $out/lib/libkrunfw.so
  '';

  meta = {
    description = "Lightweight microVM sandboxes for Linux";
    homepage = "https://github.com/superradcompany/microsandbox";
    license = lib.licenses.asl20;
    mainProgram = "msb";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
