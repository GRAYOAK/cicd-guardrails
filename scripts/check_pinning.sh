#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/feedback.sh
source "${SCRIPT_DIR}/lib/feedback.sh"

PATH_ROOT="${1:-.}"

fb_init "CICD-SEC-08" "Action pinning check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-08-Ungoverned-Usage-of-3rd-Party-Services/"
fb_add_searched "Workflow and composite action files"
fb_add_searched "uses: references that are not pinned to a full 40-char SHA"
fb_add_searched "Disallowed refs such as tags, branches, latest, or missing @"

shopt -s nullglob
files=("$PATH_ROOT"/.github/workflows/*.yml "$PATH_ROOT"/.github/workflows/*.yaml)
while IFS= read -r action_file; do
  files+=("$action_file")
done < <(find "$PATH_ROOT/actions" -type f \\( -name "action.yml" -o -name "action.yaml" \\) 2>/dev/null || true)

if [[ ${#files[@]} -eq 0 ]]; then
  fb_set_status "SKIPPED"
  fb_add_remediation "No workflow or action files found; no action required."
  fb_summary
  exit "$(fb_exit_code false false)"
fi

for file in "${files[@]}"; do
  rel="${file#"$PATH_ROOT/"}"

  findings="$(awk '
    /^[[:space:]]*#/ { next }
    {
      line = $0
      sub(/#.*$/, "", line)
      if (line !~ /uses:/) next
      if (line ~ /uses:[[:space:]]*\.\//) next
      if (line ~ /@[0-9a-f]{40}[[:space:]]*$/) next
      print NR ": " $0
    }
  ' "$file")"

  if [[ -n "$findings" ]]; then
    while IFS= read -r match; do
      linenum="${match%%:*}"
      ref="$(echo "$match" | sed -E 's/^[0-9]+:[[:space:]]*//' | sed -E 's/.*uses:[[:space:]]*//')"
      fb_report "error" "Unpinned action reference '${ref}'." "$rel" "$linenum" \
        "Pin every third-party action to a full commit SHA."
    done <<<"$findings"
  fi
done

fb_auto_status false
if [[ "$FB_STATUS" != "PASS" ]]; then
  fb_add_remediation "Example: uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683"
  fb_add_remediation "Use automation to keep pinned SHAs updated."
else
  fb_add_remediation "No remediation needed."
fi

fb_summary
exit "$(fb_exit_code false false)"
