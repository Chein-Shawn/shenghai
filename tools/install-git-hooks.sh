#!/usr/bin/env sh
set -eu

git config core.hooksPath .githooks
echo "VocalDive Git hooks enabled from .githooks."
