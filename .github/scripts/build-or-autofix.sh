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
timeout_seconds=${AUTOFIX_TIMEOUT:-2700}
log_line_limit=200

cd "$(git rev-parse --show-toplevel)"

log=$(mktemp)
tail_context=$(mktemp)
trap 'rm -f "$log" "$tail_context"' EXIT

build() {
  nix build ".#$attribute" --no-link --print-build-logs >"$log" 2>&1
}

# Substitution chatter and flake-config warnings can fill the whole line
# budget before the actual error, so drop them before showing or attaching a
# log.
trim_log() {
  grep -v -E '^(copying path |unpacking .* into the Git cache|these [0-9]+ paths will be fetched|warning: ignoring untrusted flake configuration setting|Pass .--accept-flake-config. to trust it)' "$1" |
    sed -e '/^$/d' |
    tail -n "$log_line_limit"
}

show_tail() {
  printf '===== last %s lines of the build log =====\n' "$log_line_limit"
  trim_log "$log"
  printf '==========================================\n'
}

package_context() {
  pkg_file=$(nix eval --raw ".#$attribute.meta.position" 2>/dev/null |
    sed -E 's#^.*/(pkgs/[^:]+):[0-9]+$#\1#') || true
  [ -n "${pkg_file:-}" ] || pkg_file="(unknown, find it under pkgs/)"
  pkg_version=$(nix eval --raw ".#$attribute.version" 2>/dev/null) || pkg_version="(unknown)"
  # The bump is HEAD; show what it changed so the agent does not have to
  # reverse-engineer the diff from the failure.
  bump_diff=$(git show --format= --unified=1 HEAD -- pkgs 2>/dev/null | head -60) || bump_diff=""
  [ -n "$bump_diff" ] || bump_diff="(the bump did not change any file under pkgs/)"
}

bot_name="github-actions[bot]"
bot_email="41898282+github-actions[bot]@users.noreply.github.com"

# Commit only what the pull request can carry, so the repair shows up as its
# own commit instead of being folded into the bump.
commit_pkgs() {
  local message=$1
  if [ -z "$(git status --porcelain -- pkgs)" ]; then
    return 0
  fi
  git add -A -- pkgs
  git -c user.name="$bot_name" -c user.email="$bot_email" commit -q -m "$message"
}

pr_body_note() {
  if [ -n "${PR_BODY_FILE:-}" ] && [ -f "$PR_BODY_FILE" ]; then
    printf '%s\n' "$1" >>"$PR_BODY_FILE"
  fi
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
  trim_log "$log" >"$tail_context"
  before_attempt=$(changed_paths)
  package_context

  prompt=$(
    cat <<PROMPT
You are repairing a Nix package in the my-nix repository.

Package: $attribute (flake attribute \`.#$attribute\`, version $pkg_version)
File:    $pkg_file

The version bump changed:

$bump_diff

The build command is:

    nix build .#$attribute --no-link --print-build-logs

Its failure output is attached. Read it first, then read AGENTS.md and the
package file before changing anything.

Context:
- This is repair attempt $attempt of $attempts. If the build still fails when you
  stop, the workflow discards every change under \`pkgs/\` and opens a draft pull
  request for a human, so keep going until the build passes.
- \`nix build\`, \`nix eval\`, \`nix log\` and \`nix store prefetch-file\` work here;
  the binary caches are configured and the store is warm.
- A full Rust or Electron build takes minutes. Batch related edits, inspect
  with \`nix eval\`, \`nix log\` or \`nix build --keep-failed\` instead of rebuilding
  on a guess, and do not repeat a build that already failed with the same
  error.
- The harness rebuilds after you stop; that rebuild is a cache hit if your own
  build succeeded.

Rules:
- Only edit files under \`pkgs/\`. Do not touch \`.github/\`, \`flake.nix\`,
  \`flake.lock\`, \`modules/\` or \`config/\`.
- Prefer the file that defines $attribute; touch shared helpers
  (\`pkgs/overlay.nix\`, \`pkgs/update-arch-hash.sh\`) only if the fix belongs there.
- Keep the bumped version. Do not downgrade, revert to the old release, or
  disable tests, checks or features to get a green build.
- Do not run \`git commit\`, \`git push\`, \`git checkout\` or \`git clean\`; the
  harness commits for you.

Usual causes after a bump, and their fixes:
- Fixed-output hash mismatch: use the \`got: sha256-...\` value from the error, or
  \`nix store prefetch-file --json --hash-type sha256 <url>\`, and write SRI
  hashes. Other architectures' hashes live in the same file; prefetch them the
  same way instead of guessing or copying.
- Release asset renamed or moved: list the release with
  \`curl -s https://api.github.com/repos/<owner>/<repo>/releases/tags/v<version>\`
  and follow the current asset names.
- Patch no longer applies: upstream moved or changed the code. Get the new
  source (\`nix build .#$attribute.src --no-link --print-out-paths\`), regenerate
  the patch under \`pkgs/\` against it, or drop it if upstream fixed the issue.
- The package patches a bundled artifact by pattern (asar/perl/sed): extract the
  artifact (\`dpkg-deb -x\`, \`tar -xf\`, \`unzip\`) and re-derive the pattern from
  the new build; keep replacement lengths equal where the file requires it.
- Install or version assertions: update the expected version or output.
- New native dependency: add it to \`nativeBuildInputs\` or \`buildInputs\`.

Finish only after \`nix build .#$attribute --no-link --print-build-logs\` passes.
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

  if [ -z "$(git status --porcelain -- pkgs)" ]; then
    printf 'autofix attempt %d: nothing changed under pkgs/, stopping\n' "$attempt"
    break
  fi

  printf 'autofix attempt %d: formatting and rebuilding\n' "$attempt"
  nix fmt >/dev/null 2>&1 || true

  if build; then
    printf '::notice::autofix repaired .#%s on attempt %d\n' "$attribute" "$attempt"
    commit_pkgs "fix($attribute): repair build after update

Automated repair by ${AUTOFIX_MODEL:-the configured agent} on attempt $attempt of $attempts."
    pr_body_note "The bumped package did not build as-is; commit 2 repairs it.

The repair was written by an automated agent (\`${AUTOFIX_MODEL:-configured model}\`)
on attempt $attempt of $attempts. Review those package changes before merging."
    exit 0
  fi

  printf 'autofix attempt %d: still failing\n' "$attempt"
  show_tail
done

# Drop the agent's dead ends so the branch is the plain bump, which is the
# useful starting point for whoever finishes the fix.
git clean -fdq -- pkgs >/dev/null 2>&1 || true
git checkout -- . >/dev/null 2>&1 || true

note=$(printf 'The bumped package does not build and the automated repair did not
succeed after %d attempt(s) (%s).

<details><summary>Last build output</summary>

```
%s
```

</details>' "$attempts" "${AUTOFIX_MODEL:-configured model}" "$(trim_log "$log" | tail -n 60)")
pr_body_note "$note"

printf '::warning::.#%s still fails to build after %d autofix attempt(s); opened as a draft for a human\n' "$attribute" "$attempts"
exit 1
