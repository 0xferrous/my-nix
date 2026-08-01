{
  nix,
  writeShellApplication,
}:
writeShellApplication {
  name = "nash";
  runtimeInputs = [ nix ];
  text = ''
    export ASH_NAME=nash
    exec nix run "git+file://$HOME/dev/fr/ash" -- "$@"
  '';
  meta.description = "Run the local Ash development checkout in the nash XDG namespace";
}
