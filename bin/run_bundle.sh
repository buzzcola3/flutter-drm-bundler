#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 /path/to/flutter-pi /path/to/bundle [flutter-pi args...]" >&2
  exit 1
fi

flutterpi="$1"
shift
bundle="$1"
shift

bundle_dir="$(cd "$bundle" && pwd)"

export LD_LIBRARY_PATH="$bundle_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$flutterpi" "$bundle_dir" "$@"
