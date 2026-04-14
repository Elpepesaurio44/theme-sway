#!/bin/bash

# Colores de Pywal (Cargados dinámicamente)
source "$HOME/.cache/wal/colors.sh"

# 1. CPU y Memoria (Compacto)
cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
mem=$(free -h | awk '/^Mem:/ {print $3}')

# 2. Red y Modo Monitor (Ideal para ZeroSignal)
interface=$(ip route | grep default | awk '{print $5}')
if [ -z "$interface" ]; then
    net_stat="󰲛 Off"
else
    # Detecta si la interfaz está en modo monitor
    mode=$(iw dev "$interface" info 2>/dev/null | grep type | awk '{print $2}')
    [ "$mode" == "monitor" ] && net_stat="󱚽 MON" || net_stat=" $interface"
fi

# 3. Volumen
vol=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '[0-9]+(?=%)' | head -1)

# 4. Batería (Si aplica)
bat=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)

# Salida formateada con iconos
echo " $cpu% |  $mem | $net_stat |  $vol% | 󰃭 $(date +'%d/%m %H:%M')"
