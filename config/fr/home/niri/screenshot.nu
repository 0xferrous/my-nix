#!/usr/bin/env nu

let file = (^mktemp --suffix=.png | str trim)
^rm --force $file

try {
  ^niri msg action screenshot --path $file

  while (not ($file | path exists)) or ((ls $file | get size | first) == 0) {
    sleep 50ms
  }

  ^satty --filename $file --copy-command wl-copy --actions-on-enter "save-to-clipboard,exit"
} catch {|error|
  ^rm --force $file
  error make { msg: $"Screenshot flow failed: ($error.msg)" }
}

^rm --force $file
