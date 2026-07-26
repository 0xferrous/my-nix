{
  curl,
  fetchFromGitHub,
  fetchPnpmDeps,
  git,
  icu,
  lib,
  makeWrapper,
  nodejs,
  openssh,
  openssl,
  pi,
  pi-acp,
  pkg-config,
  pnpm,
  pnpmConfigHook,
  python3,
  rustPlatform,
  stdenvNoCC,
  xz,
  zstd,
}:

let
  pname = "codeg-server";
  version = "0.21.9";

  src = fetchFromGitHub {
    owner = "xintaofei";
    repo = "codeg";
    rev = "v${version}";
    hash = "sha256-qnPZr1Y1WAsNlibUIl0GWe3otEQl5px73nNu+wTQ9Z0=";
  };

  frontend = stdenvNoCC.mkDerivation {
    pname = "codeg-web";
    inherit version src;

    pnpmDeps = fetchPnpmDeps {
      inherit
        pname
        version
        src
        pnpm
        ;
      hash = "sha256-vPPdAVJAtx0iqycSwT3GCOh+jIpEJY8MjAuSWvFwo40=";
      fetcherVersion = 4;
      # Avoid fetching every platform's large SWC/sharp binary. Consequently,
      # this fixed-output dependency hash is specific to x86_64-linux.
      pnpmInstallFlags = [
        "--no-force"
        "--network-concurrency=1"
        "--child-concurrency=1"
      ];
    };

    nativeBuildInputs = [
      nodejs
      pnpm
      pnpmConfigHook
    ];

    postPatch = ''
      substituteInPlace next.config.ts \
        --replace-fail \
          'const nextConfig: NextConfig = {' \
          'const nextConfig: NextConfig = { experimental: { cpus: 1, workerThreads: false },'
    '';

    env = {
      NEXT_TELEMETRY_DISABLED = "1";
      NODE_OPTIONS = "--max-old-space-size=1536";
    };

    buildPhase = ''
      runHook preBuild
      pnpm exec next build --webpack
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -R out $out
      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";
  cargoHash = "sha256-2rKhChh8/NWfNd/tHyBpZmBngDr9q4bpjBOfiR5CFxM=";

  buildNoDefaultFeatures = true;
  cargoBuildFlags = [
    "--bin=codeg-server"
    "--bin=codeg-mcp"
  ];

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    openssl
    xz
    zstd
  ];

  doCheck = false;

  postInstall = ''
    mkdir -p $out/share/codeg
    cp -R ${frontend} $out/share/codeg/web

    wrapProgram $out/bin/codeg-server \
      --set-default CODEG_STATIC_DIR $out/share/codeg/web \
      --set-default CODEG_MCP_BIN $out/bin/codeg-mcp \
      --prefix PATH : ${
        lib.makeBinPath [
          curl
          git
          nodejs
          openssh
          pi
          pi-acp
          python3
        ]
      } \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ icu ]}
  '';

  meta = {
    description = "Standalone server for the Codeg multi-agent coding workspace";
    homepage = "https://github.com/xintaofei/codeg";
    license = lib.licenses.asl20;
    mainProgram = "codeg-server";
    platforms = [ "x86_64-linux" ];
  };
}
