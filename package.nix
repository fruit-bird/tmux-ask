{
  lib,
  tmuxPlugins,
  makeWrapper,
  claude-code,
  jq,
  tmux,
}:

tmuxPlugins.mkTmuxPlugin {
  pluginName = "tmux-ask";
  version = "0.1.0";
  rtpFilePath = "tmux-ask.tmux";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./tmux-ask.tmux
      ./scripts
    ];
  };

  nativeBuildInputs = [ makeWrapper ];

  # pin the popup's runtime deps; override `claude-code`/`tmux` to match your own
  postInstall = ''
    wrapProgram $target/scripts/ask.sh --prefix PATH : ${
      lib.makeBinPath [
        claude-code
        jq
        tmux
      ]
    }
  '';

  meta = {
    description = "tmux popup for chatting with Claude about the current pane";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
