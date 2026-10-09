{
  bbPackage,
  lib,
  writeShellApplication,
}:

writeShellApplication {
  name = "bb-connect";
  text = ''
    usage() {
      cat >&2 <<'EOF'
    Usage: bb-connect --profile NAME URL [BB_DESKTOP_ARGS...]

    Connect bb desktop to URL using an isolated configuration profile.
    EOF
    }

    if [[ ''${1:-} == "--help" || ''${1:-} == "-h" ]]; then
      usage
      exit 0
    fi

    if [[ ''${1:-} != "--profile" || $# -lt 3 ]]; then
      usage
      exit 2
    fi

    profile=$2
    remote_url=$3
    shift 3

    case $profile in
      ""|.|..|*/*|*\\*)
        echo "bb-connect: profile must be a single path component" >&2
        exit 2
        ;;
    esac

    export XDG_CONFIG_HOME="$HOME/.config/bb-profiles/$profile"
    export BB_DESKTOP_REMOTE_URL="$remote_url"

    exec ${bbPackage}/bin/bb-desktop "$@"
  '';
  meta = {
    description = "Connect bb desktop to a remote server using a named profile";
    homepage = "https://getbb.app";
    license = lib.licenses.mit;
    mainProgram = "bb-connect";
    platforms = lib.platforms.linux;
  };
}
