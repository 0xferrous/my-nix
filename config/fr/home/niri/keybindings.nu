# Print effective, explicitly titled Niri binds as JSON for the Noctalia
# launcher. Includes are processed in place, and later binds replace earlier
# binds with the same key, matching niri-config's bind merge behavior.

def merge-binds [current: list<record>, incoming: list<record>] {
  mut merged = $current
  for bind in $incoming {
    $merged = ($merged | where key != $bind.key)
    $merged = ($merged | append $bind)
  }
  $merged
}

def parse-bind-section [lines: list<string>] {
  let source = ($lines | str join "\n"
    | str replace -ra 'hotkey-overlay-title\s*=\s*null' 'hotkey-overlay-title="__niri_null__"'
    | str replace -ra '=\s*true\b' '=#true'
    | str replace -ra '=\s*false\b' '=#false')
  let nodes = ($source | from kdl)
  let section = ($nodes | where name == "binds" | first)
  $section.children | each {|bind|
    let title = ($bind.props | get -o "hotkey-overlay-title")
    let action = if ($bind.children | is-empty) { "" } else { $bind.children.0.name }
    {
      key: $bind.name,
      title: (if $title == "__niri_null__" { null } else { $title }),
      action: $action,
    }
  }
}

def parse-file [path: string, stack: list<string>] {
  let file_path = ($path | path expand)
  if ($stack | any {|item| $item == $file_path}) or ($stack | length) >= 100 {
    return []
  }

  let next_stack = ($stack | append $file_path)
  let lines = (open --raw $file_path | lines)
  mut binds = []
  mut section_lines = []
  mut in_binds = false
  mut depth = 0

  for line in $lines {
    let trimmed = ($line | str trim)

    if not $in_binds {
      # Niri processes includes at their position in the containing file.
      if ($trimmed | str starts-with 'include ') {
        let include_node = ($trimmed | from kdl | first)
        let include_path = ($file_path | path dirname | path join $include_node.args.0)
        # Generated includes such as noctalia.kdl may not exist until Noctalia
        # has written them; skip them instead of failing the whole listing.
        if ($include_path | path exists) {
          let included = (parse-file $include_path $next_stack)
          $binds = (merge-binds $binds $included)
        }
        continue
      }

      if ($trimmed | str starts-with 'binds {') {
        $in_binds = true
        $depth = 0
        $section_lines = []
      } else {
        continue
      }
    }

    $section_lines = ($section_lines | append $line)

    # Ignore braces in quoted strings and line comments while finding the end
    # of this KDL block. The actual bind nodes are parsed by Nushell's KDL
    # parser, not extracted with regular expressions.
    let structure_line = ($line | str replace -ra '"(?:\\.|[^"\\])*"' '""' | str replace -r '//.*$' '')
    $depth = $depth + (($structure_line | split row '{' | length) - 1)
    $depth = $depth - (($structure_line | split row '}' | length) - 1)

    if $depth == 0 {
      let section_binds = (parse-bind-section $section_lines)
      $binds = (merge-binds $binds $section_binds)
      $section_lines = []
      $in_binds = false
    }
  }

  $binds
}

let config_home = ($env.XDG_CONFIG_HOME? | default ($env.HOME | path join '.config'))
let config_path = ($env.NIRI_CONFIG? | default ($config_home | path join 'niri' 'config.kdl'))
parse-file $config_path [] | to json --indent 0
