{
  pkgs,
  device ? "tpacpi::kbd_backlight",
  defaultLevel ? 1,
  step ? 1,
  lib ? pkgs.lib,
}:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "fr-kbd-backlight";
  version = "0.1.0";

  src = ./keyboard-backlight.nu;

  dontUnpack = true;

  nativeBuildInputs = [ pkgs.nushell ];

  installPhase = ''
    install -Dm755 "$src" "$out/libexec/fr-kbd-backlight"
    patchShebangs "$out/libexec/fr-kbd-backlight"
    mkdir -p "$out/bin"
    cat > "$out/bin/fr-kbd-backlight" <<EOF
    #!${pkgs.runtimeShell}
    set -euo pipefail

    script="$out/libexec/fr-kbd-backlight"
    device=${lib.escapeShellArg device}
    default_level=${lib.escapeShellArg (toString defaultLevel)}
    step=${lib.escapeShellArg (toString step)}

    if [ "\$#" -eq 0 ]; then
      exec "\$script"
    fi

    case "\$1" in
      -h|--help|help)
        exec "\$script" "\$@"
        ;;
      *)
        command="\$1"
        shift
        exec "\$script" "\$command" --device "\$device" --default-level "\$default_level" --step "\$step" "\$@"
        ;;
    esac
    EOF
    chmod +x "$out/bin/fr-kbd-backlight"
  '';

  meta = with lib; {
    description = "Nushell helper for managing keyboard backlight brightness";
    license = licenses.mit;
    mainProgram = "fr-kbd-backlight";
    platforms = platforms.linux;
  };
}
