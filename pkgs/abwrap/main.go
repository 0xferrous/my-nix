package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"os/signal"
	"os/user"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"syscall"
)

var (
	bwrapPath         = "bwrap"
	defaultEntrypoint = "nu"
	sandboxPath       = ""
)

const (
	overlayStore = "local-overlay://?root=/&lower-store=/run/abwrap/lower%3Fread-only=true&upper-layer=/run/abwrap/overlay/upper&state=/run/abwrap/overlay/state&check-mount=false"
	nixConfig    = "extra-experimental-features = nix-command flakes local-overlay-store read-only-local-store\nsandbox = false"

	bpfLD  = 0x00
	bpfW   = 0x00
	bpfABS = 0x20
	bpfJMP = 0x05
	bpfJEQ = 0x10
	bpfK   = 0x00
	bpfRET = 0x06

	seccompRetKillProcess = 0x80000000
	seccompRetErrno       = 0x00050000
	seccompRetAllow       = 0x7fff0000

	auditArchX86_64  = 0xc000003e
	auditArchAArch64 = 0xc00000b7

	seccompOffsetSyscall = 0
	seccompOffsetArch    = 4
	seccompOffsetArg1    = 24

	syscallIoctlAMD64 = 16
	syscallIoctlARM64 = 29
	x32SyscallBit     = 0x40000000
	tioCSTI           = 0x5412
)

var (
	safeEnvironment = []string{
		"TERM",
		"COLORTERM",
		"LANG",
		"LC_ALL",
		"LC_CTYPE",
		"TZ",
		"NO_COLOR",
		"FORCE_COLOR",
	}
	managedEnvironment = map[string]bool{
		"HOME":       true,
		"USER":       true,
		"LOGNAME":    true,
		"SHELL":      true,
		"PATH":       true,
		"TMPDIR":     true,
		"NIX_REMOTE": true,
		"NIX_CONFIG": true,
	}
)

type mount struct {
	source   string
	target   string
	readOnly bool
}

type options struct {
	entrypoint    string
	commandArgs   []string
	mounts        []mount
	forwardEnv    []string
	autoToolState bool
	toolState     map[string]bool
	showHelp      bool
}

type sockFilter struct {
	Code uint16
	Jt   uint8
	Jf   uint8
	K    uint32
}

func main() {
	os.Exit(run(os.Args[1:]))
}

