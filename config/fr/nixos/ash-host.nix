{ ... }:
{
  # Root-managed Ash virtiofsd services must traverse bindfs staging mounts.
  programs.fuse.userAllowOther = true;

  # Ash/QEMU stress large VirtIO-FS file sets from both foreground shells and
  # user-systemd services.
  systemd.settings.Manager.DefaultLimitNOFILE = "2000000:2000000";
  systemd.user.settings.Manager.DefaultLimitNOFILE = "2000000:2000000";
  # The user manager itself is started by the system manager, so its hard
  # limit must be raised explicitly before it can raise limits for QEMU.
  systemd.services."user@".serviceConfig.LimitNOFILE = "2000000:2000000";
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "-";
      item = "nofile";
      value = "2000000";
    }
  ];
}
