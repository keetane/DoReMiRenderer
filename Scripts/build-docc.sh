#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

SYMBOL_GRAPH_DIR=".build/arm64-apple-macosx/symbolgraph"
OUTPUT_PATH="${DOCC_OUTPUT_PATH:-/tmp/DoReMiRendererKit.doccarchive}"
SWIFTPM_CACHE_PATH=".build/swiftpm-cache"
SWIFTPM_CONFIG_PATH=".build/swiftpm-config"
SWIFTPM_SECURITY_PATH=".build/swiftpm-security"
CLANG_CACHE_PATH=".build/clang-module-cache"

mkdir -p "$SWIFTPM_CACHE_PATH" "$SWIFTPM_CONFIG_PATH" "$SWIFTPM_SECURITY_PATH" "$CLANG_CACHE_PATH"

export CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_PATH"

swift package \
  --cache-path "$SWIFTPM_CACHE_PATH" \
  --config-path "$SWIFTPM_CONFIG_PATH" \
  --security-path "$SWIFTPM_SECURITY_PATH" \
  --disable-sandbox \
  dump-symbol-graph

rm -rf "$OUTPUT_PATH"

xcrun docc convert Sources/DoReMiRendererKit/DoReMiRendererKit.docc \
  --additional-symbol-graph-dir "$SYMBOL_GRAPH_DIR" \
  --fallback-display-name DoReMiRendererKit \
  --fallback-bundle-identifier com.keetane.DoReMiRendererKit \
  --fallback-bundle-version 0.1.0 \
  --output-path "$OUTPUT_PATH"

echo "DocC archive written to $OUTPUT_PATH"
