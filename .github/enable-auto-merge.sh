#!/usr/bin/env bash
set -euo pipefail

branch=$(gh api "repos/$GITHUB_REPOSITORY" --jq '.default_branch')
rules=$(gh api "repos/$GITHUB_REPOSITORY/rules/branches/$branch")
if ! jq -e '
  [.[] | select(.type == "required_status_checks")
    | .parameters.required_status_checks[]
    | select(.integration_id == 4138076) | .context]
  | index("nixbot/nix-eval") != null and index("nixbot/nix-build") != null
' <<<"$rules" >/dev/null; then
  echo "Nixbot evaluation and build checks must be required before enabling auto-merge." >&2
  exit 1
fi

gh pr merge --auto --squash "$PR_URL"
