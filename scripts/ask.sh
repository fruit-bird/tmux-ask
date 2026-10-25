#!/usr/bin/env bash
# Chat with Claude about a tmux pane. Usage: ask.sh [pane_id]
# Runs inside a display-popup; uses the existing `claude` CLI login.
set -u

# Default to the active pane: inside a popup that's the pane it was opened from.
PANE="${1:-}"
case "$PANE" in %*) ;; *) PANE=$(tmux display-message -p '#{pane_id}') ;; esac

opt() { local v; v=$(tmux show-option -gqv "$1"); echo "${v:-$2}"; }

HISTORY_LINES=$(opt @ask-lines 200)
MODEL=$(opt @ask-model haiku)
POWER_MODEL=$(opt @ask-power-model "")  # "" = CLI default
TOOLS=$(opt @ask-tools "")          # "" = no tools (pure chat), "default" = all
# /x mode: these tools are enabled *and* pre-approved (-p can't prompt).
POWER_TOOLS=$(opt @ask-power-tools "Bash,Read,Grep,Glob")
POWER_PROMPT=$(opt @ask-power-prompt "Power mode: you may run shell commands and read files to gather context beyond the snapshot (git status/log/diff, config files, logs, --help output). Only inspect; never modify files, install anything, or run commands with side effects. Keep exploration brief.")
power=0
SYSTEM_PROMPT=$(opt @ask-system-prompt "You are a terminal debugging assistant running in a small tmux popup next to the user's shell. You are given a snapshot of their tmux pane (scrollback, cwd, running command). Be concise: short paragraphs, no headings, no tables, lines under 80 chars. When suggesting a command, put exactly one in a single \`\`\`sh fenced block so it can be pasted into the pane. Base answers on the snapshot; say so when it lacks what you need.")

DIM=$'\033[2m'; BOLD=$'\033[1m'; CYAN=$'\033[36m'; RESET=$'\033[0m'

new_session() {
  : > "${LAST:-/dev/null}"
  SESSION=$(uuidgen | tr '[:upper:]' '[:lower:]')
  started=0
  need_context=1
}

snapshot() {
  local cwd cmd screen
  cwd=$(tmux display-message -p -t "$PANE" '#{pane_current_path}')
  cmd=$(tmux display-message -p -t "$PANE" '#{pane_current_command}')
  screen=$(tmux capture-pane -p -J -t "$PANE" -S "-$HISTORY_LINES" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
  printf '<pane cwd="%s" command="%s">\n%s\n</pane>\n\n' "$cwd" "$cmd" "$screen"
}

# Last fenced code block in the conversation so far.
last_block() {
  awk '/^```/ { if (inb) { inb = 0; blk = cur } else { inb = 1; cur = "" } next }
       inb    { cur = cur $0 "\n" }
       END    { printf "%s", blk }' "$LAST" | sed -e '$ { /^$/d; }'
}

ask() {
  local msg="$1" args=(-p) model
  if [ "$power" = 1 ]; then
    args+=(--append-system-prompt "$SYSTEM_PROMPT $POWER_PROMPT" --tools "$POWER_TOOLS" --allowedTools "$POWER_TOOLS")
    model="$POWER_MODEL"
  else
    args+=(--append-system-prompt "$SYSTEM_PROMPT" --tools "$TOOLS")
    model="$MODEL"
  fi
  [ -n "$model" ] && args+=(--model "$model")
  if [ "$started" = 1 ]; then args+=(--resume "$SESSION"); else args+=(--session-id "$SESSION"); fi

  printf '%sthinking…%s\n' "$DIM" "$RESET"
  if command -v jq >/dev/null; then
    claude "${args[@]}" --output-format stream-json --verbose --include-partial-messages "$msg" \
      | jq -rj --unbuffered --arg dim "$DIM" --arg reset "$RESET" '
          if .type == "stream_event" and .event.type == "content_block_delta"
             and .event.delta.type == "text_delta" then .event.delta.text
          elif .type == "assistant" then
            .message.content[] | select(.type == "tool_use")
            | "\n\($dim)· \(.name) \(.input.command // .input.file_path // .input.pattern // "")\($reset)\n"
          else empty end' \
      | tee -a "$LAST"
  else
    claude "${args[@]}" "$msg" | tee -a "$LAST"
  fi
  printf '\n\n'
  started=1
}

help() {
  printf '%s/p%s paste last code block into pane   %s/r%s re-read pane\n' "$CYAN" "$RESET" "$CYAN" "$RESET"
  printf '%s/n%s new conversation                   %s/q%s quit (or :q, Ctrl-D)\n' "$CYAN" "$RESET" "$CYAN" "$RESET"
  printf '%s/x%s toggle power mode (shell + file access: %s)\n\n' "$CYAN" "$RESET" "$POWER_TOOLS"
}

prompt() { if [ "$power" = 1 ]; then printf '%s⚡› %s' "$CYAN" "$RESET"; else printf '%s› %s' "$CYAN" "$RESET"; fi; }

LAST=$(mktemp -t tmux-ask.XXXXXX)
trap 'rm -f "$LAST"' EXIT
cd "$(tmux display-message -p -t "$PANE" '#{pane_current_path}')" 2>/dev/null || true

new_session
printf '%sAsk about pane %s%s  %s(/? for commands)%s\n\n' "$BOLD" "$PANE" "$RESET" "$DIM" "$RESET"

while IFS= read -e -r -p "$(prompt)" line; do
  [ -z "${line// }" ] && continue
  history -s -- "$line"
  case "$line" in
    /q|/quit|/exit|:q|:q!|:wq) exit 0 ;;
    /\?|/h|/help) help ;;
    /n|/new) new_session; printf '%snew conversation%s\n\n' "$DIM" "$RESET" ;;
    /x|/power)
      power=$((1 - power))
      if [ "$power" = 1 ]; then printf '%spower mode on: Claude can run %s%s\n\n' "$DIM" "$POWER_TOOLS" "$RESET"
      else printf '%spower mode off%s\n\n' "$DIM" "$RESET"; fi ;;
    /r|/refresh) need_context=1; printf '%spane will be re-read on next message%s\n\n' "$DIM" "$RESET" ;;
    /p|/paste)
      code=$(last_block)
      if [ -z "$code" ]; then printf '%sno code block in last answer%s\n\n' "$DIM" "$RESET"; continue; fi
      printf '%s' "$code" | tmux load-buffer -b tmux-ask -
      tmux paste-buffer -p -d -b tmux-ask -t "$PANE"
      exit 0 ;;
    *)
      msg="$line"
      if [ "$need_context" = 1 ]; then msg="$(snapshot)$line"; need_context=0; fi
      ask "$msg" ;;
  esac
done
