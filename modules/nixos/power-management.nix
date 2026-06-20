{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fr.powerManagement;

  defaultTlpSettings = {
    CPU_SCALING_GOVERNOR_ON_AC = "performance";
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

    CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

    CPU_MIN_PERF_ON_AC = 0;
    CPU_MAX_PERF_ON_AC = cfg.tlp.cpuMaxPerfOnAc;
    CPU_MIN_PERF_ON_BAT = 0;
    CPU_MAX_PERF_ON_BAT = cfg.tlp.cpuMaxPerfOnBattery;

    WIFI_PWR_ON_AC = "off";
    WIFI_PWR_ON_BAT = "on";

    RUNTIME_PM_ON_AC = "on";
    RUNTIME_PM_ON_BAT = "auto";

    SATA_LINKPWR_ON_AC = "med_power_with_dipm";
    SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
  };

  chargeLimitSettings = lib.optionalAttrs cfg.tlp.chargeLimit.enable {
    "START_CHARGE_THRESH_${cfg.tlp.chargeLimit.battery}" = cfg.tlp.chargeLimit.start;
    "STOP_CHARGE_THRESH_${cfg.tlp.chargeLimit.battery}" = cfg.tlp.chargeLimit.stop;
  };
in
{
  options.fr.powerManagement = {
    enable = lib.mkEnableOption "comprehensive power management";

    upower.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable UPower for battery/device status reporting.";
    };

    powertop.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable powertop auto-tuning through NixOS powerManagement.";
    };

    packages.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install common power-management inspection/control tools.";
    };

    logind = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Apply laptop-oriented logind lid switch defaults.";
      };

      lidSwitch = lib.mkOption {
        type = lib.types.str;
        default = "suspend";
        description = "logind HandleLidSwitch value.";
      };

      lidSwitchExternalPower = lib.mkOption {
        type = lib.types.str;
        default = "lock";
        description = "logind HandleLidSwitchExternalPower value.";
      };

      lidSwitchDocked = lib.mkOption {
        type = lib.types.str;
        default = "ignore";
        description = "logind HandleLidSwitchDocked value.";
      };
    };

    cpu = {
      amdPstate.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the amd_pstate active kernel driver.";
      };

      maxCstate = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        example = 5;
        description = "Optional processor.max_cstate kernel parameter.";
      };
    };

    tlp = {
      cpuMaxPerfOnAc = lib.mkOption {
        type = lib.types.ints.between 0 100;
        default = 100;
        description = "Default CPU_MAX_PERF_ON_AC TLP setting.";
      };

      cpuMaxPerfOnBattery = lib.mkOption {
        type = lib.types.ints.between 0 100;
        default = 40;
        description = "Default CPU_MAX_PERF_ON_BAT TLP setting.";
      };

      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        example = {
          CPU_MAX_PERF_ON_BAT = 60;
          USB_AUTOSUSPEND = 1;
        };
        description = "Arbitrary extra TLP settings. These override this module's defaults and charge-limit-generated settings.";
      };

      chargeLimit = {
        enable = lib.mkEnableOption "TLP battery charge thresholds";

        battery = lib.mkOption {
          type = lib.types.str;
          default = "BAT0";
          description = "Battery identifier suffix used by TLP charge threshold keys.";
        };

        start = lib.mkOption {
          type = lib.types.ints.between 0 100;
          default = 40;
          description = "Start charging threshold percentage.";
        };

        stop = lib.mkOption {
          type = lib.types.ints.between 0 100;
          default = 80;
          description = "Stop charging threshold percentage.";
        };
      };
    };
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    assertions = [
      {
        assertion = cfg.tlp.chargeLimit.start < cfg.tlp.chargeLimit.stop;
        message = "fr.powerManagement.tlp.chargeLimit.start must be lower than .stop.";
      }
    ];

    boot.kernelParams =
      lib.optionals cfg.cpu.amdPstate.enable [ "amd_pstate=active" ]
      ++ lib.optionals (cfg.cpu.maxCstate != null) [
        "processor.max_cstate=${toString cfg.cpu.maxCstate}"
      ];

    services.upower.enable = lib.mkDefault cfg.upower.enable;

    powerManagement = {
      enable = lib.mkDefault true;
      powertop.enable = lib.mkDefault cfg.powertop.enable;
    };

    services.tlp = {
      enable = lib.mkDefault true;
      settings = defaultTlpSettings // chargeLimitSettings // cfg.tlp.settings;
    };

    services.logind = lib.mkIf cfg.logind.enable {
      lidSwitch = lib.mkDefault cfg.logind.lidSwitch;
      lidSwitchExternalPower = lib.mkDefault cfg.logind.lidSwitchExternalPower;
      lidSwitchDocked = lib.mkDefault cfg.logind.lidSwitchDocked;
    };

    environment.systemPackages = lib.mkIf cfg.packages.enable (
      with pkgs;
      [
        acpi
        brightnessctl
        powertop
        upower
      ]
      ++ [ tlp ]
    );
  };
}
