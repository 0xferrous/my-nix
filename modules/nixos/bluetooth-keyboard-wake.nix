{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fr.powerManagement.bluetoothKeyboardWake;

  # udev cannot express the AC-only policy by itself, so these rules only wake
  # the oneshot whenever one of the configured USB devices is added/rebound.
  # The service then decides whether to enable or disable wake based on the
  # current power source.
  bluetoothWakeUdevRules = lib.concatMapStringsSep "\n" (device: ''
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="${device.vendorId}", ATTR{idProduct}=="${device.productId}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="bluetooth-keyboard-wakeup.service"
  '') cfg.usbDevices;
in
{
  options.fr.powerManagement.bluetoothKeyboardWake = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Keep Bluetooth USB devices wake-enabled for closed-lid keyboard wake from suspend.";
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
      description = "Manage AC-only wake from internal Bluetooth keyboards";
      wantedBy = [
        "multi-user.target"
        "sleep.target"
      ];
      # Run once at boot, again immediately before suspend, and from udev on
      # relevant device/power events.  The pre-sleep run is important because
      # runtime power-management tools may have changed sysfs values since boot.
      before = [ "sleep.target" ];
      path = [ pkgs.coreutils ];
      serviceConfig.Type = "oneshot";
      script = ''
        shopt -s nullglob

        # Treat any online non-battery power_supply as AC/external power.  This
        # covers AC adapters, USB-C docks, and other firmware-specific names.
        ac_online=false
        for supply in /sys/class/power_supply/*; do
          if [ -r "$supply/online" ] \
            && [ -r "$supply/type" ] \
            && [ "$(cat "$supply/online")" = 1 ] \
            && [ "$(cat "$supply/type")" != Battery ]; then
            ac_online=true
            break
          fi
        done

        # On AC, keep the Bluetooth USB path armed for closed-lid keyboard wake.
        # On battery, hand it back to normal autosuspend and disable wake so this
        # feature does not cost idle/suspend battery life.
        if $ac_online; then
          wakeup=enabled
          control=on
        else
          wakeup=disabled
          control=auto
        fi

        # Start from each Bluetooth controller, resolve its backing device, then
        # walk up the parent chain.  Internal Bluetooth commonly appears as a USB
        # device behind an internal hub; both the adapter and hub may need wake
        # enabled for a keyboard event to reach the sleeping system.
        for hci in /sys/class/bluetooth/hci*; do
          dev="$(${pkgs.coreutils}/bin/readlink -f "$hci/device")"

          while [ "$dev" != /sys/devices ] && [ "$dev" != / ]; do
            # power/wakeup controls whether this device may wake the system from
            # suspend.  Some parents do not expose it, so only write when present.
            if [ -w "$dev/power/wakeup" ]; then
              echo "$wakeup" > "$dev/power/wakeup"
            fi

            # Only real USB device nodes have busnum.  On AC, keep Bluetooth's
            # USB chain active for wake; on battery, return it to autosuspend.
            if [ -e "$dev/busnum" ] && [ -w "$dev/power/control" ]; then
              echo "$control" > "$dev/power/control"
            fi

            dev="$(dirname "$dev")"
          done
        done
      '';
    };
  };
}
