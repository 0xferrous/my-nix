{
  config,
  pkgs,
  myNixInputs,
  ...
}:
with pkgs;
[
  # Productivity and organization
  taskwarrior3
  timewarrior
  when-cli
  ranger
  zk

  # Activity tracking
  myNixInputs.self.packages.${pkgs.stdenv.hostPlatform.system}.activitywatch

  # Knowledge management and note-taking
  obsidian

  # Documentation and text
  pandoc
  mdcat
  glow
  hugo

  # Cryptocurrency and finance
  cointop
  framesh
  electrum

  # News and RSS
  newsraft
  newsboat

  # Time tracking
  wakapi

  # Journaling
  jrnl

  # Backup and sync
  restic
  syncthing

  # E-books
  calibre
]
