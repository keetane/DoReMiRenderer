#!/bin/sh
set -eu

# Generate static, SDK-owned browser render plans for every MXL in the app's
# development sample directory. The browser receives plans only: it never
# parses MusicXML or calculates score layout coordinates.
ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SOURCE_DIR="${1:-$ROOT_DIR/Apps/DoReMiPalette/DoReMiPalette/Resources/Samples}"
OUTPUT_DIR="${2:-$ROOT_DIR/Examples/WebCanvasViewer/samples}"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Missing sample source directory: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.json
CATALOG_PATH="$OUTPUT_DIR/catalog.json"
SOURCE_LIST="$(mktemp)"
CATALOG_TEMPORARY="$(mktemp)"
trap 'rm -f "$SOURCE_LIST" "$CATALOG_TEMPORARY"' EXIT HUP INT TERM
rg --files "$SOURCE_DIR" | rg '\.mxl$' | sort > "$SOURCE_LIST"
printf '[]\n' > "$CATALOG_TEMPORARY"

while IFS= read -r input_path; do
  filename="$(basename "$input_path")"
  stem="${filename%.mxl}"
  slug="$(printf '%s' "$stem" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-//; s/-$//')"
  display_name="$(printf '%s' "$stem" | sed -E 's/_+/ /g; s/\.\.+/./g')"
  plan_name="$slug.json"

  swift run DoReMiRendererWebExport \
    --input "$input_path" \
    --output "$OUTPUT_DIR/$plan_name" \
    --width 1024 \
    --primary-only \
    </dev/null

  entry="$(jq -n \
    --arg id "$slug" \
    --arg name "$display_name" \
    --arg plan "./samples/$plan_name" \
    --arg source "$filename" \
    '{id: $id, name: $name, plan: $plan, source: $source}')"
  next_catalog="$(mktemp)"
  jq --argjson entry "$entry" '. + [$entry]' "$CATALOG_TEMPORARY" > "$next_catalog"
  mv "$next_catalog" "$CATALOG_TEMPORARY"
done < "$SOURCE_LIST"

if [ "$(jq 'length' "$CATALOG_TEMPORARY")" -eq 0 ]; then
  echo "No .mxl files found in $SOURCE_DIR" >&2
  exit 1
fi

mv "$CATALOG_TEMPORARY" "$CATALOG_PATH"
trap - EXIT HUP INT TERM
rm -f "$SOURCE_LIST"
echo "Wrote $(jq 'length' "$CATALOG_PATH") static Web Render Plans to $OUTPUT_DIR"
