#!/usr/bin/env bash
set -euo pipefail

# Run Audiveris batch OMR on a sample score image.
#
# This script expects an Audiveris source checkout or installed Audiveris CLI.
# It is intentionally kept as documentation plus a reproducible command because
# Audiveris development builds may require a very new JDK.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SAMPLE_IMAGE="${ROOT_DIR}/samples/scores/audiveris-baseline/chula.png"
OUTPUT_DIR="${ROOT_DIR}/samples/musicxml/audiveris-baseline"
AUDIVERIS_DIR="${AUDIVERIS_DIR:-/private/tmp/audiveris-dev}"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"

mkdir -p "${OUTPUT_DIR}"

if [[ ! -f "${SAMPLE_IMAGE}" ]]; then
  echo "Missing sample image: ${SAMPLE_IMAGE}" >&2
  exit 1
fi

if [[ ! -x "${AUDIVERIS_DIR}/gradlew" ]]; then
  echo "Missing Audiveris checkout with gradlew: ${AUDIVERIS_DIR}" >&2
  exit 1
fi

cd "${AUDIVERIS_DIR}"
JAVA_HOME="${JAVA_HOME}" ./gradlew run --no-daemon --args="-batch -transcribe -export -output ${OUTPUT_DIR} ${SAMPLE_IMAGE}"

