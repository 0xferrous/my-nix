#!/usr/bin/env nu

# Hook run when kanshi applies the only_external profile.

def list-displays [] {
  let detect_output = (ddcutil detect)
  mut displays = {}
  mut display_id = ""
  mut display_name = ""

  mut chunked_up = []
  mut current_chunk = []

  for line in ($detect_output | lines) {
    if $line == "" {
      $chunked_up = ($chunked_up | append ($current_chunk | str join "\n"))
      $current_chunk = []
    } else {
      $current_chunk = ($current_chunk | append $line)
    }
  }

  if (($current_chunk | length) > 0) {
    $chunked_up = ($chunked_up | append ($current_chunk | str join "\n"))
  }

  for chunk in $chunked_up {
    let first_line = ($chunk | lines | first)
    if ($first_line | str starts-with "Display") {
      $display_id = ($first_line | str replace "Display " "")
    } else if ($first_line | str trim | str starts-with "Invalid display") {
      continue
    }

    for line in ($chunk | lines | slice 1..) {
      if ($line | str starts-with "Display ") {
        $display_id = ($line | str replace "Display " "")
      }
      if ($line | str trim | str starts-with "Mfg id:") {
        $display_name = ($line | str trim | str replace "Mfg id:" "" | str trim)
      }
      if $display_id != "" and $display_name != "" {
        $displays = ($displays | insert $display_id { id: $display_id, name: $display_name })
        $display_id = ""
        $display_name = ""
      }
    }
  }

  $displays
}

def set-lenovo-brightness [brightness = 60] {
  notify-send $"setting brightness to ($brightness)"
  list-displays | values | where name =~ "(?i)lenovo" | first | get id | ddcutil --display $in setvcp 10 $brightness
}

def main [] {
  print "executing external_only.nu"
  notify-send "executing external_only.nu"
  set-lenovo-brightness 60
  notify-send "after executing external_only.nu"
}
