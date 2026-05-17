#!/bin/bash

# vinyl.sh - ASCII visualizer for the mood script.
#
# Displays an animated spinning vinyl record or a scrolling waveform
# while mood audio is streaming in the background. Automatically detects
# which mood is playing and styles the display accordingly.
#
# Usage: vinyl [record|wave|auto]
#   record  - Spinning ASCII vinyl record (default)
#   wave    - Scrolling waveform bars
#   auto    - Picks record for lofi/jazz, wave for rain
#
# Depends on: mood.sh (mpv running in background)

# --- Colors ---
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Mood detection ---
detect_mood() {
  # Primary: read state file written by mood.sh on start
  local state_file="$HOME/.mood_state"
  if [[ -f "$state_file" ]]; then
    local mood
    mood=$(cat "$state_file")
    case "$mood" in
      lofi|rain|jazz) echo "$mood"; return ;;
    esac
  fi
  # Fallback: scan ps for the known video IDs
  local cmd
  cmd=$(ps aux 2>/dev/null)
  case "$cmd" in
    *jfKfPfyJRdk*) echo "lofi"  ;;
    *mPZkdNFkNps*) echo "rain"  ;;
    *neV3EPgvZ3g*) echo "jazz"  ;;
    *)             echo "unknown" ;;
  esac
}

is_mood_running() {
  # Primary: state file exists and mpv is alive
  if [[ -f "$HOME/.mood_state" ]] && pgrep mpv > /dev/null 2>&1; then
    return 0
  fi
  # Fallback: any mpv process running at all
  pgrep mpv > /dev/null 2>&1
}

# --- Terminal helpers ---
hide_cursor()  { tput civis 2>/dev/null; }
show_cursor()  { tput cnorm 2>/dev/null; }
clear_screen() { tput clear 2>/dev/null; }
move_to()      { tput cup "$1" "$2" 2>/dev/null; }   # row col

# Center a string on the terminal
center_text() {
  local text="$1"
  local cols
  cols=$(tput cols)
  # Strip ANSI codes to get printable length
  local plain
  plain=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
  local len=${#plain}
  local pad=$(( (cols - len) / 2 ))
  printf "%${pad}s" ""
  echo -e "$text"
}

# --- Cleanup on exit ---
cleanup() {
  show_cursor
  tput rmcup 2>/dev/null   # restore terminal screen
  echo -e "\n${DIM}vinyl closed.${NC}"
}
trap cleanup EXIT INT TERM

# --- Mood theme config ---
# Sets: MOOD_COLOR  MOOD_LABEL  MOOD_ICON  RECORD_CHAR  GROOVE_COLOR
apply_mood_theme() {
  local mood="$1"
  case "$mood" in
    lofi)
      MOOD_COLOR="$MAGENTA"
      MOOD_LABEL="lo-fi beats"
      MOOD_ICON="◈"
      RECORD_CHAR="▓"
      GROOVE_COLOR="$BLUE"
      ;;
    rain)
      MOOD_COLOR="$CYAN"
      MOOD_LABEL="rain & storms"
      MOOD_ICON="⋄"
      RECORD_CHAR="░"
      GROOVE_COLOR="$BLUE"
      ;;
    jazz)
      MOOD_COLOR="$YELLOW"
      MOOD_LABEL="late-night jazz"
      MOOD_ICON="♪"
      RECORD_CHAR="▒"
      GROOVE_COLOR="$RED"
      ;;
    *)
      MOOD_COLOR="$WHITE"
      MOOD_LABEL="ambient audio"
      MOOD_ICON="○"
      RECORD_CHAR="▓"
      GROOVE_COLOR="$DIM"
      ;;
  esac
}

# --- Record visualizer ---
#
# The record is drawn as concentric rings. Each frame rotates a highlight
# arc around the disc to simulate spinning.

RECORD_FRAMES=(
  # Each frame is a rotation offset (0..7) mapped to a highlight position
  0 1 2 3 4 5 6 7
)

