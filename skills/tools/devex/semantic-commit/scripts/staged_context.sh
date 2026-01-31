#!/usr/bin/env bash
set -euo pipefail

exec semantic-commit staged-context "$@"
