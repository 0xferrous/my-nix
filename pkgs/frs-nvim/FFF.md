# FFF in this config

This config uses `dmtrKovalenko/fff.nvim` as the primary picker for:

The layout is tuned to feel closer to Snacks/Telescope style:

- prompt at the top
- right-side preview
- larger centered picker
- search-style prompt prefix
- file list display patched to show full relative path

- file search
- project grep
- current-word grep
- Neovim config file search

`snacks.nvim` is still used for other picker-like workflows such
as help, keymaps, diagnostics, recent files, buffers, and
notifications.

## How to use it

### Open the picker

Configured entry points:

- `<leader>sf` — search files with FFF
- `<leader>sg` — live grep with FFF
- `<leader>sw` — grep the word under cursor with FFF
- `<leader>sn` — search Neovim config files with FFF

Dashboard entry points:

- `f` — find file
- `g` — find text
- `c` — search config files

### Basic workflow

#### Find files

1. Press `<leader>sf`
2. Type a short query first
3. Narrow with additional terms only if needed
4. Press `<CR>` to open the selected file

Good queries:

- `lsp`
- `snacks`
- `plugins lsp`
- `cfg init`

#### Grep text

1. Press `<leader>sg`
2. Start with a plain identifier or phrase
3. Use constraints to narrow search scope when result sets are noisy
4. Press `<CR>` to open the selected match

Good queries:

- `CodeCompanion`
- `Snacks.picker`
- `git:modified telescope`
- `lua/plugins/ TODO`

#### Search the current word

- Press `<leader>sw` on a symbol to prefill the grep query with `<cword>`

## Query patterns and constraints

FFF supports both free-text query terms and inline constraints.

### File search constraints

These work in file search and grep unless otherwise noted.

- `git:modified` — only modified files
- `git:staged` — only staged files
- `git:deleted` — only deleted files
- `git:renamed` — only renamed files
- `git:untracked` — only untracked files
- `git:ignored` — only ignored files
- `test/` — files under directories matching `test/`
- `!test/` — exclude paths under `test/`
- `!something` — negate a path/glob/status constraint
- `./**/*.{rs,lua}` — glob constraint

### Grep-only constraints

- `*.md` — grep only markdown files
- `*.{c,h}` — grep only matching extensions
- `src/main.rs` — grep only a single file

### Combined examples

#### Search modified Rust files

```text
git:modified src/**/*.rs
```

#### Search for a term but exclude tests

```text
!test/ !*.spec.ts actor_auth
```

#### Search a specific subtree

```text
lua/plugins/ snacks
```

#### Search config files by content

```text
*.lua keymap.set
```

## Grep modes

FFF grep supports multiple modes and cycles between them inside the picker.

Default available modes:

- `plain`
- `regex`
- `fuzzy`

Use these modes like this:

- **plain** — safest default for symbols and literal text
- **regex** — when you actually want pattern matching
- **fuzzy** — for typo-tolerant lookup or approximate matches

Examples:

- plain: `CodeCompanion`
- regex: `Snacks\.picker\.(files|grep)`
- fuzzy: `telesope`

## Picker keymaps

These are FFF's picker-local defaults used by this config.

### Selection and opening

- `<CR>` — open selection
- `<C-s>` — open in horizontal split
- `<C-v>` — open in vertical split
- `<C-t>` — open in tab
- `<Esc>` — close picker

### Movement

- `<Up>` or `<C-p>` — move up
- `<Down>` or `<C-n>` — move down
- `j` / `k` also work in normal mode inside the picker

### Preview

- `<C-u>` — scroll preview up
- `<C-d>` — scroll preview down
- `<leader>l` — focus result list
- `<leader>p` — focus preview

### Grep-specific

- `<S-Tab>` — cycle grep mode (`plain` / `regex` / `fuzzy`)
- `<C-Up>` — cycle previous query history

### Multi-select / quickfix

- `<Tab>` — toggle selection
- `<C-q>` — send selected items to quickfix

### Debug

- `<F2>` — toggle debug scoring display

## Tips for effective use

### Prefer short queries

FFF works best when you start broad.

Prefer:

- `lsp`
- `snacks`
- `grep`

Over:

- `all files related to lsp settings and formatting`

### Add constraints before adding more words

When results are noisy, narrow by scope instead of piling on many terms.

Prefer:

```text
lua/plugins/ lsp
```

or:

```text
git:modified lsp
```

over:

```text
lsp config plugin settings format mapping
```

### Use plain grep first

If you are searching code:

- start with a literal identifier in plain mode
- switch to regex only when needed
- use fuzzy only for typo-tolerant discovery

### Use config-file search separately

If you know you want only Neovim config files, use:

- `<leader>sn`

instead of searching the whole project.

## Local integration notes

This repo currently carries a small local patch in
`lua/plugins/fff.lua` that removes FFF preview debounce by
overriding `fff.picker_ui.update_preview_smart()`.

Reason:

- rapid cursor movement in FFF preview felt laggy
- upstream preview code also hit fast-event-context issues during aggressive navigation
- file list display was changed from `filename + parent path` to full relative path

So if picker behavior changes after upstream updates, check:

- `lua/plugins/fff.lua`

## Limitations

FFF is used here as a full picker for file/grep workflows, not as
a backend for Snacks picker UI.

That means:

- file search and grep open FFF's own UI
- Snacks remains the UI for other picker families

## Upstream references

Primary source used for this config:

- `/tmp/pi-work/fff.nvim/README.md`
- `/tmp/pi-work/fff.nvim/doc/fff.nvim.txt`
