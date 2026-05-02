{ pkgs, myNixInputs, ... }:
let
  nvimPkg = myNixInputs.frs-nvim.packages.${pkgs.system}.default;
in
{
  # Use pre-wrapped Neovim package from frs-nvim directly.
  # Home Manager's programs.neovim module wraps again, which breaks for this package.
  home.packages = [ nvimPkg ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.shellAliases = {
    vi = "nvim";
    vim = "nvim";
    vimdiff = "nvim -d";
  };
}
