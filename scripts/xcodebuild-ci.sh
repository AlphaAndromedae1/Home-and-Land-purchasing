#!/usr/bin/env bash
# Runs xcodebuild with its full output saved to a log file, prints a short
# summary, and turns compiler errors and test failures into GitHub annotations.
#
# Usage: scripts/xcodebuild-ci.sh <log-file> <xcodebuild arguments...>
set -uo pipefail

log_file="$1"
shift

xcodebuild "$@" >"$log_file" 2>&1
status=$?

grep -E "Executed [0-9]+ tests?|\*\* (BUILD|TEST|ARCHIVE) (SUCCEEDED|FAILED) \*\*" "$log_file" | tail -n 5 || true

if [ "$status" -ne 0 ]; then
  python3 - "$log_file" <<'PY'
import os
import re
import sys

workspace = os.environ.get("GITHUB_WORKSPACE", "").rstrip("/") + "/"
pattern = re.compile(r"^(/[^:]+):(\d+):(?:(\d+):)? error: (.*)$")
seen = set()
generic = []

with open(sys.argv[1], errors="replace") as handle:
    for raw in handle:
        line = raw.rstrip("\n")
        match = pattern.match(line)
        if match:
            path, row, col, message = match.groups()
            key = (path, row, message)
            if key in seen:
                continue
            seen.add(key)
            rel = path[len(workspace):] if workspace != "/" and path.startswith(workspace) else path
            location = f"file={rel},line={row}" + (f",col={col}" if col else "")
            message = message.replace("%", "%25").replace("\r", "").replace("\n", " ")
            print(f"::error {location}::{message}")
        elif re.match(r"^(error|xcodebuild: error|ld: error|clang: error):", line) and line not in generic:
            generic.append(line)

for line in generic[:10]:
    print(f"::error::{line}")

print(f"Found {len(seen)} compiler/test error(s).")
PY
  echo "----- last 60 lines of $log_file -----"
  tail -n 60 "$log_file"
fi

exit "$status"
