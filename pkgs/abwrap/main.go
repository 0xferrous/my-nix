package main

import (
	"encoding/binary"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"os/signal"
	"os/user"
	"path/filepath"
	"runtime"
	"strconv"
	"syscall"
)

// package.nix replaces these defaults at link time with immutable Nix store
// paths. Keeping them as variables also makes local development builds useful.
var (
	bwrapPath            = "bwrap"
	posixShellPath       = "/bin/sh"
	fallbackCABundlePath = "/etc/ssl/certs/ca-bundle.crt"
	terminfoDirs         = "/usr/share/terminfo"
	defaultEntrypoint    = "nu"
	sandboxPath          = ""
)

const (
	// The lower store is query-encoded because it is nested inside another
	// store URI. check-mount is disabled because Bubblewrap exposes the backing
	// mount through an /oldroot path that Nix cannot match textually.
	overlayStore = "local-overlay://?root=/&lower-store=/run/abwrap/lower%3Fread-only=true&upper-layer=/run/abwrap/overlay/upper&state=/run/abwrap/overlay/state&check-mount=false"
	nixConfig    = "extra-experimental-features = nix-command flakes local-overlay-store read-only-local-store\nsandbox = false"

	// Classic BPF and seccomp constants are defined locally to keep the binary
	// dependency-free. They match Linux's filter and seccomp UAPI headers.
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
	// These values affect terminal presentation or locale behavior and are safe
	// enough to preserve without an explicit --env option.
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
	// Bubblewrap receives authoritative values for these names. Refusing to
	// forward them prevents a caller from bypassing the clean environment.
	managedEnvironment = map[string]bool{
		"HOME":              true,
		"USER":              true,
		"LOGNAME":           true,
		"SHELL":             true,
		"PATH":              true,
		"TMPDIR":            true,
		"NIX_REMOTE":        true,
		"NIX_CONFIG":        true,
		"SSL_CERT_FILE":     true,
		"NIX_SSL_CERT_FILE": true,
		"TERMINFO":          true,
		"TERMINFO_DIRS":     true,
	}
)

// mount describes one host path exposed at a specific sandbox path.
type mount struct {
	source   string
	target   string
	readOnly bool
}

// options is the fully parsed wrapper policy before Bubblewrap arguments are
// constructed. commandArgs are never interpreted by a shell.
type options struct {
	entrypoint    string
	commandArgs   []string
	mounts        []mount
	forwardEnv    []string
	autoToolState bool
	toolState     map[string]bool
	showHelp      bool
}

// sockFilter matches Linux's eight-byte struct sock_filter layout. binary.Write
// serializes fields without Go struct padding.
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
	caBundle, err := resolveCABundle()
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

	bwrapArgs := bubblewrapArgs(home, overlay, caBundle, opts, stateMounts)
	cmd := exec.Command(bwrapPath, bwrapArgs...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	// Do not expose even the wrapper's environment to Bubblewrap. ExtraFiles
	// maps the first entry to descriptor 3, matching --seccomp 3 below.
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

	flags := flag.NewFlagSet("abwrap", flag.ContinueOnError)
	// The wrapper owns error formatting and help output, so suppress flag's
	// default writes while retaining its parsing and validation behavior.
	flags.SetOutput(io.Discard)
	flags.Usage = func() {}

	addMount := func(readOnly bool) func(string) error {
		return func(path string) error {
			resolved, err := resolveExistingPath(path)
			if err != nil {
				return err
			}
			opts.mounts = append(opts.mounts, mount{
				source:   resolved,
				target:   resolved,
				readOnly: readOnly,
			})
			return nil
		}
	}
	setEntrypoint := func(entrypoint string) error {
		if entrypoint == "" {
			return errors.New("entrypoint requires a command")
		}
		opts.entrypoint = entrypoint
		entrypointExplicit = true
		return nil
	}

	flags.Func("ro", "expose an existing host path read-only", addMount(true))
	flags.Func("rw", "expose an existing host path read-write", addMount(false))
	flags.Func("env", "forward an environment variable if set", func(name string) error {
		return addEnvironment(&opts, name)
	})
	flags.Func("tool-state", "mount pi, codex, opencode, all, or none state", func(state string) error {
		return enableToolState(&opts, state)
	})
	flags.Func("e", "use a command instead of Nushell", setEntrypoint)
	flags.Func("entrypoint", "use a command instead of Nushell", setEntrypoint)

	if err := flags.Parse(args); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			opts.showHelp = true
			return opts, nil
		}
		return opts, err
	}

	remaining := flags.Args()
	if !entrypointExplicit && len(remaining) > 0 {
		opts.entrypoint = remaining[0]
		remaining = remaining[1:]
	}
	opts.commandArgs = remaining
	return opts, nil
}

