{ lib, pkgs, ... }:
{
  programs.jujutsu.settings = {
    signing = {
      behavior = lib.mkDefault "own";
      backend = lib.mkDefault "gpg";
      backends.gpg.program = lib.mkDefault "${pkgs.sequoia-chameleon-gnupg}/bin/gpg-sq";
    };

    ui = {
      editor = lib.mkDefault "nvim";
      pager = lib.mkDefault "delta";
      diff-formatter = lib.mkDefault ":git";
    };

    git = {
      fetch = lib.mkDefault [
        "upstream"
        "origin"
      ];
      push = lib.mkDefault "origin";
    };

    revset-aliases = {
      "to_push()" = lib.mkDefault "mine() & mutable() & bookmarks()";
      "to_rebase()" = lib.mkDefault "roots(mine() & mutable())";
    };
  };
}
