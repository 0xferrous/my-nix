#!/usr/bin/env nu
# Synchronize direct, top-level GitHub flake inputs across local flakes.
#
# README
# ======
#
# Find direct inputs shared by lockfile roots; nested dependency inputs are not
# considered:
#   flake-utils intersection . ./pkgs/frs-nvim
#
# Update comma-separated inputs in the canonical flake, then lock those exact
# revisions in every target flake:
#   flake-utils nixpkgs,nix-wrapper-modules . ./pkgs/frs-nvim
#
# Arguments are INPUTS CANONICAL_FLAKE TARGET_FLAKE..., where INPUTS is a
# comma-separated list. The canonical input must resolve directly from
# nodes.root.inputs in its flake.lock. Only GitHub-locked inputs are supported.

# Return the root input names from a flake's lockfile.
def root-input-names [flake: string] {
  let lock_path = ($flake | path join "flake.lock")
  if not ($lock_path | path exists) {
    error make {
      msg: $"missing lockfile: ($lock_path)"
      help: "each flake must already have a flake.lock"
    }
  }

  let lock = (open $lock_path | from json)
  $lock.nodes.root.inputs | columns
}

# Return a GitHub flake reference for the exact revision locked by an input.
def locked-github-url [flake: string, input: string] {
  let lock_path = ($flake | path join "flake.lock")
  if not ($lock_path | path exists) {
    error make {
      msg: $"missing lockfile: ($lock_path)"
      help: "the canonical flake must already have a flake.lock"
    }
  }

  let lock = (open $lock_path | from json)
  let node_name = ($lock.nodes.root.inputs | get $input)
  if ($node_name | describe) != "string" {
    error make {
      msg: $"canonical input does not resolve directly to a lock node: ($input)"
      help: "choose an input defined directly by the canonical flake"
    }
  }

  let locked = ($lock.nodes | get $node_name | get locked)
  if $locked.type != "github" {
    error make {
      msg: $"unsupported locked input type: ($locked.type)"
      help: "this script currently synchronizes GitHub inputs"
    }
  }

  $"github:($locked.owner)/($locked.repo)/($locked.rev)"
}

# List input names shared by every supplied flake.
def "main intersection" [first_flake: string, ...other_flakes: string] {
  if ($other_flakes | is-empty) {
    error make {
      msg: "at least two flakes are required"
      help: "run with --help for usage"
    }
  }

  mut common = (root-input-names $first_flake)
  for flake in $other_flakes {
    let inputs = (root-input-names $flake)
    $common = ($common | where { |input| $input in $inputs })
  }

  $common | sort
}

# Update canonical inputs, then synchronize each one to target flakes.
def main [input_names: string, canonical_flake: string, ...target_flakes: string] {
  if ($target_flakes | is-empty) {
    error make {
      msg: "at least one target flake is required"
      help: "run with --help for usage"
    }
  }

  let inputs = (
    $input_names
    | split row ','
    | each { str trim }
    | where { |input| not ($input | is-empty) }
  )
  if ($inputs | is-empty) {
    error make {
      msg: "at least one input name is required"
      help: "use a comma-separated list, for example nixpkgs,nix-wrapper-modules"
    }
  }

  for input in $inputs {
    print $"updating canonical input: ($canonical_flake)::($input)"
    ^nix flake update --flake $canonical_flake $input

    let source_url = (locked-github-url $canonical_flake $input)
    print $"synchronizing targets to ($source_url)"

    for target_flake in $target_flakes {
      print $"locking ($target_flake)::($input)"
      ^nix flake lock --override-input $input $source_url $target_flake
    }
  }
}
