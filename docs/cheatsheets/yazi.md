# Yazi cheatsheet

Accurate for **Yazi 26.5.6** (`yazi --version` on this machine: `Yazi 26.5.6`).
Checked on 2026-07-15 against:

- Yazi docs: <https://yazi-rs.github.io/docs/configuration/keymap/>
- Default shipped keymap: <https://github.com/sxyazi/yazi/blob/shipped/yazi-config/preset/keymap-default.toml>
- Local manpages: `man yazi`, `man yazi-config`

Inside Yazi, press `~` or `<F1>` for the authoritative live help/keymap.

## Starting Yazi

```sh
yazi [entries...]
```

Useful CLI options from `yazi --help`:

| Option | Use |
| --- | --- |
| `--cwd-file <file>` | Write Yazi's final cwd to a file on exit. Useful for shell wrappers. |
| `--chooser-file <file>` | Write selected files when an `open` action fires. |
| `--clear-cache` | Clear Yazi's cache directory. |
| `--debug` | Print debug info, config paths, dependencies, terminal capabilities. |

Config lives in `~/.config/yazi/` by default. Important files:

| File | Purpose |
| --- | --- |
| `yazi.toml` | General config. |
| `keymap.toml` | Keybindings. |
| `theme.toml` | Theme/colors. |
| `vfs.toml` | VFS config. |
| `init.lua` | Lua startup/customization. |

## Manager/file-list keymap

### Exit, help, suspend

| Key | Action |
| --- | --- |
| `<Esc>` / `<C-[>` | Escape: exit visual mode, clear selection, or cancel search/filter/find. |
| `q` | Quit. |
| `Q` | Quit without writing `--cwd-file`. |
| `<C-c>` | Close current tab, or quit if it is the last tab. |
| `<C-z>` | Suspend Yazi; resume with `fg` in the shell. |
| `~` / `<F1>` | Open help. |

### Movement and navigation

| Key | Action |
| --- | --- |
| `j` / `<Down>` | Next file. |
| `k` / `<Up>` | Previous file. |
| `<C-d>` / `<S-PageDown>` | Down half page. |
| `<C-u>` / `<S-PageUp>` | Up half page. |
| `<C-f>` / `<PageDown>` | Down one page. |
| `<C-b>` / `<PageUp>` | Up one page. |
| `g g` | Go to top. |
| `G` | Go to bottom. |
| `h` / `<Left>` | Leave to parent directory. |
| `l` / `<Right>` | Enter child directory. |
| `H` | Back to previous directory. |
| `L` | Forward to next directory. |

### Selection and visual mode

| Key | Action |
| --- | --- |
| `<Space>` | Toggle current selection and move down one item. |
| `<C-a>` | Select all files. |
| `<C-r>` | Invert selection of all files. |
| `v` | Enter visual selection mode. |
| `V` | Enter visual unset mode. |

### Preview and info

| Key | Action |
| --- | --- |
| `K` | Seek preview up 5 units. |
| `J` | Seek preview down 5 units. |
| `<Tab>` | Spot hovered file: show file info/metadata. |

### Open and file operations

| Key | Action |
| --- | --- |
| `o` / `<Enter>` | Open selected files. |
| `O` / `<S-Enter>` | Open selected files interactively. |
| `y` | Yank selected files: copy. |
| `x` | Yank selected files: cut. |
| `p` | Paste yanked files. |
| `P` | Paste yanked files, overwrite destination if needed. |
| `-` | Symlink yanked files with absolute target paths. |
| `_` | Symlink yanked files with relative target paths. |
| `<C-->` | Hardlink yanked files. |
| `Y` / `X` | Cancel yank/cut status. |
| `d` | Trash selected files. |
| `D` | Permanently delete selected files. |
| `a` | Create file; end name with `/` to create a directory. |
| `r` | Rename selected file(s), cursor before extension. |
| `;` | Run an interactive shell command. |
| `:` | Run an interactive shell command and block until it finishes. |
| `.` | Toggle hidden files. |

### Search, jump, find, filter

