{
  pkgs,
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_9,
  nodejs_22,
  jdk17,
  androidAbi ? "x86_64",
}:

let
  pname = "bb-android-${androidAbi}";
  version = "0.43.0";
  pnpm = pnpm_9;
  nodejs = nodejs_22;
  jdk = jdk17;
  gradlePackages = pkgs."gradle-packages";
  gradle = pkgs.callPackage gradlePackages.wrapGradle {
    "gradle-unwrapped" = gradlePackages.mkGradle {
      version = "9.3.1";
      hash = "sha256-smbV/2uQ6tptw7IMsJDjcxMC5VOifF0+TfHw12vq/wY=";
      defaultJava = jdk;
    };
  };

  # Expo SDK 57 / React Native 0.86.2 pins these Android toolchain versions.
  android = pkgs.androidenv.override { licenseAccepted = true; };
  androidPackages = android.composeAndroidPackages {
    platformVersions = [ 36 ];
    buildToolsVersions = [
      "35.0.0"
      "36.0.0"
    ];
    cmakeVersions = [ "3.30.5" ];
    includeNDK = true;
    ndkVersions = [ "27.1.12297006" ];
    includeEmulator = false;
    includeSystemImages = false;
    includeSources = false;
  };
  androidSdk = androidPackages.androidsdk;
  androidHome = "${androidSdk}/libexec/android-sdk";
  androidNdk = "${androidHome}/ndk/27.1.12297006";
  cmakeHome = "${androidHome}/cmake/3.30.5";

  source = fetchFromGitHub {
    owner = "get-bb";
    repo = "bb";
    rev = "desktop-v${version}";
    hash = "sha256-8bZcqbZ24rkIVpqjv18TTJcb4AOoihpsqtCHrAhkR/Y=";
  };

  pnpmWorkspaces = [ "@bb/mobile..." ];
  pnpmInstallFlags = [
    "--config.supportedArchitectures.os=linux"
    "--config.supportedArchitectures.cpu=x64"
    "--config.supportedArchitectures.libc=glibc"
  ];
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  inherit
    pname
    version
    pnpmInstallFlags
    pnpmWorkspaces
    ;

  src = source;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      src
      pnpmInstallFlags
      pnpmWorkspaces
      ;
    inherit pnpm;
    fetcherVersion = 3;
    hash = "sha256-nAah+9POXVAKvThd4VnIs/THh+w75wsr2pvdxzXnKLM=";
  };

  mitmCache = gradle.fetchDeps {
    inherit (finalAttrs) pname;
    data = ./android-deps.json;
  };

  nativeBuildInputs = [
    gradle
    nodejs
    pnpm
    pnpmConfigHook
  ];

  buildInputs = [
    androidSdk
    jdk
  ];

  dontStrip = true;

  gradleUpdateTask = "-p apps/mobile/android --no-parallel :app:assembleRelease";

  configurePhase = ''
    ulimit -n 1048576 2>/dev/null || true
    runHook preConfigure
    runHook postConfigure

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export JAVA_HOME="${jdk.home}"
    export ANDROID_HOME="${androidHome}"
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export ANDROID_NDK_ROOT="${androidNdk}"
    export PATH="${cmakeHome}/bin:$PATH"
    export EXPO_NO_TELEMETRY=1
    export EXPO_NO_DOCTOR=1
    export CI=1
    export CMAKE_BUILD_PARALLEL_LEVEL=1
    export NINJAFLAGS=-j1
    export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$ANDROID_HOME/build-tools/36.0.0/aapt2 -Dorg.gradle.parallel=false -Dorg.gradle.workers.max=1"

    # The desktop release tag does not update the mobile Expo version. Keep the
    # APK metadata aligned with this package and use a monotonically increasing
    # Android version code derived from 0.43.0.
    node <<'NODE'
    const fs = require("node:fs");
    const appJsonPath = "apps/mobile/app.json";
    const appJson = JSON.parse(fs.readFileSync(appJsonPath, "utf8"));
    appJson.expo.version = "${version}";
    appJson.expo.android.versionCode = 4300;
    fs.writeFileSync(appJsonPath, `''${JSON.stringify(appJson, null, 2)}\n`);
    NODE

    pnpm --dir apps/mobile exec expo prebuild --platform android --no-install

    # The pnpm store is only needed while installing node_modules. Removing it
    # before Gradle keeps the native build's temporary workspace manageable.
    if [ -n "''${STORE_PATH-}" ] && [ -d "$STORE_PATH" ]; then
      find "$STORE_PATH" -depth -type f -delete
      find "$STORE_PATH" -depth -type d -empty -delete
    fi

    # @react-native-cookies/cookies still references the retired JCenter
    # repository in its Android Gradle script.
    substituteInPlace apps/mobile/node_modules/@react-native-cookies/cookies/android/build.gradle \
      --replace-fail 'jcenter()' 'mavenCentral()'

    cat > apps/mobile/android/local.properties <<EOF
    sdk.dir=$ANDROID_HOME
    cmake.dir=${cmakeHome}
    EOF
  '';

  buildPhase = ''
    ulimit -n 1048576 2>/dev/null || true
    runHook preBuild

    # Restrict the APK to one architecture to keep native build intermediates
    # small and make the target ABI explicit in the package name.
    gradle -p apps/mobile/android \
      -PreactNativeArchitectures=${androidAbi} \
      -x bundleReleaseLocalLintAar \
      -x lintVitalAnalyzeRelease \
      :app:assembleRelease

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm0644 apps/mobile/android/app/build/outputs/apk/release/app-release.apk \
      "$out/bb-${version}.apk"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -s "$out/bb-${version}.apk"
    ${androidHome}/build-tools/36.0.0/aapt2 dump badging "$out/bb-${version}.apk" \
      | grep -F "versionCode='4300' versionName='${version}'"
    runHook postInstallCheck
  '';

  passthru.category = "Mobile Apps";
  meta = {
    description = "bb Android app for ${androidAbi}, built from the upstream Expo source";
    homepage = "https://getbb.app";
    changelog = "https://github.com/get-bb/bb/commits/main/apps/mobile";
    downloadPage = "https://github.com/get-bb/bb";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
      binaryNativeCode
    ];
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
  };
})
