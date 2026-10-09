{
  lib,
  niri,
  nushell,
  procps,
  waydroid,
  writeShellApplication,
}:
writeShellApplication {
  name = "waydroid-size";
  runtimeInputs = [
    niri
    nushell
    procps
    waydroid
  ];
  text = ''
    args=()
    for arg in "$@"; do
      case "$arg" in
        -w=*) args+=(--width "''${arg#-w=}") ;;
        -h=*) args+=(--height "''${arg#-h=}") ;;
        -r=*) args+=(--ratio "''${arg#-r=}") ;;
        -m=*) args+=(--margin "''${arg#-m=}") ;;
        -s=*) args+=(--strut "''${arg#-s=}") ;;
        --width=*) args+=(--width "''${arg#--width=}") ;;
        --height=*) args+=(--height "''${arg#--height=}") ;;
        --ratio=*) args+=(--ratio "''${arg#--ratio=}") ;;
        --margin=*) args+=(--margin "''${arg#--margin=}") ;;
        --strut=*) args+=(--strut "''${arg#--strut=}") ;;
        *) args+=("$arg") ;;
      esac
    done
    exec ${lib.getExe nushell} ${./waydroid-size.nu} "''${args[@]}"
  '';
  meta = {
    description = "Size the Waydroid surface for the focused Niri output";
    homepage = "https://github.com/0xferrous/my-nix";
    license = lib.licenses.mit;
    mainProgram = "waydroid-size";
    platforms = lib.platforms.linux;
  };
}
