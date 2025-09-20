#!/usr/bin/env bash
# ~/.config/waybar/modules/music_player.sh
# Versión robusta: detecta player MPRIS, crea JSON seguro para waybar.
# Uso: ~/.config/waybar/modules/music_player.sh grep
# Requiere: playerctl instalado

set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 [grep|pause|previous|next]"
  exit 1
fi

action="$1"

# Devuelve el primer player preferido que esté disponible.
# Prioridad: spotify, ncspot, any mpris player found by playerctl.
choose_player() {
  # playerctl -l lista los players MPRIS disponibles
  players="$(playerctl -l 2>/dev/null || true)"
  if echo "$players" | grep -iq '^spotify$'; then
    printf "spotify"
    return
  fi
  if echo "$players" | grep -iq '^ncspot$'; then
    printf "ncspot"
    return
  fi
  # Si hay cualquier player disponible, devuelve el primero
  first="$(printf '%s\n' "$players" | head -n1)"
  if [ -n "$first" ]; then
    printf "%s" "$first"
    return
  fi
  # si no hay ninguno, vacío
  printf ""
}

player="$(choose_player)"

# Si no hay player disponible y la acción no es solo para consulta, salimos o no hacemos nada útil.
if [ -z "$player" ] && [ "$action" != "grep" ]; then
  # nada que controlar
  exit 0
fi

# función para escapar comillas y saltos de línea para JSON simple
json_escape() {
  # reemplaza \ y " y saltos de línea por escapes JSON
  printf '%s' "$1" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read())[1:-1])"
}

case "$action" in
  grep)
    # Si no hay player devolvemos JSON vacio para que waybar oculte el módulo
    if [ -z "$player" ]; then
      printf '{"text": "", "class": ""}\n'
      exit 0
    fi

    # obtenemos estado (Playing/Paused/Stopped) con playerctl status
    status="$(playerctl --player="$player" status 2>/dev/null || echo "Stopped")"
    status_lc="$(printf '%s' "$status" | tr '[:upper:]' '[:lower:]')"

    if [ "$status_lc" = "playing" ] || [ "$status_lc" = "paused" ]; then
      # metadata (artist - title)
      info="$(playerctl --player="$player" metadata --format '{{artist}} - {{title}}' 2>/dev/null || true)"
      # fallback si viene vacío
      if [ -z "$info" ]; then
        info="$(playerctl --player="$player" metadata --format '{{title}}' 2>/dev/null || echo "")"
      fi

      # recortar a 36 chars (como en tu original)
      max=36
      if [ "${#info}" -gt "$max" ]; then
        trimmed="${info:0:36}.."
      else
        trimmed="$info"
      fi

      icon=""
      text="$icon  $trimmed"
    else
      # stopped -> no texto
      text=""
    fi

    # escapamos para JSON
    esc_text="$(json_escape "$text")"
    esc_class="$(json_escape "$status_lc")"

    printf '{"text":"%s", "class":"%s"}\n' "$esc_text" "$esc_class"
    ;;

  pause)
    playerctl --player="$player" play-pause || true
    ;;

  previous)
    playerctl --player="$player" previous || true
    ;;

  next)
    playerctl --player="$player" next || true
    ;;

  *)
    printf 'Unknown action: %s\n' "$action" >&2
    exit 1
    ;;
esac

