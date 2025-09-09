#!/bin/bash
set -euo pipefail

APP_DIR="/config/apps"
BIN="${APP_DIR}/rustdesk.AppImage"
mkdir -p "$APP_DIR"

if [[ -n "${RUSTDESK_APPIMAGE_URL:-}" ]]; then
  echo "Descargando RustDesk desde URL proporcionada..."
  wget -O "$BIN" "$RUSTDESK_APPIMAGE_URL"
  chmod +x "$BIN"
else
  if [[ ! -f "$BIN" ]]; then
    echo "No se proporcionó URL. Intenta buscar AppImage preexistente en /config/apps."
  fi
fi

# Crear lanzador de escritorio para webtop
MENU_DIR="/config/Desktop"
mkdir -p "$MENU_DIR"
cat > "$MENU_DIR/RustDesk.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=RustDesk
Exec=${BIN}
Terminal=false
Icon=utilities-terminal
Categories=Utility;Network;
EOF

if [[ "${RUSTDESK_AUTOSTART:-false}" == "true" && -x "$BIN" ]]; then
  nohup "$BIN" >/config/rustdesk.log 2>&1 &
fi
exit 0
