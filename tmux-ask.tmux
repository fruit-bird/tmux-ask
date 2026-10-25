#!/usr/bin/env bash
# TPM entry point: binds a key that opens a Claude chat popup for the current pane.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

opt() { local v; v=$(tmux show-option -gqv "$1"); echo "${v:-$2}"; }

key=$(opt @ask-key a)
width=$(opt @ask-width 50%)
height=$(opt @ask-height 50%)
border=$(opt @ask-border rounded)

tmux bind-key "$key" display-popup -E \
  -x R -y S -w "$width" -h "$height" -b "$border" -T ' claude ' \
  -d '#{pane_current_path}' \
  "'$DIR/scripts/ask.sh'"
