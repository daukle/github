#!/bin/sh
# Every pinned digest, against the checksums.txt the cli/cli release publishes
# beside its assets.
#
# The cases provision gh for ONE host, the runner's own, which leaves the other
# four rows asserted by nothing. A transcribed digest is exactly the kind of
# claim this project keeps finding wrong, and this covers every row for one
# small GET.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
table="$root/lib/gh.lua"

if [ "${DAUKLE_PUBLISH_E2E:-}" != "1" ]; then
  echo "skip pins: set DAUKLE_PUBLISH_E2E=1 to check the pins against the cli/cli release" >&2
  exit 0
fi

version=$(sed -n 's/^local VERSION = "\([^"]*\)"$/\1/p' "$table")
if [ -z "$version" ]; then
  echo "pins: no VERSION in lib/gh.lua, so there is nothing to check against" >&2
  exit 1
fi

# The table's own spelling is the input, so a row added without a digest cannot
# pass by being skipped: it is not parsed, and the count below then disagrees
# with the number of rows in the file.
rows=$(sed -n 's/^  \["\([^"]*\)"\] *= *"\([0-9a-f]\{64\}\)",$/\1 \2/p' "$table")
declared=$(grep -c '^  \["' "$table")
parsed=$(printf '%s\n' "$rows" | grep -c . || true)

if [ "$parsed" -eq 0 ] || [ "$parsed" -ne "$declared" ]; then
  echo "pins: $declared rows in lib/gh.lua and $parsed parsed; a row this cannot read is a row" \
       "nothing checks" >&2
  exit 1
fi

published=$(curl -sSL --fail \
  "https://github.com/cli/cli/releases/download/v$version/gh_${version}_checksums.txt" || true)
if [ -z "$published" ]; then
  echo "pins: the checksums.txt for v$version returned nothing" >&2
  exit 1
fi

# host/arch as lib/gh.lua keys it, to the asset name the release publishes.
asset_for() {
  case $1 in
    linux/x86_64)   echo "gh_${version}_linux_amd64.tar.gz" ;;
    linux/aarch64)  echo "gh_${version}_linux_arm64.tar.gz" ;;
    macos/x86_64)   echo "gh_${version}_macOS_amd64.zip" ;;
    macos/aarch64)  echo "gh_${version}_macOS_arm64.zip" ;;
    windows/x86_64) echo "gh_${version}_windows_amd64.zip" ;;
    *) echo "" ;;
  esac
}

failed=0
checked=0
# No pipeline: a `while read` fed by one would run in a subshell on every POSIX
# sh and lose the counters, leaving a check that is always green.
old_ifs=$IFS
IFS='
'
for row in $rows; do
  IFS=$old_ifs
  key=${row%% *}
  pinned=${row##* }
  asset=$(asset_for "$key")

  if [ -z "$asset" ]; then
    echo "FAIL $key: this script knows no asset name for that host, so the row is unchecked" >&2
    failed=$((failed + 1))
  else
    actual=$(printf '%s\n' "$published" | awk -v want="$asset" '$2 == want { print $1 }')
    if [ -z "$actual" ]; then
      echo "FAIL $key: the release publishes no $asset" >&2
      failed=$((failed + 1))
    elif [ "$actual" != "$pinned" ]; then
      echo "FAIL $key: pinned $pinned, the release publishes $actual" >&2
      failed=$((failed + 1))
    else
      checked=$((checked + 1))
    fi
  fi
  IFS='
'
done
IFS=$old_ifs

echo "$checked of $declared pinned hosts match the gh $version release, $failed failed"
[ "$failed" -eq 0 ]
