#!/usr/bin/env nu

def clamp [value: int, max: int] {
  if $value < 0 {
    0
  } else if $value > $max {
    $max
  } else {
    $value
  }
}

def get-max [device: string] {
  ^brightnessctl -d $device max | str trim | into int
}

def get-current [device: string] {
  ^brightnessctl -d $device get | str trim | into int
}

def normalized-default-level [device: string, default_level: int] {
  clamp $default_level (get-max $device)
}

def set-brightness [device: string, value: int] {
  ^brightnessctl -q -d $device set $value
}

# Set brightness to the configured default level.
def "main on" [
  --device: string = "tpacpi::kbd_backlight",
  --default-level: int = 1,
  --step: int = 1,
] {
  set-brightness $device (normalized-default-level $device $default_level)
}

# Turn keyboard backlight off.
def "main off" [
  --device: string = "tpacpi::kbd_backlight",
  --default-level: int = 1,
  --step: int = 1,
] {
  set-brightness $device 0
}

# Toggle between off and the configured default level.
def "main toggle" [
  --device: string = "tpacpi::kbd_backlight",
  --default-level: int = 1,
  --step: int = 1,
] {
  let current = (get-current $device)
  if $current > 0 {
    set-brightness $device 0
  } else {
    set-brightness $device (normalized-default-level $device $default_level)
  }
}

# Increase brightness by one step.
def "main up" [
  --device: string = "tpacpi::kbd_backlight",
  --default-level: int = 1,
  --step: int = 1,
] {
  let current = (get-current $device)
  let max = (get-max $device)
  set-brightness $device (clamp ($current + $step) $max)
}

# Decrease brightness by one step.
def "main down" [
  --device: string = "tpacpi::kbd_backlight",
  --default-level: int = 1,
  --step: int = 1,
] {
  let current = (get-current $device)
  let max = (get-max $device)
  set-brightness $device (clamp ($current - $step) $max)
}

# Set raw brightness value.
def "main set" [
  value: int,
  --device: string = "tpacpi::kbd_backlight",
  --default-level: int = 1,
  --step: int = 1,
] {
  let max = (get-max $device)
  set-brightness $device (clamp $value $max)
}

# Print current and max brightness.
def "main status" [
  --device: string = "tpacpi::kbd_backlight",
  --default-level: int = 1,
  --step: int = 1,
] {
  let current = (get-current $device)
  let max = (get-max $device)
  print $"device=($device) current=($current) max=($max)"
}

# Show help for fr-kbd-backlight.
def main [] {
  help main
}
