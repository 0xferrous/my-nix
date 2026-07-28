{
  lib,
  runCommand,
  symlinkJoin,
  ashPackage,
}:
let
  mkWrapper =
    binary:
    runCommand "ash-portal-${binary}"
      {
        meta = {
          description = "Ash Portal wrapper for ${binary}";
          license = lib.licenses.mit;
          mainProgram = binary;
          platforms = lib.platforms.linux;
        };
      }
      ''
        if [ ! -x ${lib.getExe' ashPackage binary} ]; then
          echo "ash package does not provide bin/${binary}" >&2
          exit 1
        fi
        install -Dm755 ${lib.getExe' ashPackage binary} "$out/bin/${binary}"
      '';

  gh = mkWrapper "gh";
  wl-paste = mkWrapper "wl-paste";
  all = symlinkJoin {
    name = "ash-portal-wrappers";
    paths = [
      gh
      wl-paste
    ];
    meta = {
      description = "Guest-side wrappers for the Ash Portal";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };
in
{
  inherit gh wl-paste all;
  default = all;
}
