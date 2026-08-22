{
  lib,
  stdenv,
  writeShellApplication,
  AIPackages,
  bubblewrap,
  coreutils,
  nix,
  pkgs,
  nushell,
  pi,
  codex,
  opencode,
}:
let
  devEssentialPackages = import ../config/shared/packages/dev-essentials.nix {
    inherit AIPackages pkgs;
    includeAbwrap = false;
  };

  sandboxPackages = devEssentialPackages ++ [
    coreutils
    nix
    nushell
    pi
    codex
    opencode
  ];

  tiocstiSeccompFilter = stdenv.mkDerivation {
    pname = "abwrap-tiocsti-seccomp-filter";
    version = "1";
    dontUnpack = true;

    buildPhase = ''
      cat > filter.c <<'EOF'
      #include <errno.h>
      #include <linux/audit.h>
      #include <linux/filter.h>
      #include <linux/seccomp.h>
      #include <stddef.h>
      #include <stdio.h>
      #include <sys/ioctl.h>
      #include <sys/syscall.h>

      #if defined(__x86_64__)
      #define ABWRAP_AUDIT_ARCH AUDIT_ARCH_X86_64
      #elif defined(__aarch64__)
      #define ABWRAP_AUDIT_ARCH AUDIT_ARCH_AARCH64
      #else
      #error "abwrap seccomp filter supports only x86_64 and aarch64"
      #endif

      int main(void) {
        const struct sock_filter filter[] = {
          BPF_STMT(
            BPF_LD | BPF_W | BPF_ABS,
            offsetof(struct seccomp_data, arch)
          ),
          BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, ABWRAP_AUDIT_ARCH, 1, 0),
          BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_KILL_PROCESS),
          BPF_STMT(
            BPF_LD | BPF_W | BPF_ABS,
            offsetof(struct seccomp_data, nr)
          ),
      #if defined(__x86_64__)
          BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_ioctl, 1, 0),
          BPF_JUMP(
            BPF_JMP | BPF_JEQ | BPF_K,
            __NR_ioctl | 0x40000000U,
            0,
            3
          ),
      #else
          BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_ioctl, 0, 3),
      #endif
          BPF_STMT(
            BPF_LD | BPF_W | BPF_ABS,
            offsetof(struct seccomp_data, args[1])
          ),
          BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, TIOCSTI, 0, 1),
          BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | EPERM),
          BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
        };

        if (fwrite(filter, sizeof(filter), 1, stdout) != 1) {
          perror("fwrite");
          return 1;
        }
        return 0;
      }
      EOF

      $CC filter.c -o abwrap-tiocsti-seccomp-filter
    '';

    installPhase = ''
      mkdir -p "$out/bin"
      install -m755 abwrap-tiocsti-seccomp-filter "$out/bin/"
    '';
  };
