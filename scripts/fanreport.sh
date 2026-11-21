#!/usr/bin/env bash
# fanreport.sh: report ThinkPad fan speeds and the relevant temperatures.
#
# Usage:
#   fanreport.sh            print one report
#   fanreport.sh -w 2       refresh every 2 seconds (Ctrl+C to stop)
#
# Reads values directly from /sys/class/hwmon, so it does not depend on
# the output format of `sensors`.

set -u

usage() { echo "Usage: $0 [-w SECONDS]"; }

interval=""
while getopts "w:h" opt; do
  case $opt in
    w) interval=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done

# Laptop fans on the X1 do not exceed roughly 6500 RPM; anything above this
# is flagged as a bogus reading (as seen before the EC reset).
MAX_PLAUSIBLE_RPM=7000
TEMP_WARN=75
TEMP_CRIT=90

# Colors only when writing to a terminal
if [[ -t 1 ]]; then
  RED=$'\e[31m'; YEL=$'\e[33m'; GRN=$'\e[32m'; DIM=$'\e[2m'; BLD=$'\e[1m'; RST=$'\e[0m'
else
  RED=""; YEL=""; GRN=""; DIM=""; BLD=""; RST=""
fi

# Return the first hwmon directory whose name matches the given pattern
find_hwmon() {
  local pattern=$1 d
  for d in /sys/class/hwmon/hwmon*; do
    [[ -r $d/name ]] || continue
    if [[ $(<"$d/name") == $pattern ]]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

# Read a sysfs value, printing nothing if it cannot be read
read_val() { cat "$1" 2>/dev/null; }

# Format a temperature given in millidegrees Celsius, with color
fmt_temp() {
  local raw=$1 t c
  t=$(( raw / 1000 ))
  if   (( t >= TEMP_CRIT )); then c=$RED
  elif (( t >= TEMP_WARN )); then c=$YEL
  else c=$GRN
  fi
  printf '%s%3d °C%s' "$c" "$t" "$RST"
}

temp_line() { printf '  %-20s %s\n' "$1" "$(fmt_temp "$2")"; }

report() {
  local tp ct d f n rpm level v l pkg maxcore bat status pw cap

  printf '%sThinkPad thermal report%s  %s%s%s\n\n' "$BLD" "$RST" "$DIM" "$(date '+%Y-%m-%d %H:%M:%S')" "$RST"

  # ---- Fans ----
  echo "${BLD}Fans${RST}"
  if tp=$(find_hwmon thinkpad); then
    for f in "$tp"/fan*_input; do
      [[ -e $f ]] || continue
      n=$(basename "$f" _input)
      rpm=$(read_val "$f")
      if [[ -z $rpm ]]; then
        printf '  %-20s %sunreadable%s\n' "$n" "$DIM" "$RST"
      elif (( rpm > MAX_PLAUSIBLE_RPM )); then
        printf '  %-20s %s%5d RPM  (implausible reading)%s\n' "$n" "$RED" "$rpm" "$RST"
      else
        printf '  %-20s %5d RPM\n' "$n" "$rpm"
      fi
    done
  else
    echo "  thinkpad hwmon not found (is thinkpad_acpi loaded?)"
  fi
  if [[ -r /proc/acpi/ibm/fan ]]; then
    level=$(awk '/^level:/ {print $2}' /proc/acpi/ibm/fan)
    if [[ $level == auto ]]; then
      printf '  %-20s %s\n' "control level" "$level"
    else
      printf '  %-20s %s%s (not firmware controlled)%s\n' "control level" "$YEL" "$level" "$RST"
    fi
  fi
  echo

  # ---- Temperatures ----
  echo "${BLD}Temperatures${RST}"
  if ct=$(find_hwmon coretemp); then
    pkg=""; maxcore=-1
    for f in "$ct"/temp*_label; do
      [[ -e $f ]] || continue
      l=$(<"$f")
      v=$(read_val "${f%_label}_input")
      [[ -n $v ]] || continue
      if [[ $l == Package* ]]; then
        pkg=$v
      elif [[ $l == Core* ]] && (( v > maxcore )); then
        maxcore=$v
      fi
    done
    [[ -n $pkg ]] && temp_line "CPU package" "$pkg"
    (( maxcore >= 0 )) && temp_line "CPU hottest core" "$maxcore"
  fi
  if [[ -n ${tp:-} ]]; then
    v=$(read_val "$tp/temp1_input")
    [[ -n $v ]] && (( v > 0 )) && temp_line "EC CPU sensor" "$v"
  fi
  if d=$(find_hwmon acpitz); then
    v=$(read_val "$d/temp1_input")
    [[ -n $v ]] && temp_line "ACPI thermal zone" "$v"
  fi
  if d=$(find_hwmon nvme); then
    v=$(read_val "$d/temp1_input")
    [[ -n $v ]] && temp_line "NVMe SSD" "$v"
  fi
  if d=$(find_hwmon 'iwlwifi*'); then
    v=$(read_val "$d/temp1_input")
    [[ -n $v ]] && temp_line "Wi-Fi card" "$v"
  fi
  echo

  # ---- Power ----
  bat=/sys/class/power_supply/BAT0
  if [[ -d $bat ]]; then
    echo "${BLD}Battery${RST}"
    status=$(read_val "$bat/status")
    cap=$(read_val "$bat/capacity")
    pw=$(read_val "$bat/power_now")
    printf '  %-20s %s%%, %s' "state" "${cap:-?}" "${status:-unknown}"
    if [[ -n $pw ]]; then
      awk -v p="$pw" 'BEGIN { printf " at %.1f W", p / 1e6 }'
    fi
    echo
  fi
}

if [[ -n $interval ]]; then
  trap 'echo; exit 0' INT
  while true; do
    clear
    report
    sleep "$interval"
  done
else
  report
fi
