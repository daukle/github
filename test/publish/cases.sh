#!/bin/sh
# Every case runs against a real daukle, and the one that composes a command
# provisions a real gh. A stub of either would be testing the stub.
#
# NOTHING HERE PUBLISHES, on any runner, ever. The composing case points --repo
# at a repository that does not exist, so the argv is asserted from daukle's own
# --verbose trace before anything leaves the machine and the call then fails at
# the API with nothing to have written to.
#
# A case carrying "needs-tools" provisions about 15 MB of gh and is skipped
# unless DAUKLE_PUBLISH_E2E=1. CI sets it on every runner: composing the right
# command is the whole of what this plugin does, and a run that skipped it
# proved only that bad input is refused.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work="$root/test/publish/.work"

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

# The token every case reads. A publish that reached GitHub with this would be
# rejected; the cases that compose a command are pointed at a repository that
# does not exist, so it never gets that far.
DAUKLE_PUBLISH_PROBE_TOKEN=not-a-real-token
export DAUKLE_PUBLISH_PROBE_TOKEN

passed=0
failed=0
skipped=0

fail() {
  echo "FAIL $1: $2" >&2
  failed=$((failed + 1))
}

run_case() {
  case_dir=$1
  name=$(basename "$case_dir")

  if [ -f "$case_dir/needs-tools" ] && [ "${DAUKLE_PUBLISH_E2E:-}" != "1" ]; then
    echo "skip $name: set DAUKLE_PUBLISH_E2E=1 to provision gh here" >&2
    skipped=$((skipped + 1))
    return
  fi

  sandbox="$work/$name"
  rm -rf "$sandbox"
  mkdir -p "$(dirname "$sandbox")"
  cp -R "$case_dir" "$sandbox"
  rm -f "$sandbox/expect-error.txt" "$sandbox/expect-output.txt" "$sandbox/needs-tools" \
        "$sandbox/task"
  mkdir -p "$sandbox/plugins"
  cp "$root/plugin.lua" "$sandbox/plugins/plugin.lua"
  cp -R "$root/lib" "$sandbox/plugins/lib"

  command=publish
  [ -f "$case_dir/task" ] && command=$(cat "$case_dir/task")

  if [ -f "$case_dir/expect-error.txt" ]; then
    if (cd "$sandbox" && "$daukle" $command >stdout.txt 2>stderr.txt); then
      fail "$name" "expected a failure, got success"
      return
    fi
    # ONE clause per file, not several: this greps -F with the whole file as the
    # pattern, and grep reads several lines as alternatives, so a two-line file
    # would assert an OR while reading like an AND.
    clause=$(cat "$case_dir/expect-error.txt")
    if ! grep -qF "$clause" "$sandbox/stderr.txt" "$sandbox/stdout.txt"; then
      echo "--- stderr ---" >&2
      tail -20 "$sandbox/stderr.txt" >&2
      fail "$name" "message does not carry: $clause"
      return
    fi
    passed=$((passed + 1))
    return
  fi

  if ! (cd "$sandbox" && "$daukle" $command >stdout.txt 2>stderr.txt); then
    echo "--- stderr ---" >&2
    tail -20 "$sandbox/stderr.txt" >&2
    fail "$name" "$command failed"
    return
  fi

  # One literal per line the run's own output must carry, each asserted
  # separately, which is what makes this an AND where expect-error.txt is not.
  if [ -f "$case_dir/expect-output.txt" ]; then
    if ! grep -q . "$case_dir/expect-output.txt"; then
      fail "$name" "expect-output.txt is empty, so this case asserts nothing"
      return
    fi
    while IFS= read -r clause || [ -n "$clause" ]; do
      [ -n "$clause" ] || continue
      if ! grep -qF "$clause" "$sandbox/stdout.txt" "$sandbox/stderr.txt"; then
        echo "--- stderr ---" >&2
        tail -20 "$sandbox/stderr.txt" >&2
        fail "$name" "output does not carry: $clause"
        return
      fi
    done < "$case_dir/expect-output.txt"
  fi

  passed=$((passed + 1))
}

rm -rf "$work"
for case_dir in "$root"/test/publish/cases/*/; do
  [ -d "$case_dir" ] || continue
  run_case "${case_dir%/}"
done

echo "$passed passed, $failed failed, $skipped skipped"
[ "$failed" -eq 0 ]
