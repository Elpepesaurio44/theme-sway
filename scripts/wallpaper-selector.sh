#!/bin/bash

# ╔══════════════════════════════════════════════════════════╗
# ║ 🎨 Rofi Wallpaper Selector con Pywal + swaybg + CSS    ║
# ╚══════════════════════════════════════════════════════════╝

# --- CONFIG ---
DIR_WALLPAPERS="$HOME/wallpaper"
ROFI_THEME="$HOME/.config/rofi/wallpaper-selector.rasi"
CACHE_DIR="$HOME/.cache/wal"
THUMB_DIR="$HOME/.cache/wallpaper-thumbs"

mkdir -p "$THUMB_DIR" "$HOME/.config/rofi"

# --- FUNCTIONS ---

send_notification() {
    notify-send -a "Wallpaper Selector" -u normal -t 3000 "$1" "$2"
}

# --- PARSE ARGS ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--random) RANDOM_MODE=true; shift ;;
        -d|--dir) DIR_WALLPAPERS="$2"; shift 2 ;;
        -h|--help)
            echo "Uso: $0 [-r|--random] [-d|--dir DIR]"
            exit 0
            ;;
        *) shift ;;
    esac
done

# --- CHECK DIR ---
if [ ! -d "$DIR_WALLPAPERS" ]; then
    send_notification "❌ Error" "Directorio no encontrado: $DIR_WALLPAPERS"
    exit 1
fi

# --- GET IMAGES ---
shopt -s nullglob
IMAGES=("$DIR_WALLPAPERS"/*.{jpg,jpeg,png,gif,bmp,webp,tiff,tif,svg})
shopt -u nullglob

if [ ${#IMAGES[@]} -eq 0 ]; then
    send_notification "⚠️ Sin imágenes" "No hay imágenes en $DIR_WALLPAPERS"
    exit 1
fi

# --- RANDOM MODE ---
if [ "$RANDOM_MODE" = true ]; then
    SELECCION="${IMAGES[RANDOM % ${#IMAGES[@]}]}"
else
    # --- CREATE ROFI THEME CON GRID DE PREVISUALIZACIONES ---
    cat > "$ROFI_THEME" << 'EOF'
@import "~/.cache/wal/colors-rofi-dark.rasi"

configuration {
    show-icons: true;
}

window {
    width:    85%;
    height:   75%;
    border:   2px;
    border-color: @selected-active-background;
    border-radius: 15px;
    background-color: @background;
}

listview {
    columns: 4;
    lines:   4;
    spacing: 20px;
    margin:  20px;
    fixed-columns: true;
    scrollbar: true;
    cycle: true;
}

element {
    orientation: vertical;
    padding:     10px;
    border-radius: 10px;
}

element-icon {
    size: 200px;
    horizontal-align: 0.5;
}

element-text {
    horizontal-align: 0.5;
    font: "JetBrainsMono Nerd Font 10";
}

element selected {
    background-color: @selected-active-background;
    text-color: @background;
}

inputbar {
    background-color: @background-alt;
    padding: 12px;
    margin: 10px 10px 0 10px;
    border-radius: 10px;
}

textbox-prompt-colon {
    text-color: @accent;
    str: "🎨 :";
}

entry {
    text-color: @foreground;
}

prompt {
    text-color: @accent;
}

message {
    background-color: @background-alt;
    padding: 10px;
    margin: 0 10px 10px 10px;
    border-radius: 8px;
}
EOF

    # --- BUILD ROFI LIST CON ICONOS ---
    echo "📸 Cargando previsualizaciones... (${#IMAGES[@]} imágenes)"
    send_notification "🎨 Selector de Wallpapers" "Cargando ${#IMAGES[@]} imágenes..."
    
    # Crear lista con iconos para rofi (formato: nombre\0icon\x1fruta)
    ROFI_INPUT=""
    for img in "${IMAGES[@]}"; do
        ROFI_INPUT+="$(basename "$img")\0icon\x1f$img\n"
    done

    # --- LAUNCH ROFI ---
    echo "🚀 Abriendo selector..."
    
    SELECTED=$(echo -en "$ROFI_INPUT" | rofi -dmenu \
        -i \
        -p "🎨 Wallpaper" \
        -theme "$ROFI_THEME" \
        -mesg "↑/↓/←/→ para navegar | Enter para seleccionar | Escape para cancelar" \
        -kb-accept-entry "Return,KP_Enter" \
        -kb-cancel "Escape" \
        -kb-row-up "Up,Control+k" \
        -kb-row-down "Down,Control+j" \
        -kb-row-left "Left,Control+h" \
        -kb-row-right "Right,Control+l" \
        -kb-page-up "Prior" \
        -kb-page-down "Next")

    ROFI_EXIT=$?

    # User cancelled
    if [ $ROFI_EXIT -ne 0 ] || [ -z "$SELECTED" ]; then
        send_notification "ℹ️ Cancelado" "Selección cancelada"
        exit 0
    fi

    # Find full path
    SELECCION=""
    for img in "${IMAGES[@]}"; do
        if [ "$(basename "$img")" = "$SELECTED" ]; then
            SELECCION="$img"
            break
        fi
    done

    if [ -z "$SELECCION" ]; then
        send_notification "❌ Error" "No se encontró: $SELECTED"
        exit 1
    fi
fi

# =============================================
# --- APPLY WALLPAPER ---
# =============================================

echo "✨ Aplicando: $(basename "$SELECCION")"

# Kill old swaybg
pgrep -x swaybg && pkill -TERM swaybg && sleep 0.2

# Apply wallpaper
swaybg -i "$SELECCION" -m fill &
sleep 0.3

# --- PYWAL ---
echo "🎨 Generando colores con Pywal..."
if command -v wal &>/dev/null; then
    wal -i "$SELECCION" -n -q --backend magick 2>/dev/null || wal -i "$SELECCION" -n -q 2>/dev/null
    [ -f "$CACHE_DIR/colors.sh" ] && wal -s 2>/dev/null
    echo "✓ Colores aplicados"
fi

# --- RELOAD WAYBAR ---
pgrep -x waybar && pkill -USR2 waybar

# --- UPDATE TERMINAL ---
[ -f "$CACHE_DIR/sequences" ] && cat "$CACHE_DIR/sequences"

# --- NOTIFICATION ---
WALLPAPER_NAME="$(basename "$SELECCION")"
IMAGE_DIMENSIONS="$(identify -format "%wx%h" "$SELECCION" 2>/dev/null | head -1 || echo "N/A")"

send_notification -i "$SELECCION" "✅ Wallpaper Aplicado" "$WALLPAPER_NAME\n$IMAGE_DIMENSIONS"

echo "╔══════════════════════════════════════════╗"
echo "║  ✅ ¡Wallpaper aplicado!                ║"
printf "║  📁 %-36s ║\n" "$WALLPAPER_NAME"
printf "║  📐 %-36s ║\n" "$IMAGE_DIMENSIONS"
echo "╚══════════════════════════════════════════╝"

exit 0
