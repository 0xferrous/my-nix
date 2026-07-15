{ pkgs, ... }:
with pkgs;
[
  # Terminal multiplexers and emulators
  tmux
  alacritty
  zellij

  # File system utilities
  ripgrep-all
  tree
  dust

  # Text processing and JSON tools
  jid
  jaq
  jless
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
  zsh
  carapace-bridge

  # System utilities
  bubblewrap
  bc
  hyperfine
  navi
  pastel
  silicon
  fclones
  magic-wormhole-rs
  cpio
  lsof
  socat
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

  # TUI communication
  himalaya
  iamb
  gurk-rs
]
