#!/usr/bin/env nix-shell
#! nix-shell -i nu -p nushell tesseract wl-clipboard neovim

# OCR a PNG image from the Wayland clipboard and open the result in Neovim.
let temp_file = mktemp --suffix .txt

try {
  wl-paste --no-newline --type image/png
    | tesseract stdin stdout
    | save --force $temp_file

  nvim $temp_file
} catch {|error|
  rm --force $temp_file
  error make { msg: $"OCR clipboard failed: ($error.msg)" }
}

rm --force $temp_file
