#!/bin/bash

# ╔══════════════════════════════════════════╗
# ║ 🎨 Modern Wallpaper Selector for Sway    ║
# ╚══════════════════════════════════════════╝

# --- CONFIGURACIÓN ---
DIR_WALLPAPERS="$HOME/wallpaper"
SCRIPT_NAME="$(basename "$0")"

# Colores y formato para notificaciones
NOTIFY_URGENCY="normal"
NOTIFY_TIMEOUT=3000  # 3 segundos

# Funciones helper
show_help() {
    cat << EOF
╭──────────────────────────────────────────────╮
│  🎨 $SCRIPT_NAME - Wallpaper Selector       │
├──────────────────────────────────────────────┤
│                                              │
│  Uso: $SCRIPT_NAME [OPCIONES]               │
│                                              │
│  Opciones:                                   │
│    -h, --help       Mostrar esta ayuda      │
│    -r, --random     Fondo aleatorio         │
│    -d, --dir DIR    Usar otro directorio    │
│                                              │
│  Controles nsxiv:                          │
│    m = seleccionar | q = salir             │
│                                              │
╰──────────────────────────────────────────────╯
EOF
    exit 0
}

send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-$NOTIFY_URGENCY}"
    
    notify-send \
        -a "Wallpaper Selector" \
        -u "$urgency" \
        -t "$NOTIFY_TIMEOUT" \
        "$title" \
        "$message"
}

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -r|--random)
            RANDOM_MODE=true
            shift
            ;;
        -d|--dir)
            DIR_WALLPAPERS="$2"
            shift 2
            ;;
        *)
            echo "❌ Opción desconocida: $1"
            echo "Usa --help para ver las opciones disponibles"
            exit 1
            ;;
    esac
done

# Verificar que existe el directorio
if [ ! -d "$DIR_WALLPAPERS" ]; then
    send_notification "❌ Error" "Directorio no encontrado:\n$DIR_WALLPAPERS" "critical"
    echo "❌ Error: El directorio '$DIR_WALLPAPERS' no existe"
    exit 1
fi

# Verificar que hay imágenes
shopt -s nullglob
IMAGES=("$DIR_WALLPAPERS"/*.{jpg,jpeg,png,gif,bmp,webp})
shopt -u nullglob

if [ ${#IMAGES[@]} -eq 0 ]; then
    send_notification "⚠️ Sin imágenes" "No se encontraron imágenes en:\n$DIR_WALLPAPERS" "critical"
    echo "⚠️ No se encontraron imágenes en '$DIR_WALLPAPERS'"
    exit 1
fi

# ─── MODO ALEATORIO ───
if [ "$RANDOM_MODE" = true ]; then
    SELECCION="${IMAGES[RANDOM % ${#IMAGES[@]}]}"
    send_notification "🎲 Modo Aleatorio" "Seleccionando:\n$(basename "$SELECCION")" "normal"
else
    # ─── SELECCIÓN INTERACTIVA ───
    # Mostrar indicador de inicio
    send_notification "🎨 Selector de Wallpapers" "Selecciona una imagen con nsxiv\nUsa 'm' para marcar y 'q' para salir" "normal"
    
    # Obtener resolución de la pantalla para la previsualización
    SCREEN_WIDTH=1920
    SCREEN_HEIGHT=1080
    
    # Intentar obtener la resolución real
    if command -v wlr-randr &>/dev/null; then
        RESOLUTION=$(wlr-randr | grep -m1 "Enabled" -A1 | grep -oP '\d+x\d+' | head -1)
        if [ -n "$RESOLUTION" ]; then
            SCREEN_WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
            SCREEN_HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)
        fi
    elif command -v wayland-info &>/dev/null; then
        RESOLUTION=$(wayland-info | grep -m1 "preferred mode" | grep -oP '\d+x\d+')
        if [ -n "$RESOLUTION" ]; then
            SCREEN_WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
            SCREEN_HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)
        fi
    fi
    
    # Calcular tamaño de ventana (90% de la pantalla)
    WIN_WIDTH=$(( SCREEN_WIDTH * 90 / 100 ))
    WIN_HEIGHT=$(( SCREEN_HEIGHT * 90 / 100 ))
    
    SELECCION=$(nsxiv -t -f -o -W "$WIN_WIDTH" -H "$WIN_HEIGHT" "$DIR_WALLPAPERS" | head -n 1)
    
    if [ -z "$SELECCION" ]; then
        send_notification "ℹ️ Cancelado" "Selección de wallpaper cancelada" "low"
        echo "ℹ️ Selección cancelada"
        exit 0
    fi
fi

# ─── APLICAR WALLPAPER ───
# Mensaje de transición
echo "✨ Aplicando wallpaper..."

# Terminar swaybg anterior limpiamente
if pgrep -x swaybg > /dev/null; then
    pkill -TERM swaybg
    sleep 0.2
fi

# Aplicar nuevo wallpaper
swaybg -i "$SELECCION" -m fill &
SWAYBG_PID=$!

# ─── PYWAL ───
echo "🎨 Generando esquema de colores con Pywal..."
if wal -i "$SELECCION" -n -q --backend magick 2>/dev/null; then
    echo "✓ Pywal aplicado correctamente"
else
    echo "⚠ Pywal falló, continuando..."
fi

# ─── RECARGAR WAYBAR ───
if pgrep -x waybar > /dev/null; then
    pkill -USR2 waybar
    echo "✓ Waybar recargado"
fi

# ─── ACTUALIZAR TERMINAL ───
if [ -f "$HOME/.cache/wal/sequences" ]; then
    cat "$HOME/.cache/wal/sequences"
fi

# ─── NOTIFICACIÓN FINAL ───
WALLPAPER_NAME="$(basename "$SELECCION")"
WALLPAPER_SIZE="$(du -h "$SELECCION" | cut -f1)"
IMAGE_DIMENSIONS="$(identify -format "%wx%h" "$SELECCION" 2>/dev/null || echo "Desconocida")"

send_notification \
    "✅ Wallpaper Aplicado" \
    "📁 $WALLPAPER_NAME\n📐 $IMAGE_DIMENSIONS | 💾 $WALLPAPER_SIZE" \
    "normal"

echo "╭────────────────────────────────────────────╮"
echo "│  ✅ ¡Listo! Wallpaper aplicado            │"
echo "│                                            │"
echo "│  📁 $(basename "$SELECCION")"
printf "│  📐 %-38s │\n" "$IMAGE_DIMENSIONS"
printf "│  💾 %-38s │\n" "$WALLPAPER_SIZE"
echo "╰────────────────────────────────────────────╯"

exit 0
