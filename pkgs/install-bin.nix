{
  pkgs,
  lib ? pkgs.lib,
}:

pkgs.writeShellApplication {
  name = "install-bin";
  runtimeInputs = [ pkgs.coreutils ];
  text = ''
    set -eu

    if [ "$#" -ne 1 ]; then
      echo "usage: install-bin <path>" >&2
      exit 1
    fi

    target="$1"
    file="$(basename "$target")"
    dest="$HOME/bin/$file"

    mkdir -p "$HOME/bin"
    ln -sfn "$target" "$dest"
  '';

  meta = with lib; {
    description = "Symlink a binary into ~/bin using the source path basename";
    mainProgram = "install-bin";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
