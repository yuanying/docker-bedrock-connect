#!/usr/bin/env bash
# Decides whether the weekly release has anything to release.
#
#   next-release.sh <path>...
#
# The latest release is the highest tag of the form vX.Y.Z; tags of any other
# form (v0.17.0.1, v1.0.0-rc1) are not releases and are ignored. A release is
# due when one of the given paths differs between that tag and HEAD, and is
# then the next patch version. The result is printed as key=value lines and,
# under GitHub Actions, also written to GITHUB_OUTPUT.
set -euo pipefail

if (( $# == 0 )); then
  echo "usage: $0 <path>..." >&2
  exit 2
fi

latest="$(git tag --list 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)"
if [[ -z "$latest" ]]; then
  echo "no tag of the form vX.Y.Z; the first release is tagged by hand" >&2
  exit 1
fi

result="latest=$latest"
if git diff --quiet "$latest" HEAD -- "$@"; then
  result+=$'\nrelease=false'
else
  IFS=. read -r major minor patch <<< "${latest#v}"
  version="$major.$minor.$((patch + 1))"
  result+=$'\nrelease=true'
  result+=$'\n'"version=$version"
  result+=$'\n'"tag=v$version"
fi

echo "$result"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "$result" >> "$GITHUB_OUTPUT"
fi
