{
  agentspace = import ./agentspace.nix;
  symlinks = import ./symlinks.nix;
  termfilechooser = import ./termfilechooser.nix;
  speechToText = import ./speech-to-text.nix;
  vcs = import ./vcs.nix;
  foundry = import ./programs/foundry.nix;
  pass = import ./programs/pass.nix;
  direnv = import ./programs/direnv.nix;
  ssh = import ./programs/ssh.nix;
}
