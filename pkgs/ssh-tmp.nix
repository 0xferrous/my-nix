{
  bubblewrap,
  lib,
  openssh,
  writeShellApplication,
}:

writeShellApplication {
  name = "ssh-tmp";
  runtimeInputs = [
    bubblewrap
    openssh
  ];
  text = ''
    tmpdir=$(mktemp -d "''${TMPDIR:-/tmp}/ssh-tmp.XXXXXX")
    trap 'rm -rf "$tmpdir"' EXIT INT TERM

    key="$tmpdir/id_ed25519"
    ssh-keygen -q -t ed25519 -N "" -f "$key"

    # Expose only the Nix store and the small set of files needed for name
    # service. In particular, do not bind the host root (which would expose
    # the user's home and /tmp). /dev/null avoids all SSH configuration.
    # IdentitiesOnly and the cleared socket prevent other identities.
    status=0
    env -u SSH_AUTH_SOCK bwrap \
      --ro-bind /nix/store /nix/store \
      --dir /etc \
      --ro-bind /etc/passwd /etc/passwd \
      --ro-bind /etc/group /etc/group \
      --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
      --ro-bind /etc/resolv.conf /etc/resolv.conf \
      --ro-bind /etc/hosts /etc/hosts \
      --tmpfs /tmp \
      --ro-bind "$key" /tmp/id_ed25519 \
      --dev /dev \
      --proc /proc \
      --share-net \
      --setenv HOME /tmp \
      -- \
      ssh -F /dev/null -i /tmp/id_ed25519 \
      -o IdentitiesOnly=yes "$@" || status=$?
    exit "$status"
  '';
  meta = {
    description = "SSH with an ephemeral identity and empty configuration";
    homepage = "https://www.openssh.com/";
    license = lib.licenses.bsd2;
    mainProgram = "ssh-tmp";
  };
}