func run(args []string) int {
	home, err := resolveHome()
	if err != nil {
		return fail(err)
	}

	opts, err := parseOptions(args)
	if err != nil {
		return fail(err)
	}
	if opts.showHelp {
		usage()
		return 0
	}

	if opts.autoToolState {
		entrypointName := filepath.Base(opts.entrypoint)
		switch entrypointName {
		case "pi", "codex", "opencode":
			opts.toolState[entrypointName] = true
		}
	}

	stateMounts, err := toolStateMounts(home, opts.toolState)
	if err != nil {
		return fail(err)
	}

	overlay, err := os.MkdirTemp("/tmp", "abwrap-nix.")
	if err != nil {
		return fail(fmt.Errorf("create temporary overlay: %w", err))
	}
	defer cleanupOverlay(overlay)

	for _, name := range []string{"upper", "work", "state"} {
		if err := os.Mkdir(filepath.Join(overlay, name), 0o700); err != nil {
			return fail(fmt.Errorf("create overlay %s directory: %w", name, err))
		}
	}

	filter, err := seccompFilterPipe()
	if err != nil {
		return fail(err)
	}
	defer filter.Close()

	bwrapArgs := bubblewrapArgs(home, overlay, opts, stateMounts)
	cmd := exec.Command(bwrapPath, bwrapArgs...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = []string{}
	cmd.ExtraFiles = []*os.File{filter}

	return runCommand(cmd)
}

func usage() {
	fmt.Println(`Usage: abwrap [OPTIONS] [COMMAND [ARGS...]]
       abwrap [OPTIONS] -- [COMMAND [ARGS...]]

Run Nushell or another command in an isolated filesystem.
The default entrypoint is Nushell. pi, codex, opencode, and
all dev-essential tools are available on PATH.

Each invocation gets an independent writable Nix local-overlay store
in /tmp. Host paths and environment variables are visible only when
explicitly exposed. State for a directly selected agent is mounted
automatically; other tool state can be requested explicitly.

Options:
  --ro PATH              expose an existing host path read-only
  --rw PATH              expose an existing host path read-write
  --env NAME             forward an environment variable if set
  --tool-state TOOL      mount pi, codex, opencode, all, or none state
  -e, --entrypoint CMD   use CMD instead of Nushell
  -h, --help             show this help

Examples:
  abwrap --rw "$PWD"
  abwrap --rw "$PWD" pi --model openai/gpt-5
  abwrap --env OPENAI_API_KEY --rw "$PWD" codex
  abwrap --tool-state pi --rw "$PWD"
  abwrap --rw "$PWD" opencode`)
}

func parseOptions(args []string) (options, error) {
	opts := options{
		entrypoint:    defaultEntrypoint,
		autoToolState: true,
		toolState:     make(map[string]bool),
	}
	entrypointExplicit := false

	for index := 0; index < len(args); {
		arg := args[index]
		switch {
		case arg == "--ro" || arg == "--rw":
			if index+1 >= len(args) {
				return opts, fmt.Errorf("%s requires a path", arg)
			}
			resolved, err := resolveExistingPath(args[index+1])
			if err != nil {
				return opts, err
			}
			opts.mounts = append(opts.mounts, mount{
				source:   resolved,
				target:   resolved,
				readOnly: arg == "--ro",
			})
			index += 2

		case strings.HasPrefix(arg, "--ro=") || strings.HasPrefix(arg, "--rw="):
			mode, value, _ := strings.Cut(arg, "=")
			resolved, err := resolveExistingPath(value)
			if err != nil {
				return opts, err
			}
			opts.mounts = append(opts.mounts, mount{
				source:   resolved,
				target:   resolved,
				readOnly: mode == "--ro",
			})
			index++

		case arg == "--env":
			if index+1 >= len(args) {
				return opts, errors.New("--env requires a variable name")
			}
			if err := addEnvironment(&opts, args[index+1]); err != nil {
				return opts, err
			}
			index += 2

		case strings.HasPrefix(arg, "--env="):
			if err := addEnvironment(&opts, strings.TrimPrefix(arg, "--env=")); err != nil {
				return opts, err
			}
			index++

		case arg == "--tool-state":
			if index+1 >= len(args) {
				return opts, errors.New("--tool-state requires a tool name")
			}
			if err := enableToolState(&opts, args[index+1]); err != nil {
				return opts, err
			}
			index += 2

		case strings.HasPrefix(arg, "--tool-state="):
			if err := enableToolState(&opts, strings.TrimPrefix(arg, "--tool-state=")); err != nil {
				return opts, err
			}
			index++

		case arg == "-e" || arg == "--entrypoint":
			if index+1 >= len(args) {
				return opts, fmt.Errorf("%s requires a command", arg)
			}
			opts.entrypoint = args[index+1]
			entrypointExplicit = true
			index += 2

		case strings.HasPrefix(arg, "--entrypoint="):
			opts.entrypoint = strings.TrimPrefix(arg, "--entrypoint=")
			if opts.entrypoint == "" {
				return opts, errors.New("--entrypoint requires a command")
			}
			entrypointExplicit = true
			index++

		case arg == "--":
			index++
			if !entrypointExplicit && index < len(args) {
				opts.entrypoint = args[index]
				index++
			}
			opts.commandArgs = args[index:]
			return opts, nil

		case arg == "-h" || arg == "--help":
			opts.showHelp = true
			return opts, nil

		case strings.HasPrefix(arg, "-"):
			return opts, fmt.Errorf("unknown wrapper option: %s; use -- before an entrypoint beginning with a dash", arg)

		default:
			if entrypointExplicit {
				return opts, fmt.Errorf("unexpected argument before --: %s", arg)
			}
			opts.entrypoint = arg
			opts.commandArgs = args[index+1:]
			return opts, nil
		}
	}

	return opts, nil
}

func addEnvironment(opts *options, name string) error {
	if !validEnvironmentName(name) {
		return fmt.Errorf("invalid environment variable name: %s", name)
	}
	if managedEnvironment[name] {
		return fmt.Errorf("environment variable %s is managed by abwrap", name)
	}
	for _, existing := range opts.forwardEnv {
		if existing == name {
			return nil
		}
	}
	opts.forwardEnv = append(opts.forwardEnv, name)
	return nil
}

func validEnvironmentName(name string) bool {
	if name == "" || !isEnvironmentStart(name[0]) {
		return false
	}
	for index := 1; index < len(name); index++ {
		character := name[index]
		if !isEnvironmentStart(character) && (character < '0' || character > '9') {
			return false
		}
	}
	return true
}

func isEnvironmentStart(character byte) bool {
	return character == '_' || character >= 'a' && character <= 'z' || character >= 'A' && character <= 'Z'
}

func enableToolState(opts *options, state string) error {
	switch state {
	case "pi", "codex", "opencode":
		opts.toolState[state] = true
	case "all":
		opts.toolState["pi"] = true
		opts.toolState["codex"] = true
		opts.toolState["opencode"] = true
	case "none":
		opts.autoToolState = false
		clear(opts.toolState)
	default:
		return fmt.Errorf("unknown tool state %q; expected pi, codex, opencode, all, or none", state)
	}
	return nil
}

func resolveHome() (string, error) {
	home := os.Getenv("HOME")
	if home == "" {
		return "", errors.New("HOME must exist")
	}
	resolved, err := resolveExistingPath(home)
	if err != nil {
		return "", errors.New("HOME must exist")
	}
	info, err := os.Stat(resolved)
	if err != nil || !info.IsDir() {
		return "", errors.New("HOME must exist")
	}
	return resolved, nil
}

func resolveExistingPath(path string) (string, error) {
	absolute, err := filepath.Abs(path)
	if err != nil {
		return "", fmt.Errorf("resolve path %q: %w", path, err)
	}
	resolved, err := filepath.EvalSymlinks(absolute)
	if err != nil {
		return "", fmt.Errorf("path does not exist: %s", path)
	}
	if _, err := os.Stat(resolved); err != nil {
		return "", fmt.Errorf("path does not exist: %s", path)
	}
	return resolved, nil
}

func toolStateMounts(home string, enabled map[string]bool) ([]mount, error) {
	paths := make([]string, 0, 5)
	if enabled["pi"] {
		paths = append(paths, filepath.Join(home, ".pi"))
	}
	if enabled["codex"] {
		paths = append(paths, filepath.Join(home, ".codex"))
	}
	if enabled["opencode"] {
		paths = append(paths,
			filepath.Join(home, ".config", "opencode"),
			filepath.Join(home, ".local", "share", "opencode"),
			filepath.Join(home, ".local", "state", "opencode"),
		)
	}

	mounts := make([]mount, 0, len(paths))
	for _, target := range paths {
		if _, err := os.Stat(target); errors.Is(err, os.ErrNotExist) {
			continue
		} else if err != nil {
			return nil, fmt.Errorf("inspect tool state %s: %w", target, err)
		}
		source, err := resolveExistingPath(target)
		if err != nil {
			return nil, err
		}
		mounts = append(mounts, mount{source: source, target: target})
	}
	return mounts, nil
}

func bubblewrapArgs(home, overlay string, opts options, stateMounts []mount) []string {
	userName := currentUserName()
	args := []string{
		"--unshare-all",
		"--unshare-user",
		"--share-net",
		"--disable-userns",
		"--die-with-parent",
		"--seccomp", "3",
		"--ro-bind", "/nix/store", "/run/abwrap/lower/nix/store",
		"--ro-bind", "/nix/var/nix/db", "/run/abwrap/lower/nix/var/nix/db",
		"--overlay-src", "/nix/store",
		"--overlay", filepath.Join(overlay, "upper"), filepath.Join(overlay, "work"), "/nix/store",
		"--bind", overlay, "/run/abwrap/overlay",
		"--ro-bind-try", "/etc/resolv.conf", "/etc/resolv.conf",
		"--ro-bind-try", "/etc/hosts", "/etc/hosts",
		"--ro-bind-try", "/etc/nsswitch.conf", "/etc/nsswitch.conf",
		"--proc", "/proc",
		"--dev", "/dev",
		"--tmpfs", "/tmp",
		"--dir", home,
		"--clearenv",
		"--setenv", "HOME", home,
		"--setenv", "USER", userName,
		"--setenv", "LOGNAME", userName,
		"--setenv", "SHELL", defaultEntrypoint,
		"--setenv", "PATH", sandboxPath,
		"--setenv", "TMPDIR", "/tmp",
		"--setenv", "NIX_REMOTE", overlayStore,
		"--setenv", "NIX_CONFIG", nixConfig,
	}

	seenEnvironment := make(map[string]bool)
	appendEnvironment := func(name string) {
		if seenEnvironment[name] {
			return
		}
		seenEnvironment[name] = true
		if value, exists := os.LookupEnv(name); exists {
			args = append(args, "--setenv", name, value)
		}
	}
	for _, name := range safeEnvironment {
		appendEnvironment(name)
	}
	for _, name := range opts.forwardEnv {
		appendEnvironment(name)
	}

	for _, item := range append(stateMounts, opts.mounts...) {
		operation := "--bind"
		if item.readOnly {
			operation = "--ro-bind"
		}
		args = append(args, operation, item.source, item.target)
	}

	args = append(args, "--", opts.entrypoint)
	args = append(args, opts.commandArgs...)
	return args
}

func currentUserName() string {
	current, err := user.Current()
	if err == nil && current.Username != "" {
		return current.Username
	}
	return strconv.Itoa(os.Getuid())
}

func seccompFilterPipe() (*os.File, error) {
	var auditArchitecture uint32
	var ioctlNumber uint32
	switch runtime.GOARCH {
	case "amd64":
		auditArchitecture = auditArchX86_64
		ioctlNumber = syscallIoctlAMD64
	case "arm64":
		auditArchitecture = auditArchAArch64
		ioctlNumber = syscallIoctlARM64
	default:
		return nil, fmt.Errorf("seccomp filter does not support architecture %s", runtime.GOARCH)
	}

	// Bubblewrap consumes classic BPF instructions directly. Reject execution
	// under a different ABI, then deny only ioctl(_, TIOCSTI, _).
	filters := []sockFilter{
		statement(bpfLD|bpfW|bpfABS, seccompOffsetArch),
		jump(bpfJMP|bpfJEQ|bpfK, auditArchitecture, 1, 0),
		statement(bpfRET|bpfK, seccompRetKillProcess),
		statement(bpfLD|bpfW|bpfABS, seccompOffsetSyscall),
	}
	if runtime.GOARCH == "amd64" {
		filters = append(filters,
			jump(bpfJMP|bpfJEQ|bpfK, ioctlNumber, 1, 0),
			jump(bpfJMP|bpfJEQ|bpfK, ioctlNumber|x32SyscallBit, 0, 3),
		)
	} else {
		filters = append(filters, jump(bpfJMP|bpfJEQ|bpfK, ioctlNumber, 0, 3))
	}
	filters = append(filters,
		statement(bpfLD|bpfW|bpfABS, seccompOffsetArg1),
		jump(bpfJMP|bpfJEQ|bpfK, tioCSTI, 0, 1),
		statement(bpfRET|bpfK, seccompRetErrno|uint32(syscall.EPERM)),
		statement(bpfRET|bpfK, seccompRetAllow),
	)

	reader, writer, err := os.Pipe()
	if err != nil {
		return nil, fmt.Errorf("create seccomp pipe: %w", err)
	}
	if err := binary.Write(writer, binary.LittleEndian, filters); err != nil {
		reader.Close()
		writer.Close()
		return nil, fmt.Errorf("write seccomp filter: %w", err)
	}
	if err := writer.Close(); err != nil {
		reader.Close()
		return nil, fmt.Errorf("close seccomp filter: %w", err)
	}
	return reader, nil
}

func statement(code uint16, value uint32) sockFilter {
	return sockFilter{Code: code, K: value}
}

func jump(code uint16, value uint32, onTrue, onFalse uint8) sockFilter {
	return sockFilter{Code: code, Jt: onTrue, Jf: onFalse, K: value}
}

func runCommand(cmd *exec.Cmd) int {
	signals := make(chan os.Signal, 8)
	signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP, syscall.SIGQUIT)
	defer signal.Stop(signals)

	if err := cmd.Start(); err != nil {
		return fail(fmt.Errorf("start bubblewrap: %w", err))
	}

	done := make(chan struct{})
	go func() {
		for {
			select {
			case received := <-signals:
				_ = cmd.Process.Signal(received)
			case <-done:
				return
			}
		}
	}()

	err := cmd.Wait()
	close(done)
	if err == nil {
		return 0
	}

	var exitError *exec.ExitError
	if errors.As(err, &exitError) {
		if status, ok := exitError.Sys().(syscall.WaitStatus); ok && status.Signaled() {
			return 128 + int(status.Signal())
		}
		return exitError.ExitCode()
	}
	return fail(fmt.Errorf("wait for bubblewrap: %w", err))
}

func cleanupOverlay(root string) {
	_ = os.Chmod(root, 0o700)
	_ = filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil || entry.Type()&os.ModeSymlink != 0 {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return nil
		}
		permissions := info.Mode().Perm() | 0o600
		if entry.IsDir() {
			permissions |= 0o700
		}
		_ = os.Chmod(path, permissions)
		return nil
	})
	_ = os.RemoveAll(root)
}

func fail(err error) int {
	fmt.Fprintf(os.Stderr, "abwrap: %v\n", err)
	return 2
}
