{
  agentspace,
  vms,
  lib,
  wrapperOptionNames ? [
    "enable"
    "packageName"
    "socketActivation"
    "sshConnect"
    "impermanence"
  ],
}:
lib.mapAttrs (
  _name: vmConfig: agentspace.lib.mkSandbox (builtins.removeAttrs vmConfig wrapperOptionNames)
) vms
