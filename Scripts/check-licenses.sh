#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

NOTICE_FILE="THIRD_PARTY_NOTICES.md"

if [ ! -f "$NOTICE_FILE" ]; then
  echo "Missing $NOTICE_FILE"
  exit 1
fi

if ! grep -q "ZIPFoundation" "$NOTICE_FILE"; then
  echo "THIRD_PARTY_NOTICES.md does not mention ZIPFoundation"
  exit 1
fi

if ! grep -q "MIT License" "$NOTICE_FILE"; then
  echo "THIRD_PARTY_NOTICES.md does not mention the ZIPFoundation MIT License"
  exit 1
fi

if ! grep -q "github.com/weichsel/ZIPFoundation" "$NOTICE_FILE"; then
  echo "THIRD_PARTY_NOTICES.md does not include the ZIPFoundation repository URL"
  exit 1
fi

DEPENDENCY_FILES="Package.swift Package.resolved"
if find . -path "*/Package.resolved" -type f | grep -q .; then
  DEPENDENCY_FILES="$DEPENDENCY_FILES $(find . -path "*/Package.resolved" -type f)"
fi

if grep -Eiq "(^|[^A-Z])L?GPL([^A-Z]|$)" $DEPENDENCY_FILES; then
  echo "Potential GPL/LGPL dependency text found in dependency files"
  exit 1
fi

echo "License check passed"

