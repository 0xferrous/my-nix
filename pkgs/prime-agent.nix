{
  pkgs,
  lib ? pkgs.lib,
}:
let
  version = "0.7.0";
  releaseBase = "https://github.com/PrimeIntellect-ai/prime-agent/releases/download/v${version}";

  # Prime Agent is not on the npm registry; upstream publishes a prebuilt npm
  # tarball (dist/ included) as a GitHub release asset. Packaging from the
  # release tarball avoids rebuilding the whole TypeScript monorepo.
  srcTarball = pkgs.fetchurl {
    url = "${releaseBase}/prime-agent-${version}.tgz";
    sha256 = "88b6578518c72cd51a825bc80f28e0fef9a64c67de4a7d6fd7afd7ca1b34da0b";
  };
in
pkgs.buildNpmPackage {
  pname = "prime-agent";
  inherit version;

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
  '';

  npmDepsHash = "sha256-GfWqb4Z+OuykbMUJ1nIrQzYMz19Y2DFFIaPia4mz7ZM=";

  # The release tarball ships the built dist/; there is nothing to compile.
  dontNpmBuild = true;

  meta = with lib; {
    description = "Self-improving RLM agent for coding workflows and long-running autonomous tasks";
    homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
    license = licenses.mit;
    mainProgram = "prime-agent";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
