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
      show-cryptographic-signatures = lib.mkDefault true;
    };

    template-aliases."format_short_cryptographic_signature(sig)" = lib.mkDefault ''
      if(
        sig,
        if(sig.status() == "good", "✓", "⚠"),
        "✗",
      )
    '';

    # Override the alias used by the built-in compact log so the committer is
    # shown next to the author only when the two identities differ.
    template-aliases."format_short_commit_header(commit)" = lib.mkDefault ''
      separate(" ",
        format_short_change_id_with_change_offset(commit),
        if(
          commit.author().email() != commit.committer().email(),
          separate(" / ",
            format_short_signature(commit.author()),
            format_short_signature(commit.committer()),
          ),
          format_short_signature(commit.author()),
        ),
        format_timestamp(commit_timestamp(commit)),
        commit.bookmarks(),
        commit.tags(),
        commit.working_copies(),
        format_short_commit_id(commit.commit_id()),
        format_commit_labels(commit),
        if(config("ui.show-cryptographic-signatures").as_boolean(),
          format_short_cryptographic_signature(commit.signature())
        ),
      )
    '';

    git = {
      fetch = lib.mkDefault [
        "upstream"
        "origin"
      ];
      push = lib.mkDefault "origin";
    };

    revsets.bookmark-advance-to = lib.mkDefault "closest_pushable(@)";

    revset-aliases = {
      "closest_pushable(to)" =
        lib.mkDefault "heads(::to & mutable() & ~description(exact:\"\") & (~empty() | merges()))";
      "to_push()" = lib.mkDefault "mine() & mutable() & bookmarks()";
      "to_rebase()" = lib.mkDefault "roots(mine() & mutable())";
    };
  };
}
