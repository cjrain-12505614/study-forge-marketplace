#!/bin/bash
set -e

PLUGIN_NAME="study-forge"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION=$(python3 -c "import json; d=json.load(open('${SCRIPT_DIR}/.claude-plugin/plugin.json')); print(d['version'])")
OUT="${SCRIPT_DIR}/dist/${PLUGIN_NAME}.plugin"

mkdir -p "${SCRIPT_DIR}/dist"

# 기존 파일 제거
rm -f "$OUT"

# study-forge/ prefix가 붙도록 상위 디렉토리에서 패키징
cd "${SCRIPT_DIR}/.."
zip -r "$OUT" \
  "${PLUGIN_NAME}/.claude-plugin" \
  "${PLUGIN_NAME}/commands" \
  "${PLUGIN_NAME}/skills" \
  "${PLUGIN_NAME}/README.md" \
  --exclude "*.DS_Store"

echo "Built: $OUT (v${VERSION})"
