#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
python="${PYTHON:-}"
if [[ -z "$python" ]]; then
  python="$(command -v python3 || true)"
fi

if [[ -z "$python" ]]; then
  echo "image-processing: error: python3 not found (set PYTHON=... or install python3)" >&2
  exit 1
fi

exec "$python" "${script_dir}/image_processing.py" "$@"
