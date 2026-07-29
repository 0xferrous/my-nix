{
  nix,
  writeShellApplication,
}:
writeShellApplication {
  name = "nash";
  runtimeInputs = [ nix ];
  text = ''
    export ASH_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}/nash"
    export ASH_STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}/nash"
    exec nix run "path:$HOME/dev/fr/ash" -- "$@"
  '';
  meta.description = "Run the local Ash development checkout with isolated config and state";
}