| Key | Action |
| --- | --- |
| `s` | Search files by name via `fd`. |
| `S` | Search files by content via `ripgrep`. |
| `<C-s>` | Cancel ongoing search. |
| `z` | Jump to a file/directory via Yazi's `fzf` plugin. |
| `Z` | Jump to a directory via Yazi's `zoxide` plugin. |
| `f` | Filter files, smart-case. |
| `/` | Find next file, smart-case. |
| `?` | Find previous file, smart-case. |
| `n` | Next found match. |
| `N` | Previous found match. |

### Linemode

| Key | Action |
| --- | --- |
| `m s` | Linemode: size. |
| `m p` | Linemode: permissions. |
| `m b` | Linemode: birth time. |
| `m m` | Linemode: modified time. |
| `m o` | Linemode: owner. |
| `m n` | Linemode: none. |

### Copy file info

Yazi's docs call these URLs because it can represent local and non-local paths.

| Key | Action |
| --- | --- |
| `c c` | Copy file URL/path. |
| `c d` | Copy directory URL/path. |
| `c f` | Copy filename. |
| `c n` | Copy filename without extension. |

### Sorting

| Key | Action |
| --- | --- |
| `, m` | Sort by modified time; set linemode to mtime. |
| `, M` | Sort by modified time, reverse; set linemode to mtime. |
| `, b` | Sort by birth time; set linemode to btime. |
| `, B` | Sort by birth time, reverse; set linemode to btime. |
| `, e` | Sort by extension. |
| `, E` | Sort by extension, reverse. |
| `, a` | Sort alphabetically. |
| `, A` | Sort alphabetically, reverse. |
| `, n` | Sort naturally. |
| `, N` | Sort naturally, reverse. |
| `, s` | Sort by size; set linemode to size. |
| `, S` | Sort by size, reverse; set linemode to size. |
| `, r` | Sort randomly. |

### Goto

| Key | Action |
| --- | --- |
| `g h` | Go home: `~`. |
| `g c` | Go to `~/.config`. |
| `g d` | Go to `~/Downloads`. |
| `g <Space>` | Jump interactively. |
| `g f` | Follow hovered symlink. |

### Tabs

| Key | Action |
| --- | --- |
| `t t` | Create a new tab in the current directory. |
| `t r` | Rename current tab interactively. |
| `1`..`9` | Switch to tab 1..9. |
| `[` / `]` | Switch to previous / next tab. |
| `{` / `}` | Swap current tab with previous / next tab. |

### Tasks

| Key | Action |
| --- | --- |
| `w` | Show task manager. |

## Other UI layers

These are the default keys after opening each layer/component.

### Task manager

| Key | Action |
| --- | --- |
| `<Esc>` / `<C-[>` / `<C-c>` / `w` | Close task manager. |
| `j` / `<Down>` | Next task. |
| `k` / `<Up>` | Previous task. |
| `<Enter>` | Inspect task. |
| `x` | Cancel task. |
| `~` / `<F1>` | Help. |

### Spotter (`<Tab>` from manager)

| Key | Action |
| --- | --- |
| `<Esc>` / `<C-[>` / `<C-c>` / `<Tab>` | Close spotter. |
| `j` / `<Down>` | Next line. |
| `k` / `<Up>` | Previous line. |
| `h` / `<Left>` | Swipe to previous file. |
| `l` / `<Right>` | Swipe to next file. |
| `c c` | Copy selected cell. |
| `~` / `<F1>` | Help. |

### Picker, e.g. open-with menu

| Key | Action |
| --- | --- |
| `<Esc>` / `<C-[>` / `<C-c>` | Cancel picker. |
| `<Enter>` | Submit picker. |
| `j` / `<Down>` | Next option. |
| `k` / `<Up>` | Previous option. |
| `~` / `<F1>` | Help. |

### Confirmation dialogs

| Key | Action |
| --- | --- |
| `<Esc>` / `<C-[>` / `<C-c>` / `n` | Cancel. |
| `<Enter>` / `y` | Submit/confirm. |
| `j` / `<Down>` | Next line. |
| `k` / `<Up>` | Previous line. |
| `~` / `<F1>` | Help. |

### Completion popup

| Key | Action |
| --- | --- |
| `<C-c>` | Cancel completion. |
| `<Tab>` | Submit completion. |
| `<Enter>` | Complete and submit input. |
| `<A-j>` / `<Down>` / `<C-n>` | Next item. |
| `<A-k>` / `<Up>` / `<C-p>` | Previous item. |
| `~` / `<F1>` | Help. |

