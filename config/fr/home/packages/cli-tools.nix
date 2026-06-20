{ pkgs, ... }:
with pkgs;
[
  # Terminal multiplexers and emulators
  tmux
  alacritty
  zellij

  # File system utilities
  eza
  bat
  fd
  ripgrep
  ripgrep-all
  tree
  dust
  dua

  # Text processing and JSON tools
  jq
  jid
  jaq
  jless
  fx
  qsv
  choose
  sd
  jqp
  htmlq
  mdq

  # System monitoring
  htop
  btop
  glances
  bottom
  bandwhich
  gping
  duf

  # System information
  fastfetch

  # Recording and documentation
  asciinema
  asciinema-agg

  # Terminal enhancements
  starship
  direnv
  zsh
  fzf

  # System utilities
  bubblewrap
  bc
  tokei
  hyperfine
  just
  navi
  pastel
  silicon
  fclones
  magic-wormhole-rs
  cpio
  lsof
  simple-http-server
  rclone
  wttrbar

  # Graph plotting
  gnuplot

  # bat extras
  bat-extras.batgrep
  bat-extras.batman
  bat-extras.prettybat
  bat-extras.batdiff

  # Argument parsing
  argc

  # Fonts
  fira-code
  fira-code-symbols

  # File browsing
  television

  # CLI multimedia tools
  ffmpeg
  imagemagick
  chafa
  exiftool
  spotdl

  # Music daemon and client
  mpd
  vimpc

  # TUI communication
  himalaya
  iamb
  gurk-rs
]
