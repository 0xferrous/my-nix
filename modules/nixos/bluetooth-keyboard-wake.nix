{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fr.powerManagement.bluetoothKeyboardWake;

  bluetoothKeyboardWakePolicy = import ./bluetooth-keyboard-wake-policy.nix {
    inherit lib pkgs;
    inherit (cfg) requireExternalDisplay;
  };

  # udev cannot express the AC-only policy by itself, so these rules only wake
  # the oneshot whenever one of the configured USB devices is added/rebound.
  # The service then decides whether to enable or disable wake based on the
  # current power source.
  bluetoothWakeUdevRules = lib.concatMapStringsSep "\n" (device: ''
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="${device.vendorId}", ATTR{idProduct}=="${device.productId}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="bluetooth-keyboard-wakeup.service"
  '') cfg.usbDevices;

  bluetoothPostResumeReset = pkgs.writeShellApplication {
    name = "bluetooth-post-resume-reset";
    runtimeInputs = [
      pkgs.bluez
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      shopt -s nullglob

      sleep ${toString cfg.resetAfterResume.delaySeconds}

      echo "bluetooth-post-resume-reset: resetting bluetooth controller after resume"

      # A bluetoothd restart is not always enough for this MediaTek adapter; the
      # inconsistent LE scan/connect state can live in the kernel btusb device.
      # Try a lightweight BlueZ power cycle first, then unbind/rebind btusb.
      bluetoothctl power off || true
      sleep 1

      rebound=false
      for hci in /sys/class/bluetooth/hci*; do
        dev="$(readlink -f "$hci/device")"
        if [ -L "$dev/driver" ]; then
          driver="$(readlink -f "$dev/driver")"
          device_name="$(basename "$dev")"
          if [ -w "$driver/unbind" ] && [ -w "$driver/bind" ]; then
            echo "bluetooth-post-resume-reset: rebinding $device_name via $driver"
            echo "$device_name" > "$driver/unbind" || true
            sleep 1
            echo "$device_name" > "$driver/bind" || true
            rebound=true
          fi
        fi
      done

      sleep 2
      systemctl try-restart bluetooth.service || true
      sleep 1
      bluetoothctl power on || true

      if ! $rebound; then
        echo "bluetooth-post-resume-reset: no bindable bluetooth controller found"
      fi
    '';
  };
in
{
  options.fr.powerManagement.bluetoothKeyboardWake = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Keep Bluetooth USB devices wake-enabled for closed-lid keyboard wake from suspend.";
    };

    requireExternalDisplay = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Only enable Bluetooth wake when an external DRM display connector is attached.";
    };

    usbDevices = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            vendorId = lib.mkOption {
              type = lib.types.str;
              example = "0e8d";
              description = "USB vendor ID.";
            };

            productId = lib.mkOption {
              type = lib.types.str;
              example = "e025";
              description = "USB product ID.";
            };
          };
        }
      );
      default = [ ];
      example = [
        {
          vendorId = "0e8d";
          productId = "e025";
        }
      ];
      description = "USB devices whose Bluetooth wake policy should be managed while on AC power.";
    };

    resetAfterResume = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Hard-reset the Bluetooth controller after resume to recover wedged BLE HID connections.";
      };

      delaySeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3;
        description = "Seconds to wait after resume before resetting Bluetooth.";
      };
    };
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    services.udev.extraRules = ''
      # Re-apply Bluetooth keyboard wake policy when the adapter is added/rebound
      # or when AC/battery state changes.  The rule starts the systemd oneshot;
      # it intentionally does not write power/wakeup directly, because the value
      # depends on whether external power is currently online.
      ${bluetoothWakeUdevRules}
      ACTION=="change", SUBSYSTEM=="power_supply", TAG+="systemd", ENV{SYSTEMD_WANTS}+="bluetooth-keyboard-wakeup.service"
    '';

    systemd.services.bluetooth-keyboard-wakeup = {
      description = "Manage docked Bluetooth wake policy";
      unitConfig.StartLimitIntervalSec = 0;
      wantedBy = [
        "multi-user.target"
        "sleep.target"
      ];
      # Run once at boot, again immediately before suspend, and from udev on
      # relevant device/power events.  The pre-sleep run is important because
      # runtime power-management tools may have changed sysfs values since boot.
      before = [ "sleep.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${bluetoothKeyboardWakePolicy}/bin/bluetooth-keyboard-wakeup";
        LogRateLimitIntervalSec = 0;
      };
    };

    systemd.services.bluetooth-post-resume-reset = lib.mkIf cfg.resetAfterResume.enable {
      description = "Reset Bluetooth controller after resume";
      after = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];
      wantedBy = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${bluetoothPostResumeReset}/bin/bluetooth-post-resume-reset";
        LogRateLimitIntervalSec = 0;
      };
    };
  };
}
