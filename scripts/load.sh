#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/helpers.sh"

get_number_of_cores() {
  if is_osx; then
    sysctl -n hw.ncpu
  else
    nproc
  fi
}

print_load() {
  local LC_NUMERIC=C
  local interval="$1"
  local per_core="${2:-}"

  if [[ -z "$per_core" ]]; then
    per_core="${LOAD_PER_CPU_CORE:-}"
  fi
  if [[ -z "$per_core" && -n "$TMUX" ]]; then
    per_core="$(get_tmux_option "@load_per_cpu_core" "false")"
  fi

  # Fast-path for Linux /proc/loadavg (avoids spawning subshells)
  if [[ -r /proc/loadavg ]]; then
    local l1 l5 l15
    read -r l1 l5 l15 _ < /proc/loadavg
    case "$per_core" in
      true|1|yes)
        local num_cores
        num_cores=$(get_number_of_cores)
        case "$interval" in
          1) awk -v n="$num_cores" -v l="$l1" 'BEGIN { printf "%.2f", l/n }' ;;
          5) awk -v n="$num_cores" -v l="$l5" 'BEGIN { printf "%.2f", l/n }' ;;
          15) awk -v n="$num_cores" -v l="$l15" 'BEGIN { printf "%.2f", l/n }' ;;
          *) awk -v n="$num_cores" -v a="$l1" -v b="$l5" -v c="$l15" 'BEGIN { printf "%.2f %.2f %.2f", a/n, b/n, c/n }' ;;
        esac
        ;;
      *)
        case "$interval" in
          1) echo -n "$l1" ;;
          5) echo -n "$l5" ;;
          15) echo -n "$l15" ;;
          *) echo -n "$l1 $l5 $l15" ;;
        esac
        ;;
    esac
    return
  fi

  # Fallback for systems without /proc/loadavg (e.g. macOS / BSD)
  local num_cores=1
  case "$per_core" in
    true|1|yes)
      num_cores=$(get_number_of_cores)
      ;;
  esac

  local output
  output=$(uptime | awk -v num_cores="$num_cores" '{
    printf "%.2f %.2f %.2f", $(NF-2)/num_cores, $(NF-1)/num_cores, $NF/num_cores
  }')

  local out1 out5 out15
  read -r out1 out5 out15 <<< "$output"

  case "$interval" in
    1) output="$out1" ;;
    5) output="$out5" ;;
    15) output="$out15" ;;
  esac

  # Replace commas with dots
  echo -n "${output//,/.}"
}

main() {
  print_load "$@"
}

main "$@"