# Draw one frame of the spinning record.
# Args: $1=frame_index  $2=rows_offset (top row to start drawing)
draw_record() {
  local frame="$1"
  local top="$2"
  local cols
  cols=$(tput cols)
  local mid=$(( cols / 2 ))

  # Record art: 9 lines tall, built from inside out
  # Highlight rotates through 8 positions (0=top, going clockwise)
  local f=$(( frame % 8 ))

  # Quadrant characters for spinning groove highlight
  local q=("─" "╮" "│" "╯" "─" "╰" "│" "╭")
  local spin="${q[$f]}"

  # Each row of the record
  # Row 0: top arc
  local r=0
  move_to $(( top + r )) 0
  printf "%*s" $(( mid - 8 )) ""
  echo -e "        ${MOOD_COLOR}╭──────────╮${NC}"

  r=1
  move_to $(( top + r )) 0
  printf "%*s" $(( mid - 8 )) ""
  echo -e "      ${MOOD_COLOR}╭╯${NC}${GROOVE_COLOR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${NC}${MOOD_COLOR}╰╮${NC}"

  r=2
  move_to $(( top + r )) 0
  printf "%*s" $(( mid - 8 )) ""
  echo -e "     ${MOOD_COLOR}│${NC}${GROOVE_COLOR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${NC} ${MOOD_COLOR}╭────╮${NC} ${GROOVE_COLOR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${NC}${MOOD_COLOR}│${NC}"

  r=3
  move_to $(( top + r )) 0
  printf "%*s" $(( mid - 8 )) ""
  # Spinning dot inside label ring
  local spin_char
  case $(( frame % 4 )) in
    0) spin_char="◌" ;;
    1) spin_char="◎" ;;
    2) spin_char="◉" ;;
    3) spin_char="◎" ;;
  esac
  echo -e "     ${MOOD_COLOR}│${NC}${GROOVE_COLOR}${RECORD_CHAR}${RECORD_CHAR}${NC} ${MOOD_COLOR}│${NC} ${MOOD_COLOR}${spin_char}${NC} ${MOOD_COLOR}│${NC} ${GROOVE_COLOR}${RECORD_CHAR}${RECORD_CHAR}${NC}${MOOD_COLOR}│${NC}"

  r=4
  move_to $(( top + r )) 0
  printf "%*s" $(( mid - 8 )) ""
  echo -e "     ${MOOD_COLOR}│${NC}${GROOVE_COLOR}${RECORD_CHAR}${RECORD_CHAR}${NC} ${MOOD_COLOR}╰────╯${NC} ${GROOVE_COLOR}${RECORD_CHAR}${RECORD_CHAR}${NC}${MOOD_COLOR}│${NC}"

  r=5
  move_to $(( top + r )) 0
  printf "%*s" $(( mid - 8 )) ""
  echo -e "      ${MOOD_COLOR}╰╮${NC}${GROOVE_COLOR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${RECORD_CHAR}${NC}${MOOD_COLOR}╭╯${NC}"

  r=6
  move_to $(( top + r )) 0
  printf "%*s" $(( mid - 8 )) ""
  echo -e "        ${MOOD_COLOR}╰──────────╯${NC}"

  # Spinning needle arm
  r=7
  move_to $(( top + r )) 0
  local needle_frames=( "        ╲" "         ╲" "          ╲" "           ╲" "           ╱" "          ╱" "         ╱" "        ╱" )
  printf "%*s" $(( mid - 8 )) ""
  echo -e "${DIM}${needle_frames[$f]}${NC}"
}

# --- Waveform visualizer ---
WAVE_WIDTH=40          # number of bars
WAVE_HEIGHT=8          # max bar height in rows
declare -a wave_bars   # current bar heights

init_wave() {
  wave_bars=()
  for (( i=0; i<WAVE_WIDTH; i++ )); do
    wave_bars+=( $(( RANDOM % WAVE_HEIGHT + 1 )) )
  done
}

# Smoothly evolve wave heights
tick_wave() {
  local new_bars=()
  for (( i=0; i<WAVE_WIDTH; i++ )); do
    local cur="${wave_bars[$i]}"
    local delta=$(( (RANDOM % 3) - 1 ))   # -1, 0, or +1
    local next=$(( cur + delta ))
    (( next < 1 )) && next=1
    (( next > WAVE_HEIGHT )) && next=$WAVE_HEIGHT
    new_bars+=( "$next" )
  done
  wave_bars=( "${new_bars[@]}" )
}

