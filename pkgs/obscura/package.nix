{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  callPackage,
  nix-update-script,
  librusty_v8 ? (
    callPackage ./librusty_v8.nix {
      inherit (callPackage ./fetchers.nix { }) fetchLibrustyV8;
    }
  ),
}:

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
  env.RUSTY_V8_ARCHIVE = librusty_v8;

  # Render build: screenshots/PDF/screencasting via the CPU paint pipeline.
  # Uses rustls, so neither CMake nor OpenSSL is needed (stealth would add
  # both via wreq/BoringSSL).
  buildFeatures = [ "render" ];

  cargoHash = "sha256-tBuPQjjqXkF+vcBRXXyi9+gcBzg8L3QH2jjixBzGODE=";

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
