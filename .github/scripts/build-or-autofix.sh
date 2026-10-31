#!/usr/bin/env bash
# Build one flake package and, when the build fails, let a coding agent try to
# repair the package expression before giving up.
#
# Usage: build-or-autofix.sh <attribute>
#
# Environment:
#   AUTOFIX_ATTEMPTS  repair attempts after the first failure (default 3,
#                     0 disables the agent and just builds)
#   AUTOFIX_MODEL     opencode model, e.g. `anthropic/claude-sonnet-4-5`
#   AUTOFIX_TIMEOUT   per-attempt agent timeout in seconds (default 1800)
#   PR_BODY_FILE      optional file that gets a note appended when the agent
#                     succeeded, so the pull request says what happened
#
# Exits 0 only when the package builds, so a caller that gates pull request
# creation on this step never publishes an unverified bump.
set -uo pipefail

attribute=${1:?usage: build-or-autofix.sh <attribute>}
attempts=${AUTOFIX_ATTEMPTS:-3}
timeout_seconds=${AUTOFIX_TIMEOUT:-1800}
log_line_limit=200

cd "$(git rev-parse --show-toplevel)"

log=$(mktemp)
tail_context=$(mktemp)
trap 'rm -f "$log" "$tail_context"' EXIT

build() {
  nix build ".#$attribute" --no-link --print-build-logs >"$log" 2>&1
}

show_tail() {
  printf '===== last %s lines of the build log =====\n' "$log_line_limit"
  tail -n "$log_line_limit" "$log"
  printf '==========================================\n'
}

changed_paths() {
  # `git status --porcelain` entries look like ` M path` or `R  old -> new`.
  git status --porcelain | sed -E 's/^...//; s/^.* -> //' | sort
}

agent_credentials_present() {
  local var
  for var in ANTHROPIC_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY GEMINI_API_KEY OPENCODE_API_KEY; do
    if [ -n "${!var:-}" ]; then
      return 0
    fi
  done
  return 1
}

printf 'building .#%s\n' "$attribute"
if build; then
  printf 'build succeeded\n'
  exit 0
fi

printf 'build failed\n'
show_tail

if [ "$attempts" -le 0 ]; then
  printf '::error::.#%s does not build and autofix is disabled\n' "$attribute"
  exit 1
fi
if ! command -v opencode >/dev/null 2>&1; then
  printf '::error::.#%s does not build and opencode is not installed\n' "$attribute"
  exit 1
fi
if ! agent_credentials_present; then
  printf '::error::.#%s does not build and no provider credentials are configured\n' "$attribute"
  exit 1
fi

model_args=()
if [ -n "${AUTOFIX_MODEL:-}" ]; then
  model_args=(--model "$AUTOFIX_MODEL")
fi

for ((attempt = 1; attempt <= attempts; attempt++)); do
  printf '::group::autofix attempt %d/%d\n' "$attempt" "$attempts"
  tail -n "$log_line_limit" "$log" >"$tail_context"
  before_attempt=$(changed_paths)

  prompt=$(
    cat <<PROMPT
The Nix package \`$attribute\` (flake attribute \`.#$attribute\`) fails to build
after a version bump. Repair the package expression.

The failure comes from:

    nix build .#$attribute --print-build-logs

Its output is attached; read it before changing anything.

Rules:
- Only edit files under \`pkgs/\`. Do not touch \`.github/\`, \`flake.nix\`,
  \`flake.lock\`, \`modules/\`, \`config/\` or anything else outside \`pkgs/\`.
- Keep the bumped version. Do not downgrade, revert to an older release, or
  disable tests, checks or features to get a green build.
- Prefer the smallest correct change in the style of the surrounding code, and
  follow the comments already in the package file plus AGENTS.md.
- Do not run \`git commit\`, \`git push\`, \`git checkout\` or \`git clean\`; the
  harness commits and rebuilds for you.
- You may read files, search the tree and run \`nix eval\`; do not start long
  builds, the harness rebuilds as soon as you finish.
PROMPT
  )

  timeout "$timeout_seconds" opencode run \
    --dir "$PWD" \
    --auto \
    --file "$tail_context" \
    "${model_args[@]}" \
    --title "autofix $attribute attempt $attempt" \
    "$prompt"
  agent_status=$?
  printf '::endgroup::\n'

  if [ "$agent_status" -ne 0 ]; then
    printf 'autofix attempt %d: agent exited %d\n' "$attempt" "$agent_status"
  fi

  # The pull request only commits `pkgs/`, so changes the agent makes outside
  # it would make a passing build unreproducible. Compare with the state
  # before the attempt so edits that were already dirty are left alone.
  stray=$(comm -13 <(printf '%s\n' "$before_attempt") <(changed_paths) | grep -v '^pkgs/' || true)
  if [ -n "$stray" ]; then
    printf '::warning::agent changed files outside pkgs/, reverting: %s\n' "$(tr '\n' ' ' <<<"$stray")"
    while IFS= read -r path; do
      if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
        git checkout -- "$path"
      else
        rm -f -- "$path"
      fi
    done <<<"$stray"
  fi

  if git diff --quiet -- pkgs; then
    printf 'autofix attempt %d: nothing changed under pkgs/, stopping\n' "$attempt"
    break
  fi

  printf 'autofix attempt %d: formatting and rebuilding\n' "$attempt"
  nix fmt >/dev/null 2>&1 || true

  if build; then
    printf '::notice::autofix repaired .#%s on attempt %d\n' "$attribute" "$attempt"
    if [ -n "${PR_BODY_FILE:-}" ] && [ -f "$PR_BODY_FILE" ]; then
      printf '\nThe bumped package did not build as-is and was repaired by an\nautomated agent on attempt %d of %d. Review the package changes before\nmerging.\n' \
        "$attempt" "$attempts" >>"$PR_BODY_FILE"
    fi
    exit 0
  fi

  printf 'autofix attempt %d: still failing\n' "$attempt"
  show_tail
done

printf '::error::.#%s still fails to build after %d autofix attempt(s)\n' "$attribute" "$attempts"
exit 1
