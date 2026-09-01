# wallet-cli (TRON command-line wallet) — original Java implementation.
# Interactive REPL built with Gradle 7.6 and a shadow (fat) jar.
#
# Uses nixpkgs' Gradle builder with a mitm-cache fixed-output derivation to
# make dependency resolution reproducible. To refresh dependencies after a
# version bump, run the `mitmCache.updateScript` passthru from this repo root.
{
  pkgs,
  lib,
  version ? "4.12.0",
  rev ? "0190dab7e7ccffc18d9343ccac50db0714290dd3", # wallet-cli-4.12.0
}:

let
  jdk = pkgs.openjdk17_headless;
  # Must stay on Gradle 7.x: the build uses shadow-jar plugin 7.1.2, which is
  # incompatible with Gradle 8+ (upstream's wrapper pins gradle-7.6).
  gradle = pkgs.gradle_7.override { java = jdk; };

  # The protobuf-gradle-plugin normally downloads these binaries into the
  # Gradle cache, where they lose their executable bit; use nix-built ones.
  # Versions must match build.gradle's protobufVersion/grpcVersion.
  protoc = pkgs.stdenv.mkDerivation rec {
    pname = "protoc";
    version = "3.25.8";
    src = pkgs.fetchurl {
      url = "https://repo1.maven.org/maven2/com/google/protobuf/protoc/${version}/protoc-${version}-linux-x86_64.exe";
      hash = "sha256-40EhJ02oQJvIbAk7ho4F3xmMvh9QFyAqVghmOQrj1uw=";
    };
    sourceRoot = ".";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
    ];
    installPhase = ''
      install -Dm0755 "$src" "$out/bin/protoc"
    '';
  };
  protocGenGrpcJava = pkgs.stdenv.mkDerivation rec {
    pname = "protoc-gen-grpc-java";
    version = "1.75.0";
    src = pkgs.fetchurl {
      url = "https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/${version}/protoc-gen-grpc-java-${version}-linux-x86_64.exe";
      hash = "sha256-WTZvtYoZ79TjZ0wVaOlO8WeBYVGs+q0C+k7wS7yrKT0=";
    };
    sourceRoot = ".";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    installPhase = ''
      install -Dm0755 "$src" "$out/bin/protoc-gen-grpc-java"
    '';
  };
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "tron-wallet-cli-java";
  inherit version;

  src = pkgs.fetchgit {
    url = "https://github.com/tronprotocol/wallet-cli";
    inherit rev;
    hash = "sha256-k9lYh+vbtubIdI3qUs29Fo6YwmsRr83eGz6G4adA1T0=";
  };

  sourceRoot = "${finalAttrs.src.name}/java";

  postPatch = ''
    substituteInPlace build.gradle \
      --replace 'artifact = "com.google.protobuf:protoc:$protobufVersion"' 'path = "${protoc}/bin/protoc"' \
      --replace 'artifact = "io.grpc:protoc-gen-grpc-java:$grpcVersion"' 'path = "${protocGenGrpcJava}/bin/protoc-gen-grpc-java"'
  '';

  nativeBuildInputs = [
    gradle
    pkgs.makeWrapper
  ];

  mitmCache = gradle.fetchDeps {
    inherit (finalAttrs) pname;
    data = ./java-deps.json;
  };

  __darwinAllowLocalNetworking = true;

  gradleFlags = [ "-Dfile.encoding=utf-8" ];
  # tests need network/config; skip them
  gradleCheckTask = "test";
  doCheck = false;
  gradleBuildTask = "shadowJar";

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/java" "$out/bin"
    cp build/libs/wallet-cli.jar "$out/share/java/wallet-cli-java.jar"
    makeWrapper ${jdk}/bin/java "$out/bin/wallet-cli-java" \
      --add-flags "-jar $out/share/java/wallet-cli-java.jar"
    runHook postInstall
  '';

  dontStrip = true;

  meta = with lib; {
    description = "Original interactive TRON command-line wallet (Java/Gradle)";
    homepage = "https://github.com/tronprotocol/wallet-cli";
    license = licenses.lgpl3Plus;
    mainProgram = "wallet-cli-java";
    platforms = platforms.linux ++ platforms.darwin;
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryBytecode # mitm cache
    ];
  };
})
