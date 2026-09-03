#!/usr/bin/env bash
# Report total GitHub release download counts for Kanto-Reforged.
set -euo pipefail

REPO="1Jamie/Kanto-Reforged"
VERBOSE=0
JSON=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Fetch download counts for all GitHub release assets and print the total.

Options:
  --repo OWNER/NAME   GitHub repo (default: ${REPO})
  -v, --verbose       Show per-release breakdown
  --json              Print machine-readable JSON summary
  -h, --help          Show this help

Requires: gh (GitHub CLI), authenticated or unauthenticated for public repos.
EOF
}

require_gh() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh (GitHub CLI) is required but not installed." >&2
    echo "Install: https://cli.github.com/" >&2
    exit 1
  fi
}

fetch_releases_json() {
  gh api "repos/${REPO}/releases" --paginate
}

print_verbose_breakdown() {
  gh api "repos/${REPO}/releases" --paginate \
    --jq '.[] | select(.assets | length > 0) | [.tag_name, ([.assets[]?.download_count // 0] | add)] | @tsv' \
    | sort -t$'\t' -k1,1V \
    | awk -F'\t' '
      BEGIN {
        printf "%-12s %10s\n", "Release", "Downloads"
        printf "%-12s %10s\n", "-------", "---------"
      }
      {
        release_total += $2
        printf "%-12s %10d\n", $1, $2
      }
      END {
        printf "%-12s %10s\n", "-------", "---------"
        printf "%-12s %10d\n", "Total", release_total
      }'
}

print_json_summary() {
  gh api "repos/${REPO}/releases" --paginate --jq '
    [
      .[] | {
        tag: .tag_name,
        published_at: .published_at,
        downloads: ([.assets[]?.download_count // 0] | add // 0),
        assets: [.assets[]? | {name: .name, downloads: .download_count}]
      }
    ] as $releases
    | {
        repo: "'"${REPO}"'",
        release_count: ($releases | length),
        total_downloads: ($releases | map(.downloads) | add // 0),
        releases: $releases
      }
  '
}

print_summary() {
  local total release_count

  total="$(gh api "repos/${REPO}/releases" --paginate \
    --jq '[.[].assets[]?.download_count // 0] | add // 0')"
  release_count="$(gh api "repos/${REPO}/releases" --paginate \
    --jq '[.[] | select(.assets | length > 0)] | length')"

  echo "Repository:       ${REPO}"
  echo "Releases w/assets: ${release_count}"
  echo "Total downloads:   ${total}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    --json)
      JSON=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_gh

if [[ "$JSON" -eq 1 ]]; then
  print_json_summary
elif [[ "$VERBOSE" -eq 1 ]]; then
  print_verbose_breakdown
else
  print_summary
fi
