{
  symlinks = import ./symlinks.nix;
  termfilechooser = import ./termfilechooser.nix;
  vcs = import ./vcs.nix;
  executor = import ./executor.nix;
  foundry = import ./programs/foundry.nix;
  nushell = import ./programs/nushell.nix;
  pass = import ./programs/pass.nix;
  direnv = import ./programs/direnv.nix;
  ssh = import ./programs/ssh.nix;
}
