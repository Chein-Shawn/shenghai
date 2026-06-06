#!/usr/bin/env bash
set -euo pipefail

# Run Audiveris batch OMR on a sample score image.
#
# This script prefers an installed Audiveris.app because current source builds
# require a very new JDK. It falls back to a source checkout only when needed.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SAMPLE_IMAGE="${ROOT_DIR}/samples/scores/audiveris-baseline/chula.png"
OUTPUT_DIR="${ROOT_DIR}/samples/musicxml/audiveris-baseline"
AUDIVERIS_DIR="${AUDIVERIS_DIR:-/private/tmp/audiveris-dev}"
AUDIVERIS_APP_CLI="${AUDIVERIS_APP_CLI:-/Applications/Audiveris.app/Contents/MacOS/Audiveris}"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home}"

mkdir -p "${OUTPUT_DIR}"

if [[ ! -f "${SAMPLE_IMAGE}" ]]; then
  echo "Missing sample image: ${SAMPLE_IMAGE}" >&2
  exit 1
fi

if [[ -x "${AUDIVERIS_APP_CLI}" ]]; then
  "${AUDIVERIS_APP_CLI}" -batch -transcribe -export -output "${OUTPUT_DIR}" "${SAMPLE_IMAGE}"
  exit 0
fi

if [[ ! -x "${AUDIVERIS_DIR}/gradlew" ]]; then
  cat >&2 <<EOF
Missing Audiveris app or source checkout.

Preferred fix:
  1. Install a macOS Audiveris DMG that provides Audiveris.app.
  2. Re-run this script.

Source-build fallback:
  1. Install JDK 25.
  2. Clone Audiveris into ${AUDIVERIS_DIR}.
  3. Re-run with JAVA_HOME pointing at JDK 25.
EOF
  exit 1
fi

cd "${AUDIVERIS_DIR}"
JAVA_HOME="${JAVA_HOME}" ./gradlew run --no-daemon --args="-batch -transcribe -export -output ${OUTPUT_DIR} ${SAMPLE_IMAGE}"
