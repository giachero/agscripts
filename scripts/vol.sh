#!/usr/bin/env bash
#
# Author: Andrea Giachero <Andrea.Giachero@mib.infn.it>
# Desc  : Show or set the volume of the default audio output.
#         Works with PulseAudio and PipeWire (through pactl).
#
# Usage : vol              show the current volume
#         vol 50           set the volume to 50%  (the % sign is optional)
#         vol 120%         set the volume to 120% (above 100% amplifies)
#         vol +10 | -10    raise or lower by 10%
#         vol mute | unmute | toggle
#
# The volume is limited to MAX_VOL (150%) to protect speakers and ears.

set -euo pipefail

MAX_VOL=150
SINK=@DEFAULT_SINK@

usage() { sed -n '7,13s/^# \{0,1\}//p' "$0"; }
die()   { echo "vol: $*" >&2; exit 1; }

command -v pactl >/dev/null 2>&1 || die "pactl not found (sudo apt install pulseaudio-utils)"

get_vol()  { pactl get-sink-volume "$SINK" | grep -oE '[0-9]+%' | head -n1 | tr -d '%'; }
get_mute() { pactl get-sink-mute "$SINK" | awk '{print $2}'; }

show() {
  local v m
  v=$(get_vol); m=$(get_mute)
  if [[ $m == yes ]]; then
    echo "Volume: ${v}% (muted)"
  else
    echo "Volume: ${v}%"
  fi
}

set_vol() {
  local v=$1
  (( v < 0 )) && v=0
  if (( v > MAX_VOL )); then
    echo "vol: limited to ${MAX_VOL}%" >&2
    v=$MAX_VOL
  fi
  pactl set-sink-volume "$SINK" "${v}%"
}

case ${1:-} in
  "")             show; exit 0 ;;
  -h|--help)      usage; exit 0 ;;
  mute)           pactl set-sink-mute "$SINK" 1 ;;
  unmute)         pactl set-sink-mute "$SINK" 0 ;;
  toggle)         pactl set-sink-mute "$SINK" toggle ;;
  [+-][0-9]*)     arg=${1%\%}
                  [[ $arg =~ ^[+-][0-9]+$ ]] || die "invalid value: $1"
                  delta=$(( 10#${arg:1} ))
                  [[ $arg == -* ]] && delta=$(( -delta ))
                  set_vol $(( $(get_vol) + delta )) ;;
  [0-9]*)         arg=${1%\%}
                  [[ $arg =~ ^[0-9]+$ ]] || die "invalid value: $1"
                  set_vol $(( 10#$arg )) ;;
  *)              usage >&2; exit 1 ;;
esac

show
