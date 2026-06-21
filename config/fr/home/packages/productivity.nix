{ pkgs, ... }:
with pkgs;
[
  # Productivity and organization
  taskwarrior3
  timewarrior
  when-cli
  yazi
  superfile
  ranger
  zk

  # Activity tracking
  activitywatch

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
