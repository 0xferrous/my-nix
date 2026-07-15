{
  lib,
  pkgs,
  requireExternalDisplay ? true,
}:

pkgs.writeShellApplication {
  name = "bluetooth-keyboard-wakeup";
  runtimeInputs = [ pkgs.coreutils ];
  text = ''
    shopt -s nullglob

    require_external_display=${lib.boolToString requireExternalDisplay}

    # Treat any online non-battery power_supply as AC/external power. This
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

    # Detect an attached external display through DRM connector status. Skip
    # built-in panel connector families.
    external_display_connected=false
    for connector in /sys/class/drm/card*-*; do
      name="$(basename "$connector")"
      case "$name" in
        *-eDP-*|*-LVDS-*|*-DSI-*)
          continue
          ;;
      esac

      if [ -r "$connector/status" ] && [ "$(cat "$connector/status")" = connected ]; then
        external_display_connected=true
        break
      fi
    done

    # Arm Bluetooth controller wake only in the intended docked case: external
    # power and, by default, at least one external display. This prevents
    # Bluetooth events such as headset AVRCP reconnects from waking/draining an
    # undocked laptop.
    enable_wake=false
    if $ac_online; then
      if $require_external_display; then
        if $external_display_connected; then
          enable_wake=true
        fi
      else
        enable_wake=true
      fi
    fi

    if $enable_wake; then
      wakeup=enabled
      control=on
    else
      wakeup=disabled
      control=auto
    fi

    echo "bluetooth-keyboard-wakeup: ac_online=$ac_online external_display_connected=$external_display_connected require_external_display=$require_external_display enable_wake=$enable_wake wakeup=$wakeup control=$control"

    # Start from each Bluetooth controller, resolve its backing device, then
    # walk up the parent chain. Internal Bluetooth commonly appears as a USB
    # device behind an internal hub; both the adapter and hub may need wake
    # enabled for a keyboard event to reach the sleeping system.
    for hci in /sys/class/bluetooth/hci*; do
      dev="$(readlink -f "$hci/device")"

      while [ "$dev" != /sys/devices ] && [ "$dev" != / ]; do
        # power/wakeup controls whether this device may wake the system from
        # suspend. Some parents do not expose it, so only write when present.
        if [ -w "$dev/power/wakeup" ]; then
          old_wakeup="$(cat "$dev/power/wakeup" 2>/dev/null || true)"
          echo "$wakeup" > "$dev/power/wakeup"
          echo "bluetooth-keyboard-wakeup: $dev power/wakeup $old_wakeup -> $wakeup"
        fi

        # Only real USB device nodes have busnum. In the enabled case, keep
        # Bluetooth's USB chain active for wake; otherwise return it to
        # autosuspend.
        if [ -e "$dev/busnum" ] && [ -w "$dev/power/control" ]; then
          old_control="$(cat "$dev/power/control" 2>/dev/null || true)"
          echo "$control" > "$dev/power/control"
          echo "bluetooth-keyboard-wakeup: $dev power/control $old_control -> $control"
        fi

        dev="$(dirname "$dev")"
      done
    done
  '';
}
