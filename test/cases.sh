#!/bin/sh
# Every case is run against a real daukle, because this plugin's output is
# daukle.json_set's formatting and a stub of that verb would be testing the stub.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work="$root/test/.work"

daukle=${DAUKLE:-}
if [ -z "$daukle" ]; then
  for candidate in \
    "$root/.daukle/build/daukle" \
    "$root/.daukle/build/daukle.exe" \
    "$root/.daukle/build/Release/daukle.exe" \
    "$root/.daukle/build/Debug/daukle.exe"
  do
    [ -x "$candidate" ] && daukle=$candidate && break
  done
fi
if [ -z "$daukle" ] || [ ! -x "$daukle" ]; then
  echo "no daukle binary: set DAUKLE, or check out daukle/daukle into .daukle and build it" >&2
  exit 1
fi

passed=0
failed=0

fail() {
  echo "FAIL $1: $2" >&2
  failed=$((failed + 1))
}

run_case() {
  case_dir=$1
  name=$(basename "$case_dir")

  for manifest in "$case_dir"/daukle*.toml; do
    manifest_name=$(basename "$manifest")
    sandbox="$work/$name-$manifest_name"
    # A cache per case, so a case that fetches starts cold. Sharing the ambient
    # cache hid a real defect: this plugin's only daukle.env call sits inside
    # the cache callback, so on a warm cache it never runs and a missing env
    # declaration passes.
    case_cache="$sandbox.cache"
    rm -rf "$case_cache"
    rm -rf "$sandbox"
    mkdir -p "$(dirname "$sandbox")"
    cp -R "$case_dir" "$sandbox"
    rm -rf "$sandbox/expected" "$sandbox/expect-error.txt"
    cp "$root/plugin.lua" "$sandbox/plugins/plugin.lua"

    if [ -f "$case_dir/expect-error.txt" ]; then
      if (cd "$sandbox" && DAUKLE_CACHE_DIR="$case_cache" "$daukle" sync "$manifest_name" >stdout.txt 2>stderr.txt); then
        fail "$name/$manifest_name" "expected a failure, got success"
        continue
      fi
      clause=$(cat "$case_dir/expect-error.txt")
      if ! grep -qF "$clause" "$sandbox/stderr.txt" "$sandbox/stdout.txt"; then
        fail "$name/$manifest_name" "message does not carry: $clause"
        continue
      fi
      passed=$((passed + 1))
      continue
    fi

    # Twice, because applying twice must equal applying once for every case,
    # not only for the one a test remembered to say it about.
    if ! (cd "$sandbox" && DAUKLE_CACHE_DIR="$case_cache" "$daukle" sync "$manifest_name" >/dev/null 2>&1); then
      fail "$name/$manifest_name" "sync failed"
      continue
    fi
    if ! compare_expected "$case_dir" "$sandbox" "$name/$manifest_name (first)"; then
      continue
    fi
    if ! (cd "$sandbox" && DAUKLE_CACHE_DIR="$case_cache" "$daukle" sync "$manifest_name" >/dev/null 2>&1); then
      fail "$name/$manifest_name" "second sync failed"
      continue
    fi
    if ! compare_expected "$case_dir" "$sandbox" "$name/$manifest_name (second)"; then
      continue
    fi
    passed=$((passed + 1))
  done
}

compare_expected() {
  expected_root=$1/expected
  actual_root=$2
  label=$3
  ok=0
  # An empty expected/ would compare nothing and pass, which is the one way a
  # case can look green while asserting nothing at all.
  if [ -z "$(cd "$expected_root" && find . -type f)" ]; then
    fail "$label" "expected/ holds no files, so this case asserts nothing"
    return 1
  fi
  for expected in $(cd "$expected_root" && find . -type f); do
    if ! cmp -s "$expected_root/$expected" "$actual_root/$expected"; then
      fail "$label" "$expected differs"
      diff -u "$expected_root/$expected" "$actual_root/$expected" >&2 || true
      ok=1
    fi
  done
  return $ok
}

#
# The published release asset and the file it was built from. These used to live
# in two repositories, where they could legitimately differ and the example's own
# ABOUT.md said the comparison was deliberately not made; in one repository a
# release and its source move in the same commit, so a difference is a defect.
# Same shape, and the same reason, as core's wrapper_example_matches_wrapper.
check_release_asset() {
  label=release-asset-matches-producer
  committed="$root/examples/github-release-source/producer/daukle.toml"
  # Derived rather than written here: the example declares `tag = "greeter-{version}"`,
  # so a hardcoded tag would keep checking the old release after a version bump.
  tag=$(sed -n 's/^version = "\(.*\)"$/\1/p' "$committed" | head -1)
  url="https://github.com/daukle/github/releases/download/greeter-$tag/daukle.toml"
  downloaded="$work/$label.toml"
  mkdir -p "$work"

  if ! curl -fsSL -o "$downloaded" "$url"; then
    fail "$label" "could not fetch $url"
    return
  fi
  if ! cmp -s "$downloaded" "$committed"; then
    fail "$label" "the published asset differs from producer/daukle.toml"
    diff -u "$committed" "$downloaded" >&2 || true
    return
  fi
  passed=$((passed + 1))
}

rm -rf "$work"
for case_dir in "$root"/test/cases/*/; do
  run_case "${case_dir%/}"
done

# Gated with the examples, because it is the same real network fetch they are.
if [ "${DAUKLE_EXAMPLE_E2E:-}" = "1" ]; then
  check_release_asset
else
  echo "skip release-asset-matches-producer: set DAUKLE_EXAMPLE_E2E=1"
fi

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
