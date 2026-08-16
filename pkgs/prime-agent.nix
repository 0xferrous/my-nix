{
  pkgs,
  lib ? pkgs.lib,
}:
let
  version = "0.7.2";
  releaseBase = "https://github.com/PrimeIntellect-ai/prime-agent/releases/download/v${version}";

  # Prime Agent is not on the npm registry; upstream publishes a prebuilt npm
  # tarball (dist/ included) as a GitHub release asset. Packaging from the
  # release tarball avoids rebuilding the whole TypeScript monorepo.
  srcTarball = pkgs.fetchurl {
    url = "${releaseBase}/prime-agent-${version}.tgz";
    sha256 = "bc5471f2a626d727b88a45eb745fff93b10c554a3c4fc5912f25d8c64b987f5e";
  };
in
pkgs.buildNpmPackage {
  pname = "prime-agent";
  inherit version;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  src = pkgs.runCommand "prime-agent-${version}-src" { } ''
    mkdir -p $out
    tar -xzf ${srcTarball} -C $out --strip-components=1
  '';

  postPatch = ''
    # The release tarball ships without a package-lock.json; use the vendored
    # lockfile generated from this exact tarball (npm 10, nodejs 22).
    cp ${./prime-agent/package-lock.json} package-lock.json

    # Re-point the @earendil-works/* tarball dependencies (ai, core, tui) at
    # the identical files hosted on GitHub Releases instead of upstream's
    # pub-*.r2.dev CDN URLs (content verified byte-identical). The overrides
    # below also force the transitive pi-ai dep of pi-agent-core to the same
    # GitHub asset; both patches reproduce the exact package.json the vendored
    # lockfile was generated from.
    ${pkgs.python3}/bin/python3 - <<'PYEOF'
    import json

    gh = "https://github.com/PrimeIntellect-ai/prime-agent/releases/download/v${version}"
    tarballs = {
        "@earendil-works/pi-ai": "prime-agent-ai",
        "@earendil-works/pi-agent-core": "prime-agent-core",
        "@earendil-works/pi-tui": "prime-agent-tui",
    }
    with open("package.json") as f:
        data = json.load(f)
    for dep, tarball in tarballs.items():
        data["dependencies"][dep] = f"{gh}/{tarball}-${version}.tgz"
    # Overrides force the transitive pi-ai dep of pi-agent-core to the same
    # GitHub asset.
    data["overrides"] = {
        "@earendil-works/pi-ai": f"{gh}/prime-agent-ai-${version}.tgz",
        "@earendil-works/pi-agent-core": f"{gh}/prime-agent-core-${version}.tgz",
        "@earendil-works/pi-tui": f"{gh}/prime-agent-tui-${version}.tgz",
    }
    with open("package.json", "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    PYEOF

    # Upstream bug: the TUI fullscreen input handler does not filter key-release
    # events, so terminals with the Kitty keyboard protocol (kitty, alacritty
    # with protocol enabled, foot, ...) scroll the transcript twice per
    # PageUp/PageDown press (once on keydown, once on keyup). Upstream PR #1303
    # contains the exact fix but was closed unmerged (2026-08-15, PR-queue
    # cleanup); neither main nor any release ships it. Apply the guard to the
    # shipped bundle here. Fails loudly if the context ever changes so the
    # patch is revisited on the next version bump.
    ${pkgs.python3}/bin/python3 - <<'PYEOF'
    import glob

    old = (
        "if (overlayFocused || !fullscreen.viewportControls) return false;\n"
        "    const keybindings = getKeybindings();"
    )
    new = (
        "if (overlayFocused || !fullscreen.viewportControls) return false;\n"
        "    // A key release repeats the same binding under the Kitty protocol\n"
        "    // and would scroll a second time for one keypress (upstream PR #1303).\n"
        "    if (isKeyRelease(data)) return false;\n"
        "    const keybindings = getKeybindings();"
    )
    patched = False
    for path in glob.glob("dist/bundle/chunk-*.js"):
        with open(path) as f:
            src = f.read()
        if old in src:
            with open(path, "w") as f:
                f.write(src.replace(old, new, 1))
            patched = True
            break
    if not patched:
        raise SystemExit(
            "prime-agent: could not find the fullscreen input handler context; "
            "update the kitty key-release guard patch in pkgs/prime-agent.nix"
        )
    PYEOF
  '';

  npmDepsHash = "sha256-+NwiX10EXiA6ABG5VFdcoTaxlZWGglO922LTlNSKeNg=";

  # The release tarball ships the built dist/; there is nothing to compile.
  dontNpmBuild = true;

  # prime-agent picks the Wayland vs X11 clipboard reader from
  # WAYLAND_DISPLAY / XDG_SESSION_TYPE. On this host neither is exported to the
  # TUI process, so Ctrl+V falls through to the X11 native path and silently
  # no-ops. Force the Wayland path (wl-paste) like pkgs/pi.nix does for pi, and
  # put wl-clipboard on PATH so both wl-paste (image paste) and wl-copy (text
  # copy) resolve regardless of the host profile. Also hard-disable product
  # analytics via PRIME_AGENT_TELEMETRY=0.
  postInstall = ''
    wrapProgram "$out/bin/prime-agent" \
      --prefix PATH : ${lib.makeBinPath [ pkgs.wl-clipboard ]} \
      --set XDG_SESSION_TYPE wayland \
      --set PRIME_AGENT_TELEMETRY 0
  '';

  meta = with lib; {
    description = "Self-improving RLM agent for coding workflows and long-running autonomous tasks";
    homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
    license = licenses.mit;
    mainProgram = "prime-agent";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
