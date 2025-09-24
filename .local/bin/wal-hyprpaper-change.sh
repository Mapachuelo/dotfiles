#!/usr/bin/env bash
# wal-hyprpaper-change.sh
# Selecciona un fondo aleatorio, lo pre-load en hyprpaper, lo aplica por monitor y ejecuta pywal.
# Ajusta WALLPAPERS y la ruta de kitty si hace falta.

set -euo pipefail

WALLPAPERS="/home/mapachuelo/OneDrive/Pictures/Wallpaper/"   # <- cambia a tu carpeta
# BUSCA IMAGEN
IMG=$(find "$WALLPAPERS" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | shuf -n1)

if [ -z "$IMG" ]; then
  notify-send "wal-hyprpaper" "No se encontró imagen en $WALLPAPERS"
  exit 1
fi

# ASEGURAR hyprpaper corriendo
if ! pgrep -x hyprpaper >/dev/null 2>&1; then
  # arrancar en background (sin duplicar si ya se lanza desde hyprland)
  hyprpaper >/dev/null 2>&1 & disown || true
  sleep 0.2
fi

# PRELOAD (mejor practicar: preload antes de aplicar)
if command -v hyprctl >/dev/null 2>&1; then
  hyprctl hyprpaper preload "$IMG"
else
  notify-send "wal-hyprpaper" "hyprctl no está disponible. Instala hyprctl/hyprland tools."
  exit 1
fi

# OBTENER LISTA DE MONITORES y APLICAR por cada uno
# hyprctl monitors -> línea con "Monitor <NOMBRE>"
MONITORS=$(hyprctl monitors | awk '/Monitor/ {print $2}')

# si no devuelve monitores, intentar aplicar global (por si acaso)
if [ -z "$MONITORS" ]; then
  # aplicar al monitor virtual por defecto (puede funcionar en setups simples)
  hyprctl hyprpaper wallpaper "$IMG" || true
else
  for M in $MONITORS; do
    # la sintaxis: hyprctl hyprpaper wallpaper "MonitorName,/ruta/a/imagen"
    hyprctl hyprpaper wallpaper "${M},${IMG}" || true
  done
fi

# ESPERAR UN POCO y DESCARGAR nop utilizados
sleep 0.2
# la opción recomendada es unload unused (libera preloads que no se usan)
hyprctl hyprpaper unload unused >/dev/null 2>&1 || true

# EJECUTAR pywal para generar paleta
if command -v wal >/dev/null 2>&1; then
  wal -i "$IMG"
fi

# REAPLICAR A kitty (si existe)
KITTY_COLORS="$HOME/.cache/wal/colors-kitty.conf"
if command -v kitty >/dev/null 2>&1 && [ -f "$KITTY_COLORS" ]; then
  kitty @ set-colors -a "$KITTY_COLORS" 2>/dev/null || true
fi

# Opcional: recargar o notificar otros componentes (descomenta/ajusta si usas)
# killall -USR1 waybar || true
# systemctl --user restart my-waybar.service || true

notify-send "wal-hyprpaper" "Wallpaper aplicado: $(basename "$IMG")"

