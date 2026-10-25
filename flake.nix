{
  description = "tmux popup for chatting with Claude about the current pane";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          # claude-code is unfree
          config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "claude-code";
        };
    in
    {
      packages = forAllSystems (system: {
        default = (pkgsFor system).callPackage ./package.nix { };
      });

      overlays.default = final: prev: {
        tmuxPlugins = prev.tmuxPlugins // {
          tmux-ask = final.callPackage ./package.nix { };
        };
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
