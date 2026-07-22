# Preserve a remote SSH-kitten directory across --hold-after-ssh fallback.
#
# The remote shell publishes its PWD relative to its home directory. When the
# SSH kitten exits, the local fallback shell resolves that relative path below
# its own home directory, provided it exists.

def _kitty_remote_control [...args: string] {
  # SSH kitten exposes its bootstrap helper here. It is not necessarily named
  # `kitten` or available on PATH on the remote machine.
  let helper = if (which kitten | is-not-empty) {
    "kitten"
  } else if $env.SSH_KITTEN_KITTY_DIR? != null {
    $"($env.SSH_KITTEN_KITTY_DIR)/kitten"
  } else {
    null
  }

  if $helper != null {
    do -i { run-external $helper "@" ...$args }
  }
}

def _kitty_user_var [name: string] {
  _kitty_remote_control set-user-vars
  | lines
  | where { |line| $line starts-with $"($name)=" }
  | each { |line| $line | str replace $"($name)=" "" }
  | get 0?
}

def _kitty_set_user_var [name: string, value: string] {
  if (($env.KITTY_WINDOW_ID? != null) and ($env.KITTY_LISTEN_ON? != null)) {
    _kitty_remote_control set-user-vars $"($name)=($value)" | ignore
  }
}

def _kitty_clear_user_var [name: string] {
  if (($env.KITTY_WINDOW_ID? != null) and ($env.KITTY_LISTEN_ON? != null)) {
    _kitty_remote_control set-user-vars $name | ignore
  }
}

def _kitty_publish_remote_cwd [] {
  # The kitten bootstrap unsets KITTY_SSH_KITTEN_DATA_DIR before starting the
  # login shell. SSH_KITTEN_KITTY_DIR remains as the remote-session marker.
  if $env.SSH_KITTEN_KITTY_DIR? == null {
    return
  }

  let home = ($env.HOME | path expand)
  let cwd = ($env.PWD | path expand)
  let relative_cwd = if $cwd == $home {
    "."
  } else if ($cwd | str starts-with $"($home)/") {
    $cwd | str substring (($home | str length) + 1)..
  } else {
    null
  }

  if $relative_cwd == null {
    _kitty_clear_user_var remote_home_relative_cwd
  } else {
    _kitty_set_user_var remote_home_relative_cwd $relative_cwd
  }
}

def --env _kitty_restore_local_cwd [] {
  # Only Kitty windows can have a value to consume. In particular, do not run
  # the `kitten` helper during ordinary agent shell startup.
  if (($env.KITTY_WINDOW_ID? == null) or ($env.KITTY_LISTEN_ON? == null)) {
    return
  }

  # Do not consume the value in the remote shell that publishes it.
  if $env.SSH_KITTEN_KITTY_DIR? != null {
    return
  }

  let relative_cwd = (_kitty_user_var remote_home_relative_cwd)
  if $relative_cwd == null {
    return
  }

  # Consume it once, even if the path is invalid on this host.
  _kitty_clear_user_var remote_home_relative_cwd

  if ($relative_cwd | str starts-with "/") or ($relative_cwd | split row "/" | any { |part| $part == ".." }) {
    return
  }

  let target = if $relative_cwd == "." {
    $env.HOME
  } else {
    $env.HOME | path join $relative_cwd
  }
  if ($target | path exists) {
    cd $target
  }
}

# The fallback shell loads this file before its first prompt.
_kitty_restore_local_cwd

# Publish after every remote prompt, so it reflects remote `cd` commands.
$env.config.hooks.pre_prompt = (
  $env.config.hooks.pre_prompt? | default [] | append {|| _kitty_publish_remote_cwd }
)