### Help menu

| Key | Action |
| --- | --- |
| `<Esc>` / `<C-[>` | Clear help filter or hide help. |
| `<C-c>` | Hide help. |
| `j` / `<Down>` | Next line. |
| `k` / `<Up>` | Previous line. |
| `f` | Filter help items. |

## Input editing keys

Input boxes are used by create, rename, filter/search prompts, shell command
prompts, tab rename, etc. They are modal and vi-like.

### Input mode control

| Key | Action |
| --- | --- |
| `<C-c>` | Cancel input. |
| `<Enter>` | Submit input. |
| `<Esc>` / `<C-[>` | Back to normal mode, or cancel input. |
| `i` | Insert mode. |
| `I` | Move to first non-whitespace character and insert. |
| `a` | Append mode. |
| `A` | Move to end of line and append. |
| `v` | Visual mode. |
| `r` | Replace one character. |

### Input movement

| Key | Action |
| --- | --- |
| `h` / `<Left>` / `<C-b>` | Move back one character. |
| `l` / `<Right>` / `<C-f>` | Move forward one character. |
| `b` / `<A-b>` / `<C-Left>` | Move back to start of current/previous word. |
| `B` | Move back to start of current/previous WORD. |
| `w` | Move forward to start of next word. |
| `W` | Move forward to start of next WORD. |
| `e` / `<A-f>` / `<C-Right>` | Move forward to end of current/next word. |
| `E` | Move forward to end of current/next WORD. |
| `0` / `<C-a>` / `<Home>` | Move to beginning of line. |
| `$` / `<C-e>` / `<End>` | Move to end of line. |
| `_` / `^` | Move to first non-whitespace character. |

### Input selection, delete, kill, paste

| Key | Action |
| --- | --- |
| `V` / `<C-A>` / `<C-E>` | Select whole line. |
| `<Backspace>` / `<C-h>` | Delete character before cursor. |
| `<Delete>` / `<C-d>` | Delete character under cursor. |
| `<C-u>` | Kill backward to beginning of line. |
| `<C-k>` | Kill forward to end of line. |
| `<C-w>` / `<C-Backspace>` | Kill backward to start of word. |
| `<A-d>` / `<C-Delete>` | Kill forward to end of word. |
| `d` | Cut selected characters. |
| `D` | Cut until end of line. |
| `c` | Cut selected characters and enter insert mode. |
| `C` | Cut until end of line and enter insert mode. |
| `s` | Cut current character and enter insert mode. |
| `S` | Cut from beginning to end of line and enter insert mode. |
| `x` | Cut current character. |
| `y` | Copy selected characters. |
| `p` | Paste after cursor. |
| `P` | Paste before cursor. |
| `u` | Undo, or lowercase in visual mode. |
| `U` | Uppercase. |
| `<C-r>` | Redo. |
| `~` / `<F1>` | Help. |

## Make the shell cd to Yazi's exit directory

Yazi cannot change its parent shell's cwd directly. Use `--cwd-file` and a shell
wrapper.

Nushell wrapper:

```nu
def --env yy [...args] {
  let tmp = (mktemp -t yazi-cwd.XXXXXX)
  yazi ...$args --cwd-file $tmp
  let cwd = (open $tmp | str trim)
  rm -f $tmp

  if $cwd != "" and $cwd != $env.PWD {
    cd $cwd
  }
}
```

Use `yy` instead of `yazi` when you want your shell to follow Yazi's final
directory.

## Thin Yazi in this repo

This repo's dev essentials uses a thin Nix package:

```nix
pkgs.yazi.override { optionalDeps = [ ]; }
```

That keeps the closure small, but some features depend on optional external
programs. Install these separately if you want the corresponding feature:

| Program | Used for |
| --- | --- |
| `fd` | Name search. Already in dev essentials. |
| `ripgrep` / `rg` | Content search. Already in dev essentials. |
| `fzf` | `z` jump plugin. Already in dev essentials. |
| `zoxide` | `Z` directory jump plugin. Enabled separately in the agent config. |
| `chafa`, `imagemagick`, `ffmpeg`, `poppler`, `resvg`, `7zz` | Rich previews/archive/media helpers; intentionally not pulled into thin Yazi. |
