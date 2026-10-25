# tmux-ask

Bottom-right tmux popup for chatting with Claude about the pane you opened it from.
Uses your existing `claude` CLI login. Needs tmux 3.3+; `jq` optional (enables streaming).

## Install

Nix (home-manager), with `claude`, `jq` and `tmux` pinned onto the script's `PATH`:

```nix
# flake.nix
inputs.tmux-ask.url = "github:fruit-bird/tmux-ask";
inputs.tmux-ask.inputs.nixpkgs.follows = "nixpkgs";

# home-manager module
programs.tmux.plugins = [
  {
    plugin = inputs.tmux-ask.packages.${pkgs.stdenv.hostPlatform.system}.default;
    extraConfig = ''
      set -g @ask-model haiku
    '';
  }
];
```

`.override { claude-code = ...; tmux = ...; }` swaps in your own packages, and
`overlays.default` adds it as `pkgs.tmuxPlugins.tmux-ask`.

TPM:

```tmux
set -g @plugin 'fruit-bird/tmux-ask'
```

Manual: clone anywhere, then in `~/.tmux.conf`:

```tmux
run-shell ~/path/to/tmux-ask/tmux-ask.tmux
```

Or skip the plugin file and bind it yourself:

```tmux
bind a display-popup -E -x R -y S -w 50% -h 50% -b rounded -T ' claude ' \
  -d '#{pane_current_path}' "~/path/to/tmux-ask/scripts/ask.sh"
# no-prefix variant: bind -n M-? display-popup ...
```

## Options

| option               | default    | meaning                                             |
|----------------------|------------|-----------------------------------------------------|
| `@ask-key`           | `a`        | key after prefix (`?` works but shadows list-keys)  |
| `@ask-width/height`  | `50%`      | popup size                                          |
| `@ask-border`        | `rounded`  | popup border style                                  |
| `@ask-lines`         | `200`      | scrollback lines sent as context                    |
| `@ask-model`         | `haiku`    | model for normal chat                               |
| `@ask-power-model`   | CLI default| model in `/x` mode, e.g. `sonnet`                   |
| `@ask-tools`         | `""`       | `""` = no tools (pure chat), `default` = all tools  |
| `@ask-system-prompt` | built in   | appended to Claude Code's system prompt             |
| `@ask-power-tools`   | `Bash,Read,Grep,Glob` | tools enabled + auto-approved in `/x` mode |
| `@ask-power-prompt`  | built in   | extra system prompt in `/x` mode (read-only rules)  |

## In the popup

- type a question; pane scrollback, cwd and running command go with the first message
- `/p` paste last code block into the pane (bracketed paste, not executed) and close
- `/x` toggle power mode: Claude may run shell commands and read files (prompt shows `⚡›`).
  Tools are pre-approved since the popup can't ask; "read-only" is only a prompt instruction
- `/r` re-read the pane on next message, `/n` new conversation, `/q`, `:q` or Ctrl-D quit
