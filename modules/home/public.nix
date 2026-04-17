{ config, lib, ... }:
let
  cfg = config.fr.public;
in
{
  options.fr.public.enable = lib.mkEnableOption "public Home Manager baseline";

  config = lib.mkIf cfg.enable { };
}
