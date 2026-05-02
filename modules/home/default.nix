{
  symlinks = import ./symlinks.nix;
  vcs = import ./vcs.nix;
  foundry = import ./programs/foundry.nix;
  pass = import ./programs/pass.nix;
  ssh = import ./programs/ssh.nix;
}
