def usage [] {
  print --stderr 'Usage: waydroid-size [-w=FACTOR | -h=FACTOR] [-r=WIDTH:HEIGHT] [-m=PIXELS]

FACTOR must be greater than 0 and at most 1.
  -w=FACTOR  Size the app width as a fraction of the screen width.
  -h=FACTOR  Size the app height as a fraction of the available screen height.

-w and -h are mutually exclusive. If neither is provided, -w=0.25 is used.
-r defaults to 9:19.5. -m defaults to 90 pixels for the bar exclusion.
-s defaults to 6 pixels for each configured horizontal Niri strut.'
}

def fail [message: string, code: int = 1] {
  print --stderr $message
  exit $code
}

def ratio_size [value: int, ratio_width: float, ratio_height: float, inverse: bool = false] {
  if $inverse {
    (($value | into float) * $ratio_height / $ratio_width | math floor | into int)
  } else {
    (($value | into float) * $ratio_width / $ratio_height | math floor | into int)
  }
}

def waydroid-prop [property: string] {
  let result = (^waydroid prop get $property | complete)
  if $result.exit_code != 0 {
    fail $"waydroid-size: failed to read ($property); is Waydroid running?"
  }
  $result.stdout | str trim
}

def set-waydroid-prop [property: string, value: int] {
  let result = (^waydroid prop set $property ($value | into string) | complete)
  if $result.exit_code != 0 {
    fail $"waydroid-size: failed to set ($property)"
  }
}

def main [
  --width(-w): float
  --height(-h): float
  --ratio(-r): string = "9:19.5"
  --margin(-m): int = 90
  --strut(-s): int = 6
] {
  if $width != null and $height != null {
    fail "waydroid-size: -w and -h are mutually exclusive" 2
  }

  let factor = if $width != null {
    $width
  } else if $height != null {
    $height
  } else {
    0.25
  }
  if $factor <= 0 or $factor > 1 {
    fail $"waydroid-size: sizing factor ($factor) must satisfy 0 < x <= 1" 2
  }
  if $margin < 0 or $strut < 0 {
    fail "waydroid-size: margin and strut must be non-negative" 2
  }

  let ratio_parts = ($ratio | split row ":")
  if ($ratio_parts | length) != 2 {
    fail $"waydroid-size: invalid ratio '($ratio)' (expected W:H)" 2
  }

  let ratio_width = try {
    $ratio_parts.0 | into float
  } catch {
    fail $"waydroid-size: invalid ratio '($ratio)' (expected W:H)" 2
  }
  let ratio_height = try {
    $ratio_parts.1 | into float
  } catch {
    fail $"waydroid-size: invalid ratio '($ratio)' (expected W:H)" 2
  }
  if $ratio_width <= 0 or $ratio_height <= 0 {
    fail $"waydroid-size: invalid ratio '($ratio)' (expected positive W:H)" 2
  }

  let niri_check = (^niri msg outputs | complete)
  if $niri_check.exit_code != 0 {
    fail "waydroid-size: niri is not reachable; set the size manually with
  waydroid prop set persist.waydroid.width <w>
  waydroid prop set persist.waydroid.height <h>"
  }

  let focused_output = (^niri msg focused-output | complete)
  if $focused_output.exit_code != 0 {
    fail "waydroid-size: could not read the focused output size"
  }
  let logical_line = (
    $focused_output.stdout
    | lines
    | where {|line| $line | str contains "Logical size:"}
    | first
  )
  if $logical_line == null {
    fail "waydroid-size: could not read the focused output size"
  }
  let logical = ($logical_line | split row ":" | last | str trim)
  let dimensions = ($logical | split row "x")
  if ($dimensions | length) != 2 {
    fail $"waydroid-size: invalid focused output size '($logical)'"
  }
  let screen_width = try {
    $dimensions.0 | into int
  } catch {
    fail $"waydroid-size: invalid focused output size '($logical)'"
  }
  let screen_height = try {
    $dimensions.1 | into int
  } catch {
    fail $"waydroid-size: invalid focused output size '($logical)'"
  }
  let height_limit = $screen_height - $margin
  let width_limit = $screen_width - (2 * $strut)
  if $height_limit <= 0 {
    fail $"waydroid-size: margin ($margin)px leaves no room on a ($logical) output"
  }
  if $width_limit <= 0 {
    fail $"waydroid-size: struts leave no usable width on a ($logical) output"
  }

  let size = if $width != null or ($width == null and $height == null) {
    let app_width = (($width_limit | into float) * $factor | math floor | into int)
    let app_height = (ratio_size $app_width $ratio_width $ratio_height true)
    if $app_height > $height_limit {
      let constrained_height = $height_limit
      {
        width: (ratio_size $constrained_height $ratio_width $ratio_height)
        height: $constrained_height
      }
    } else {
      { width: $app_width, height: $app_height }
    }
  } else {
    let app_height = (($height_limit | into float) * $factor | math floor | into int)
    let app_width = (ratio_size $app_height $ratio_width $ratio_height)
    if $app_width > $width_limit {
      let constrained_width = $width_limit
      {
        width: $constrained_width
        height: (ratio_size $constrained_width $ratio_width $ratio_height true)
      }
    } else {
      { width: $app_width, height: $app_height }
    }
  }

  if $size.width <= 0 or $size.height <= 0 {
    fail $"waydroid-size: calculated an invalid size ($size.width)x($size.height)"
  }

  set-waydroid-prop "persist.waydroid.width" $size.width
  set-waydroid-prop "persist.waydroid.height" $size.height

  let actual_width = (waydroid-prop "persist.waydroid.width")
  let actual_height = (waydroid-prop "persist.waydroid.height")
  if $actual_width != ($size.width | into string) or $actual_height != ($size.height | into string) {
    fail $"waydroid-size: failed to set ($size.width)x($size.height); is Waydroid running?"
  }

  let sizing_option = if $width != null or ($width == null and $height == null) {
    $"-w=($factor)"
  } else {
    $"-h=($factor)"
  }
  print $"Waydroid: ($size.width)x($size.height) on a ($logical) output ($sizing_option), margin ($margin)px, strut ($strut)px"

  let composers = (^pgrep -f '/vendor/bin/hw/[a]ndroid.hardware.graphics.composer@2.1-service' | complete)
  if $composers.exit_code == 0 {
    $composers.stdout
    | lines
    | each {|pid| ^kill $pid | complete | ignore }
  }
}