in
writeShellApplication {
  name = "abwrap";
  runtimeInputs = sandboxPackages;
  text = ''
    usage() {
      printf '%s\n' \
        'Usage: abwrap [OPTIONS] [COMMAND [ARGS...]]' \
        '       abwrap [OPTIONS] -- [COMMAND [ARGS...]]' \
        \
        'Run Nushell or another command in an isolated filesystem.' \
        'The default entrypoint is Nushell. pi, codex, opencode, and' \
        'dev-essentials are available on PATH.' \
        \
        'Each invocation gets an independent writable Nix local-overlay store' \
        'in /tmp. Host paths and environment variables are visible only when' \
        'explicitly exposed. State for a directly selected agent is mounted' \
        'automatically; other tool state can be requested explicitly.' \
        \
        'Options:' \
        '  --ro PATH              expose an existing host path read-only' \
        '  --rw PATH              expose an existing host path read-write' \
        '  --env NAME             forward an environment variable if set' \
        '  --tool-state TOOL      mount pi, codex, opencode, all, or none state' \
        '  -e, --entrypoint CMD   use CMD instead of Nushell' \
        '  -h, --help             show this help' \
        \
        'Examples:' \
        "  abwrap --rw \"\$PWD\"" \
        "  abwrap --rw \"\$PWD\" pi --model openai/gpt-5" \
        "  abwrap --env OPENAI_API_KEY --rw \"\$PWD\" codex" \
        "  abwrap --tool-state pi --rw \"\$PWD\"" \
        "  abwrap --rw \"\$PWD\" opencode"
    }

    if [[ -z "''${HOME:-}" || ! -d "$HOME" ]]; then
      echo "abwrap: HOME must exist" >&2
      exit 2
    fi

    home=$(realpath -e -- "$HOME")
    nix_overlay=$(mktemp -d /tmp/abwrap-nix.XXXXXXXXXX)
    mkdir -p \
      "$nix_overlay/upper" \
      "$nix_overlay/work" \
      "$nix_overlay/state"

    # Invoked indirectly by the EXIT trap below.
    # shellcheck disable=SC2329
    cleanup_overlay() {
      # Nix store objects are read-only, including those in the upper layer.
      chmod -R u+w "$nix_overlay" 2>/dev/null || true
      rm -rf -- "$nix_overlay"
    }
    trap cleanup_overlay EXIT

    # The lower store database is mounted read-only. The nested lower-store
    # query marker must be percent-encoded because it is itself inside the
    # overlay store URI. Bubblewrap reports backing paths as /oldroot/... in
    # /proc/self/mounts, so disable Nix's incompatible path-name check.
    overlay_store="local-overlay://?root=/&lower-store=/run/abwrap/lower%3Fread-only=true&upper-layer=/run/abwrap/overlay/upper&state=/run/abwrap/overlay/state&check-mount=false"
    nix_config='extra-experimental-features = nix-command flakes local-overlay-store read-only-local-store
    sandbox = false'

    ${tiocstiSeccompFilter}/bin/abwrap-tiocsti-seccomp-filter > "$nix_overlay/tiocsti-seccomp.bpf"
    exec {seccomp_fd}< "$nix_overlay/tiocsti-seccomp.bpf"

    entrypoint=${lib.escapeShellArg (lib.getExe nushell)}
    entrypoint_explicit=false
    auto_tool_state=true
    mount_pi_state=false
    mount_codex_state=false
    mount_opencode_state=false
    mounts=()
    forwarded_env=()

    forward_environment() {
      local name="$1"
      if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "abwrap: invalid environment variable name: $name" >&2
        exit 2
      fi
      if [[ -v "$name" ]]; then
        forwarded_env+=(--setenv "$name" "''${!name}")
      fi
    }

    enable_tool_state() {
      case "$1" in
        pi)
          mount_pi_state=true
          ;;
        codex)
          mount_codex_state=true
          ;;
        opencode)
          mount_opencode_state=true
          ;;
        all)
          mount_pi_state=true
          mount_codex_state=true
          mount_opencode_state=true
          ;;
        none)
          auto_tool_state=false
          mount_pi_state=false
          mount_codex_state=false
          mount_opencode_state=false
          ;;
        *)
          echo "abwrap: unknown tool state: $1" >&2
          echo 'abwrap: expected pi, codex, opencode, all, or none' >&2
          exit 2
          ;;
      esac
    }

    while (( $# > 0 )); do
      case "$1" in
        --ro|--rw)
          mode="$1"
          if (( $# < 2 )); then
            echo "abwrap: $mode requires a path" >&2
            exit 2
          fi
          path=$(realpath -e -- "$2") || {
            echo "abwrap: path does not exist: $2" >&2
            exit 2
          }
          if [[ "$mode" == "--ro" ]]; then
            mounts+=(--ro-bind "$path" "$path")
          else
            mounts+=(--bind "$path" "$path")
          fi
          shift 2
          ;;
        --ro=*|--rw=*)
          mode="''${1%%=*}"
          value="''${1#*=}"
          path=$(realpath -e -- "$value") || {
            echo "abwrap: path does not exist: $value" >&2
            exit 2
          }
          if [[ "$mode" == "--ro" ]]; then
            mounts+=(--ro-bind "$path" "$path")
          else
            mounts+=(--bind "$path" "$path")
          fi
          shift
          ;;
        --env)
          if (( $# < 2 )); then
            echo 'abwrap: --env requires a variable name' >&2
            exit 2
          fi
          forward_environment "$2"
          shift 2
          ;;
        --env=*)
          forward_environment "''${1#*=}"
          shift
          ;;
        --tool-state)
          if (( $# < 2 )); then
            echo 'abwrap: --tool-state requires a tool name' >&2
            exit 2
          fi
          enable_tool_state "$2"
          shift 2
          ;;
        --tool-state=*)
          enable_tool_state "''${1#*=}"
          shift
          ;;
        -e|--entrypoint)
          if (( $# < 2 )); then
            echo "abwrap: $1 requires a command" >&2
            exit 2
          fi
          entrypoint="$2"
          entrypoint_explicit=true
          shift 2
          ;;
        --entrypoint=*)
          entrypoint="''${1#*=}"
          if [[ -z "$entrypoint" ]]; then
            echo 'abwrap: --entrypoint requires a command' >&2
            exit 2
          fi
          entrypoint_explicit=true
          shift
          ;;
        --)
          shift
          if [[ "$entrypoint_explicit" == false && $# -gt 0 ]]; then
            entrypoint="$1"
            shift
          fi
          break
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        -*)
          echo "abwrap: unknown wrapper option: $1" >&2
          echo 'abwrap: use -- before an entrypoint beginning with a dash' >&2
          exit 2
          ;;
        *)
          if [[ "$entrypoint_explicit" == true ]]; then
            echo "abwrap: unexpected argument before --: $1" >&2
            exit 2
          fi
          entrypoint="$1"
          shift
          break
          ;;
      esac
    done

    if [[ "$auto_tool_state" == true ]]; then
      case "$(basename -- "$entrypoint")" in
        pi)
          enable_tool_state pi
          ;;
        codex)
          enable_tool_state codex
          ;;
        opencode)
          enable_tool_state opencode
          ;;
      esac
    fi

    tool_state_mounts=()
    add_tool_state_mount() {
      local destination="$1"
      local source
      if [[ -e "$destination" ]]; then
        source=$(realpath -e -- "$destination")
        tool_state_mounts+=(--bind "$source" "$destination")
      fi
    }

    if [[ "$mount_pi_state" == true ]]; then
      add_tool_state_mount "$home/.pi"
    fi
    if [[ "$mount_codex_state" == true ]]; then
      add_tool_state_mount "$home/.codex"
    fi
    if [[ "$mount_opencode_state" == true ]]; then
      add_tool_state_mount "$home/.config/opencode"
      add_tool_state_mount "$home/.local/share/opencode"
      add_tool_state_mount "$home/.local/state/opencode"
    fi

    # Start with an empty environment. Keep only terminal/locale metadata plus
    # variables explicitly requested with --env.
    for name in TERM COLORTERM LANG LC_ALL LC_CTYPE TZ NO_COLOR FORCE_COLOR; do
      forward_environment "$name"
    done
    user_name=$(id -un 2>/dev/null || id -u)
    sandbox_env=(
      --clearenv
      --setenv HOME "$home"
      --setenv USER "$user_name"
      --setenv LOGNAME "$user_name"
      --setenv SHELL ${lib.escapeShellArg (lib.getExe nushell)}
      --setenv PATH ${lib.escapeShellArg (lib.makeBinPath sandboxPackages)}
      --setenv TMPDIR /tmp
      --setenv NIX_REMOTE "$overlay_store"
      --setenv NIX_CONFIG "$nix_config"
      "''${forwarded_env[@]}"
    )

    status=0
    ${lib.getExe bubblewrap} \
      --unshare-all \
      --unshare-user \
      --share-net \
      --disable-userns \
      --die-with-parent \
      --seccomp "$seccomp_fd" \
      --ro-bind /nix/store /run/abwrap/lower/nix/store \
      --ro-bind /nix/var/nix/db /run/abwrap/lower/nix/var/nix/db \
      --overlay-src /nix/store \
      --overlay "$nix_overlay/upper" "$nix_overlay/work" /nix/store \
      --bind "$nix_overlay" /run/abwrap/overlay \
      --ro-bind-try /etc/resolv.conf /etc/resolv.conf \
      --ro-bind-try /etc/hosts /etc/hosts \
      --ro-bind-try /etc/nsswitch.conf /etc/nsswitch.conf \
      --proc /proc \
      --dev /dev \
      --tmpfs /tmp \
      --dir "$home" \
      "''${sandbox_env[@]}" \
      "''${tool_state_mounts[@]}" \
      "''${mounts[@]}" \
      -- "$entrypoint" "$@" \
      || status=$?

    exit "$status"
  '';
}
