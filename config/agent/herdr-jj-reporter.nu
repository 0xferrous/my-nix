#!/usr/bin/env nu

const report_ttl_ms = 90000
const poll_interval = 15sec
const source = "fr:jj"
const token_name = "jj_status"


def jj_status_token [cwd: string] {
  let result = (
    do {
      ^jj --repository $cwd log --no-graph --revisions @ --template 'change_id.shortest() ++ " " ++ if(empty, "✓", "●")'
    } | complete
  )

  if $result.exit_code == 0 {
    let token = ($result.stdout | str trim)
    if ($token | is-empty) { null } else { $token }
  } else {
    null
  }
}


def report_token [workspace_id: string, token: string] {
  do {
    ^herdr workspace report-metadata $workspace_id --source $source --token $"($token_name)=($token)" --ttl-ms ($report_ttl_ms | into string)
  } | complete | ignore
}


def clear_token [workspace_id: string] {
  do {
    ^herdr workspace report-metadata $workspace_id --source $source --clear-token $token_name
  } | complete | ignore
}


mut reported_workspaces = []

loop {
  let pane_list = (do { ^herdr pane list } | complete)
  if $pane_list.exit_code != 0 {
    sleep $poll_interval
    continue
  }

  let panes = try {
    $pane_list.stdout | from json | get result.panes
  } catch {
    sleep $poll_interval
    continue
  }

  mut current_workspaces = []
  for workspace in ($panes | group-by workspace_id | transpose workspace_id panes) {
    let candidates = (
      $workspace.panes
      | each {|pane| [($pane.foreground_cwd?), ($pane.cwd?)] }
      | flatten
      | compact
      | uniq
    )
    let token = (
      $candidates
      | each {|cwd| jj_status_token $cwd }
      | compact
      | get 0?
    )

    if $token != null {
      report_token $workspace.workspace_id $token
      $current_workspaces = ($current_workspaces | append $workspace.workspace_id)
    } else if $workspace.workspace_id in $reported_workspaces {
      clear_token $workspace.workspace_id
    }
  }

  $reported_workspaces = $current_workspaces
  sleep $poll_interval
}