// addEnvironment records a variable name, never its value. The value is read
// immediately before launch so secrets do not appear in argv.
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

// enableToolState accumulates explicit state requests. "none" also disables
// entrypoint-based automatic state selection.
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

// resolveExistingPath canonicalizes bind sources and destinations before
// entering the mount namespace, including resolving user-controlled symlinks.
func resolveExistingPath(path string) (string, error) {
	if path == "" {
		return "", errors.New("path must not be empty")
	}
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

// resolveCABundle prefers the host's configured bundle so custom trust roots
// remain available, then falls back to the immutable bundle injected by Nix.
func resolveCABundle() (string, error) {
	candidates := []string{
		os.Getenv("SSL_CERT_FILE"),
		os.Getenv("NIX_SSL_CERT_FILE"),
		"/etc/ssl/certs/ca-bundle.crt",
		"/etc/ssl/certs/ca-certificates.crt",
		fallbackCABundlePath,
	}
	seen := make(map[string]bool)
	for _, candidate := range candidates {
		if candidate == "" || seen[candidate] {
			continue
		}
		seen[candidate] = true
		resolved, err := resolveExistingPath(candidate)
		if err != nil {
			continue
		}
		info, err := os.Stat(resolved)
		if err == nil && !info.IsDir() {
			return resolved, nil
		}
	}
	return "", errors.New("no usable TLS CA bundle found")
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
		// Preserve the conventional path inside the sandbox while binding the
		// canonical host source in case the state directory itself is a symlink.
		source, err := resolveExistingPath(target)
		if err != nil {
			return nil, err
		}
		mounts = append(mounts, mount{source: source, target: target})
	}
	return mounts, nil
}

// bubblewrapArgs is the complete sandbox policy. Keep security-sensitive
// defaults here so their ordering is visible and reviewable in one place.
func bubblewrapArgs(home, overlay, caBundle string, opts options, stateMounts []mount) []string {
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
		// Use the host bundle when available so locally installed trust roots, such
		// as an intercepting proxy CA, remain valid inside the sandbox.
		"--ro-bind", caBundle, "/etc/ssl/certs/ca-bundle.crt",
		// Pi's bash tool and many build scripts expect /bin/sh even on NixOS.
		"--ro-bind", posixShellPath, "/bin/sh",
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
		"--setenv", "SSL_CERT_FILE", "/etc/ssl/certs/ca-bundle.crt",
		"--setenv", "NIX_SSL_CERT_FILE", "/etc/ssl/certs/ca-bundle.crt",
		"--setenv", "TERMINFO_DIRS", terminfoDirs,
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
		// x32 uses the x86-64 audit architecture with a syscall-number bit, so
		// both native and x32 ioctl numbers must reach the TIOCSTI check.
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

	// A pipe avoids writing a persistent filter file. The read end is inherited
	// by Bubblewrap as descriptor 3 and consumed before the payload starts.
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
	// Catch termination signals so they can reach the payload while run returns
	// normally and executes deferred overlay cleanup. SIGWINCH is deliberately
	// not caught: the foreground process group receives terminal resizes itself.
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
	// Nix store objects are commonly read-only. Restore owner permissions before
	// RemoveAll, but never chmod symlinks because that would affect their targets.
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
