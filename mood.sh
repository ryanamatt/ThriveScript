#!/bin/bash

# mood.sh - A terminal-based background music utility.

# This script uses mpv to stream curated YouTube playlists (lofi, rain, jazz) 
# in the background. It provides a simple CLI for starting and stopping 
# ambient audio without opening a browser or a GUI.
#

# Define Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Define "moods" in an associative array (requires Bash 4+)
declare -A playlists
playlists=(
  ["lofi"]="https://www.youtube.com/watch?v=jfKfPfyJRdk"
  ["rain"]="https://www.youtube.com/watch?v=mPZkdNFkNps"
  ["jazz"]="https://www.youtube.com/watch?v=neV3EPgvZ3g"
)

# Check if the user wants to stop the music
if [[ "$1" == "stop" ]]; then
  echo -e "${RED}Stopping the music...${NC}"
  pkill mpv
  rm -f "$HOME/.mood_state"
  exit 0
fi

# Check if a mood was provided
if [[ -z "$1" || -z "${playlists[$1]}" ]]; then
  echo -e "${BLUE}Usage:${NC} mood [stop|lofi|rain|jazz]"
  exit 1
fi

echo -e "${GREEN}Setting the mood: $1...${NC}"

# Write current mood to state file so vinyl can read it instantly
echo "$1" > "$HOME/.mood_state"

# Execute mpv with specific flags for terminal background play
mpv --no-video \
    --ytdl-format="bestaudio/best" \
    --really-quiet \
    --cache=yes \
    "${playlists[$1]}" > /dev/null 2>&1 &

echo -e "Playlist is running in the background. Use 'mood ${RED}stop${NC}' to stop."