#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

SCRIPT_DIR="${0:A:h}"
WEB_DIR="$SCRIPT_DIR/Examples/WebCanvasViewer"
APP_URL="http://127.0.0.1:8767/"
HEALTH_URL="http://127.0.0.1:8767/api/health"
LOG_PATH="/tmp/DoReMiPaletteWeb.log"

if ! /usr/bin/curl --silent --fail --max-time 1 "$HEALTH_URL" >/dev/null 2>&1; then
  cd "$WEB_DIR"
  /usr/bin/nohup /usr/bin/python3 server.py --host 127.0.0.1 --port 8767 >"$LOG_PATH" 2>&1 &

  for _ in {1..40}; do
    if /usr/bin/curl --silent --fail --max-time 1 "$HEALTH_URL" >/dev/null 2>&1; then
      break
    fi
    /bin/sleep 0.25
  done
fi

if ! /usr/bin/curl --silent --fail --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then
  /usr/bin/osascript -e 'display alert "DoReMi Palette Webを起動できませんでした" message "ログを確認してください: /tmp/DoReMiPaletteWeb.log" as critical'
  exit 1
fi

/usr/bin/open "$APP_URL"