# Draw the waveform at a given row offset
draw_wave() {
  local top="$1"
  local cols
  cols=$(tput cols)
  local left=$(( (cols - WAVE_WIDTH * 2) / 2 ))
  (( left < 0 )) && left=0

  # Draw from top of wave area downward
  for (( row=0; row<WAVE_HEIGHT; row++ )); do
    move_to $(( top + row )) 0
    # Clear line
    printf "%${cols}s" ""
    move_to $(( top + row )) $left

    for (( i=0; i<WAVE_WIDTH; i++ )); do
      local bar="${wave_bars[$i]}"
      local row_from_bottom=$(( WAVE_HEIGHT - row ))
      if (( row_from_bottom <= bar )); then
        # Color intensity by height
        local intensity=$(( bar * 100 / WAVE_HEIGHT ))
        if (( intensity > 75 )); then
          echo -en "${MOOD_COLOR}${BOLD}▐█${NC}"
        elif (( intensity > 40 )); then
          echo -en "${MOOD_COLOR}▐▌${NC}"
        else
          echo -en "${DIM}${MOOD_COLOR}▐▖${NC}"
        fi
      else
        echo -en "  "
      fi
    done
  done
}

# --- Status bar ---
draw_status() {
  local row="$1"
  local mood="$2"
  local frame="$3"
  local cols
  cols=$(tput cols)

  # Pulsing indicator
  local pulse_chars=("·" "•" "●" "•")
  local pulse="${pulse_chars[$(( frame % 4 ))]}"

  move_to "$row" 0
  printf "%${cols}s" ""   # clear line
  move_to "$row" 0

  local status_line="${MOOD_COLOR}${BOLD}${pulse}${NC}  ${BOLD}${MOOD_LABEL}${NC}  ${DIM}│  mood stop  to quit audio${NC}"
  center_text "$status_line"

  # Progress dots (decorative)
  move_to $(( row + 1 )) 0
  printf "%${cols}s" ""
  move_to $(( row + 1 )) 0
  local dot_line="${DIM}· · · · · · · · · · · · · · · · · · · ·${NC}"
  center_text "$dot_line"
}

draw_header() {
  local row="$1"
  local cols
  cols=$(tput cols)

  move_to "$row" 0
  printf "%${cols}s" ""
  move_to "$row" 0
  center_text "${BOLD}${MOOD_COLOR}vinyl${NC}${DIM}  ──  mood visualizer${NC}"
}

# --- Main loop: record ---
run_record() {
  local mood="$1"
  local rows
  rows=$(tput lines)
  local header_row=1
  local record_top=3
  local status_row=$(( record_top + 9 ))

  hide_cursor
  tput smcup   # switch to alternate screen
  clear_screen

  local frame=0
  while true; do
    if ! is_mood_running; then
      move_to $(( rows - 2 )) 0
      center_text "${RED}mood stopped.${NC}  ${DIM}Start it again with:${NC}  mood [lofi|rain|jazz]"
      sleep 2
      break
    fi

    draw_header "$header_row"
    draw_record "$frame" "$record_top"
    draw_status "$status_row" "$mood" "$frame"

    (( frame++ ))
    sleep 0.12
  done
}

# --- Main loop: waveform ---
run_wave() {
  local mood="$1"
  local rows
  rows=$(tput lines)
  local header_row=1
  local wave_top=3
  local status_row=$(( wave_top + WAVE_HEIGHT + 2 ))

  init_wave
  hide_cursor
  tput smcup
  clear_screen

  local frame=0
  while true; do
    if ! is_mood_running; then
      move_to $(( rows - 2 )) 0
      center_text "${RED}mood stopped.${NC}  ${DIM}Start it again with:${NC}  mood [lofi|rain|jazz]"
      sleep 2
      break
    fi

    draw_header "$header_row"
    tick_wave
    draw_wave "$wave_top"
    draw_status "$status_row" "$mood" "$frame"

    (( frame++ ))
    sleep 0.10
  done
}

# --- Entry point ---
main() {
  local mode="${1:-record}"
  local mood
  mood=$(detect_mood)

  apply_mood_theme "$mood"

  # Guard: warn if no mpv process at all, but still allow launching
  if ! is_mood_running; then
    echo -e "${YELLOW}Warning:${NC} No mood audio detected."
    echo -e "Start one first:  ${BOLD}mood [lofi|rain|jazz]${NC}"
    echo -e "Launching visualizer anyway...\n"
    sleep 1
  fi

  # Auto-mode: pick based on detected mood
  if [[ "$mode" == "auto" ]]; then
    [[ "$mood" == "rain" ]] && mode="wave" || mode="record"
  fi

  case "$mode" in
    record) run_record  "$mood" ;;
    wave)   run_wave    "$mood" ;;
    *)
      echo -e "${RED}Usage:${NC} vinyl [record|wave|auto]"
      exit 1
      ;;
  esac
}

main "$@"