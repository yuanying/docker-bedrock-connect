#!/usr/bin/env bash
# Checks next-release.sh against throwaway repositories. Run from anywhere:
#   .github/scripts/test-next-release.sh
set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/next-release.sh"
failures=0

# g runs git in the given directory.
g() { local d="$1"; shift; (cd "$d" && git "$@"); }

# new_repo creates an empty repository with one commit holding the Dockerfile.
new_repo() {
  dir="$(mktemp -d)"
  g "$dir" init -q -b main
  g "$dir" config user.email test@example.com
  g "$dir" config user.name test
  echo 'FROM scratch' > "$dir/Dockerfile"
  g "$dir" add Dockerfile
  g "$dir" commit -q -m initial
  echo "$dir"
}

commit_file() {
  mkdir -p "$(dirname "$1/$2")"
  echo "$RANDOM" >> "$1/$2"
  g "$1" add "$2"
  g "$1" commit -q -m "change $2"
}

expect() {
  local name="$1" want="$2" got="$3"
  if [[ "$got" == "$want" ]]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name"
    echo "  want: $(echo "$want" | tr '\n' ' ')"
    echo "  got:  $(echo "$got" | tr '\n' ' ')"
    failures=$((failures + 1))
  fi
}

run() {
  (cd "$1" && shift && GITHUB_OUTPUT='' "$script" "$@")
}

repo="$(new_repo)"
g "$repo" tag v0.0.1
commit_file "$repo" Dockerfile
expect "a change to a listed path releases the next patch" \
  "$(printf 'latest=v0.0.1\nrelease=true\nversion=0.0.2\ntag=v0.0.2')" \
  "$(run "$repo" Dockerfile custom_servers.json)"

repo="$(new_repo)"
g "$repo" tag v0.0.1
commit_file "$repo" .github/workflows/docker.yml
commit_file "$repo" renovate.json
expect "changes outside the listed paths release nothing" \
  "$(printf 'latest=v0.0.1\nrelease=false')" \
  "$(run "$repo" Dockerfile custom_servers.json)"

repo="$(new_repo)"
g "$repo" tag v0.0.1
expect "no commit since the tag releases nothing" \
  "$(printf 'latest=v0.0.1\nrelease=false')" \
  "$(run "$repo" Dockerfile custom_servers.json)"

repo="$(new_repo)"
g "$repo" tag v0.9.0
commit_file "$repo" Dockerfile
g "$repo" tag v0.10.0
g "$repo" tag v0.17.0.1
g "$repo" tag v1.0.0-rc1
g "$repo" tag latest
commit_file "$repo" custom_servers.json
expect "the latest tag is the highest vX.Y.Z by version, others are ignored" \
  "$(printf 'latest=v0.10.0\nrelease=true\nversion=0.10.1\ntag=v0.10.1')" \
  "$(run "$repo" Dockerfile custom_servers.json)"

repo="$(new_repo)"
g "$repo" tag v0.17.0.1
if run "$repo" Dockerfile >/dev/null 2>&1; then
  expect "no vX.Y.Z tag is an error" "exit non-zero" "exit 0"
else
  expect "no vX.Y.Z tag is an error" "x" "x"
fi

repo="$(new_repo)"
g "$repo" tag v0.0.1
commit_file "$repo" Dockerfile
out="$(mktemp)"
(cd "$repo" && GITHUB_OUTPUT="$out" "$script" Dockerfile >/dev/null)
expect "the result is also written to GITHUB_OUTPUT" \
  "$(printf 'latest=v0.0.1\nrelease=true\nversion=0.0.2\ntag=v0.0.2')" \
  "$(cat "$out")"

if (( failures > 0 )); then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
