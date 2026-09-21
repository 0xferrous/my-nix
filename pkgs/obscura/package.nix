{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchurl,
  callPackage,
  runCommand,
  nix-update-script,
  librusty_v8 ? (
    callPackage ./librusty_v8.nix {
      inherit (callPackage ./fetchers.nix { }) fetchLibrustyV8;
    }
  ),
  librusty_v8_host ? null,
}:
let
  hostLibrustyV8 =
    if librusty_v8_host != null then
      librusty_v8_host
    else if stdenv.buildPlatform.system == stdenv.hostPlatform.system then
      librusty_v8
    else
      fetchurl {
        name = "librusty_v8-137.3.0-${stdenv.buildPlatform.system}";
        url = "https://github.com/denoland/rusty_v8/releases/download/v137.3.0/librusty_v8_release_${stdenv.buildPlatform.rust.rustcTarget}.a.gz";
        hash =
          {
            x86_64-linux = "sha256-omgf3lMBir0zZgGPEyYX3VmAAt948VbHvG0v9gi1ZWc=";
            aarch64-linux = "sha256-42jQy0HBecQ6mQ5OxKVeRN2XYvHTS+FWlqzEQz+KbJI=";
            x86_64-darwin = "sha256-ZnFsCn2VDqLHKqr2oMGkAqO6xV/fwLQ0H0mzjpr+zXU=";
            aarch64-darwin = "sha256-YFA9ZyTlUsRrAewmChXnnobEcVtxl8XGJ0iRG/H04HA=";
          }
          .${stdenv.buildPlatform.system};
      };
in

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "obscura";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "h4ckf0r0day";
    repo = "obscura";
    tag = "v${finalAttrs.version}";
    hash = "sha256-f09I77mKhQA1mCt8YmtVqbK/QIb9MrvhpYav+FJdkRI=";
  };

  # The v8 crate's build script downloads librusty_v8.a at build time; the Nix
  # sandbox has no network, so point it at a prefetched release archive (same
  # approach as nixpkgs' deno/codex/windmill packages).
  env = {
    RUSTY_V8_ARCHIVE = librusty_v8;
    RUSTY_V8_ARCHIVE_HOST = hostLibrustyV8;
  };

  # The build-dependency snapshot is executed on the build platform and needs
  # a build-platform V8 archive; the final binary links the host-platform
  # archive. The patched v8 build script selects between these variables.
  cargoDeps =
    let
      unpatchedCargoDeps = rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) src;
        hash = "sha256-tBuPQjjqXkF+vcBRXXyi9+gcBzg8L3QH2jjixBzGODE=";
      };
    in
    if stdenv.buildPlatform.system == stdenv.hostPlatform.system then
      unpatchedCargoDeps
    else
      runCommand "${finalAttrs.pname}-${finalAttrs.version}-vendor-cross" { } ''
        cp -R --no-preserve=mode,ownership ${unpatchedCargoDeps}/. "$out"
        chmod -R u+w "$out"
        patch -d "$out" -p1 < ${../../patches/obscura-rusty-v8-cross-compile.patch}
      '';

  # Render build: screenshots/PDF/screencasting via the CPU paint pipeline.
  # Uses rustls, so neither CMake nor OpenSSL is needed (stealth would add
  # both via wreq/BoringSSL).
  buildFeatures = [ "render" ];

  # Tests need the obstacle-course companion repo and network fixtures.
  doCheck = false;

  # Upstream keeps the workspace Cargo version at 0.1.0 even though release
  # tags are v0.2.0+; the binary reports 0.1.0. Keep the package version in
  # step with the tag and just sanity-check the binary reports 0.1.0.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    version=$(${placeholder "out"}/bin/obscura --version | awk '{print $2}')
    echo "obscura reports version $version"
    if [ "$version" != "0.1.0" ]; then
      echo "obscura --version did not report the upstream Cargo version 0.1.0" >&2
      exit 1
    fi
    runHook postInstallCheck
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Headless browser engine in Rust: V8, real DOM, CDP, stealth — a drop-in replacement for headless Chrome";
    homepage = "https://github.com/h4ckf0r0day/obscura";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "obscura";
  };
})
