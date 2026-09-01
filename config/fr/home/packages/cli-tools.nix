{ pkgs, ... }:
with pkgs;
[
  # Terminal emulators
  alacritty

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

  # OCR an image from the Wayland clipboard and open the text in Neovim
  (pkgs.writeTextFile {
    name = "ocr-clipboard";
    destination = "/bin/ocr-clipboard";
    executable = true;
    text = builtins.readFile ../../../../pkgs/ocr-clipboard.nu;
  })

  # Music daemon and client
  mpd

  # TUI communication
  himalaya
  iamb
  gurk-rs
]
