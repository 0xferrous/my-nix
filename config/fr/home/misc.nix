{
  config,
  lib,
  pkgs,
  ...
}:
let
  carapaceBin = lib.getExe config.programs.carapace.package;
  fzfBin = lib.getExe config.programs.fzf.package;
in
{
  programs.carapace = {
    enable = true;
    # Carapace 1.7.1's generated integration uses `upsert` in a way that leaves
    # the external completer null on Nushell 0.115. Patch the generated tail
    # until upstream emits a direct assignment compatible with current Nushell.
    enableNushellIntegration = false;
  };

  programs.nushell.extraConfig = lib.mkBefore ''
    source ${
      pkgs.runCommand "carapace-nushell-config-patched.nu" { } ''
        ${carapaceBin} _carapace nushell \
          | sed '/^mut current =/,$d' > "$out"
        echo '$env.config.completions.external.completer = $carapace_completer' >> "$out"
      ''
    }

    source ${
      pkgs.runCommand "fzf-nushell-config-patched.nu" { } ''
              ${fzfBin} --nushell \
                | sed \
                    -e 's/str downcase/str lowercase/g' \
                    -e 's@let spans = $buffer | split words@let spans = if ($buffer ends-with " ") { $buffer | split words | append "" } else { $buffer | split words }@' \
                    -e '/^  \$env.config = \$env.config | upsert completions {$/,/^  }$/c\  $env.config.completions.external.enable = true\
        $env.config.completions.external.completer = $fzf_wrapper_completer' \
                > "$out"
      ''
    }
  '';

  programs.caelestia = {
    enable = false;
    systemd = {
      enable = false; # if you prefer starting from your compositor
      target = "graphical-session.target";
      environment = [ ];
    };
    settings = {
      bar.status = {
        showBattery = false;
      };
      paths.wallpaperDir = "~/Images";
    };
    cli = {
      enable = true; # Also add caelestia-cli to path
      settings = {
        theme.enableGtk = false;
      };
    };
  };
}
