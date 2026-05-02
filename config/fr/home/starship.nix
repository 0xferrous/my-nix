{ ... }:
{
  programs.starship = {
    # Enabled in ./enables.nix
  };

  fr.symlinks.configFiles."starship.toml".target = "config/fr/home/starship/gruvbox-rainbow.toml";
}
