
#!/usr/bin/env bash
# wal-swww-change.sh - aplica wallpaper con swww, espera daemon y ejecuta wal+hyprtheme
set -euo pipefail

WALLPAPERS="${HOME}/.config/wallpaper"
LOG="/tmp/wal-swww-change.log"

echo "=== inicio $(date -Iseconds) ===" >> "$LOG"

IMG=$(find "$WALLPAPERS" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | shuf -n1 || true)
if [ -z "$IMG" ]; then
  echo "No se encontró imagen en $WALLPAPERS" >> "$LOG"
  notify-send "wal-swww" "No se encontró imagen en $WALLPAPERS"
  exit 1
fi

echo "Imagen seleccionada: $IMG" >> "$LOG"

# Esperar a XDG_RUNTIME_DIR y WAYLAND_DISPLAY (sesión Wayland) - timeout 10s
WAIT_SECS=10
i=0
while [ -z "${XDG_RUNTIME_DIR:-}" ] || [ -z "${WAYLAND_DISPLAY:-}" ]; do
  i=$((i+1))
  if [ $i -ge $WAIT_SECS ]; then
    echo "Advertencia: XDG_RUNTIME_DIR o WAYLAND_DISPLAY no seteados (intento $i/$WAIT_SECS)" >> "$LOG"
    break
  fi
  #sleep 0.5
done

# Asegurar swww-daemon (iniciar si no existe)
if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  echo "swww-daemon no encontrado. Lanzando swww init..." >> "$LOG"
  # iniciar daemon en background
  swww init >/dev/null 2>&1 & disown || true
  # esperar un poco por el socket
  sleep 0.5
fi

# Esperar hasta que swww acepte comandos (timeout 8s)
i=0
until swww img "$IMG" --no-daemon --output /dev/null >/dev/null 2>&1; do
  # prueba real: usar swww img en modo simulación no siempre existe, así que intentamos 'swww img' con --transition-step 0 en background.
  if pgrep -x swww-daemon >/dev/null 2>&1; then
    # Intentar con transición mínima para chequear disponibilidad
    if swww img "$IMG" --transition-type none --transition-step 0 >/dev/null 2>&1; then
      break
    fi
  fi

  i=$((i+1))
  if [ $i -ge 16 ]; then
    echo "Timeout esperando swww responder (intentos $i). Se continuará intentando pero puede fallar." >> "$LOG"
    break
  fi
  #sleep 0.5
done

# Intentar aplicar con transición visible
if command -v swww >/dev/null 2>&1; then
  echo "Aplicando wallpaper vía swww: $IMG" >> "$LOG"
  # usa parámetros estándar; si te da problemas ajusta --transition-type/step
  swww img "$IMG" --transition-type any --transition-step 255 --transition-fps 60 >/dev/null 2>&1 || {
    echo "swww img falló en la llamada principal, intentando sin flags..." >> "$LOG"
    swww img "$IMG" >/dev/null 2>&1 || echo "swww img completamente falló" >> "$LOG"
  }
else
  echo "swww no instalado" >> "$LOG"
  notify-send "wal-swww" "swww no está instalado"
fi

# Ejecutar wal
if command -v wal >/dev/null 2>&1; then
  echo "Ejecutando wal -i $IMG" >> "$LOG"
  wal -i "$IMG" >> "$LOG" 2>&1 || echo "wal falló" >> "$LOG"
else
  echo "wal no disponible" >> "$LOG"
fi

# Intentar aplicar hyprtheme o reiniciar servicio user
APPLIED_HYPRTHEME=0
if command -v hyprtheme >/dev/null 2>&1; then
  echo "Intentando hyprtheme apply wal" >> "$LOG"
  if hyprtheme apply wal >/dev/null 2>&1; then
    APPLIED_HYPRTHEME=1
  fi
fi

if [ $APPLIED_HYPRTHEME -eq 0 ]; then
  if systemctl --user status hyprtheme.service >/dev/null 2>&1; then
    echo "Reiniciando hyprtheme.service" >> "$LOG"
    systemctl --user restart hyprtheme.service >/dev/null 2>&1 || true
    APPLIED_HYPRTHEME=1
  fi
fi

# Reaplicar kitty si aplica
KITTY_COLORS="${HOME}/.cache/wal/colors-kitty.conf"
if command -v kitty >/dev/null 2>&1 && [ -f "$KITTY_COLORS" ]; then
  kitty @ set-colors -a "$KITTY_COLORS" 2>/dev/null || true
fi

MSG="Wallpaper aplicado: $(basename "$IMG")"
if [ $APPLIED_HYPRTHEME -eq 1 ]; then
  MSG="${MSG} — hyprtheme actualizado"
else
  MSG="${MSG} — hyprtheme NO aplicado"
fi

notify-send "wal-swww" "$MSG"
echo "=== fin $(date -Iseconds) ===" >> "$LOG"

