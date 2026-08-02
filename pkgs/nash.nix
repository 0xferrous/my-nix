{
  nix,
  writeShellApplication,
}:
writeShellApplication {
  name = "nash";
  runtimeInputs = [ nix ];
  text = ''
    export ASH_NAME=nash

    ash_path="''${NASH_ASH_PATH:-$HOME/dev/fr/ash}"
    ash_ref="git+file://$ash_path"
    add_ash_override=true
    previous=
    for argument in "$@"; do
      if [[ "$argument" == --override-input=ash=* ]] \
        || { [[ "$previous" == --override-input ]] && [[ "$argument" == ash=* ]]; }; then
        add_ash_override=false
        break
      fi
      previous="$argument"
    done

    if [[ "''${1:-}" == spawn ]] && $add_ash_override; then
      set -- "$@" --override-input "ash=$ash_ref"
    fi

    exec nix run "$ash_ref" -- "$@"
  '';
  meta.description = "Run the local Ash development checkout in the nash XDG namespace";
}
