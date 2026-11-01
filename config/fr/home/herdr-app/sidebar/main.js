// The workspace sidebar: stable colored avatars, worktrees under their checkout,
// and each space's tabs under it, grouped by machine when more than one is known.
// After a space's name, the repo its first terminal is in now, only where unusual:
// branch, ahead/behind. Agent state lives on the tab, and its helpers nest under it.
// Click to switch, right-click for its menu, drag to reorder. A space's chevron
// folds its tabs.

import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { spaces, machines, panes, agents, terminals, run, openOverlay, exec, hc, theme, shared, setShared, watchFolder, window, layout, home, nextCommand } from "herdr";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// The sidebar's rail goes by its width, not a flag: dragging its edge narrows it too.
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

// Where a space is now: its first terminal's live folder, else where it was made.
// `ps`: panes(), read once by the caller (each read copies every pane).
function place(s, ps) {
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return ps.find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}
const rowHeight = ({ tree }) => (tree ? 28 : 30);
const where = (s, ps) => JSON.stringify([s.machine ?? null, place(s, ps)]);
const base = (path) => path.replace(/\/+$/, "").split("/").pop();
// The folder part of a tab's live cwd, with the home folder shortened.
function cwdName(path) {
  if (!path) return "";
  const clean = path.replace(/\\/g, "/").replace(/\/+$/, "");
  if (clean === home().replace(/\/+$/, "")) return "~";
  return clean.split("/").pop() || "/";
}
// Changes made outside Herdr (an editor's save, a commit in another app): looked
// for this often, in repos the list shows, while the window is in front.
const FALLBACK = 60000;

// What a stored color name looks like on an avatar (the same in every mod
// that draws space avatars): one strong color per hue, light and dark alike.
const MARK = { ansi6: "#22a99a", ansi3: "#e3814f", ansi4: "#5b8def", ansi5: "#8b7cf6", ansi2: "#3fae6a", ansi1: "#d9649a" };

// Agent status, as the agents list drew it: urgency order, status words, icons.
const RANK = { blocked: 4, done: 3, working: 2, idle: 1 };
const kidStatus = (k, listed) => {
  const status = listed.get(k.address) ?? k.status;
  return status === "error" ? "blocked" : status === "done" ? "idle" : status;
};
function agentIcon(program, size, color) {
  if (!program?.icon) return null;
  return program.tint ? svg(program.icon).size(size).flex_none().text_color(color) : image(program.icon).w(size).h(size).flex_none();
}
function duration(ms) {
  const m = Math.floor(ms / 60000);
  if (m < 1) return "<1m";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  return h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;
}

// The app's machine layout doc has each tab's split tree. Pane ids in it are
// local to that machine; the model's are qualified when the space is remote.
const localId = (id, machine) => (machine && id.startsWith(`${machine}/`) ? id.slice(machine.length + 1) : id);
const paneId = (id, machine) => (machine ? `${machine}/${id}` : id);
function hasPane(node, ps, machine) {
  if (!node || node.hidden) return false;
  if (node.type === "block") return ps.some((p) => p.pane === paneId(node.id, machine));
  if (node.type === "stack") {
    const active = (node.children ?? []).find((c) => c.id === node.active) ?? node.children?.[0];
    return hasPane(active, ps, machine);
  }
  return (node.children ?? []).some((c) => hasPane(c, ps, machine));
}
function paneHeight(node, ps, machine) {
  if (!node || node.hidden) return 0;
  if (node.type === "block") return ps.some((p) => p.pane === paneId(node.id, machine)) ? 24 : 0;
  if (node.type === "stack") {
    const active = (node.children ?? []).find((c) => c.id === node.active) ?? node.children?.[0];
    return paneHeight(active, ps, machine);
  }
  const heights = (node.children ?? []).filter((c) => hasPane(c, ps, machine)).map((c) => paneHeight(c, ps, machine)).filter((h) => h > 0);
  if (!heights.length) return 0;
  if (node.type === "row") return Math.max(...heights);
  if (node.type === "column") return heights.reduce((n, h) => n + h, 0) + (heights.length - 1);
  return 24;
}
function buildLayout(node, ps, machine, height) {
  if (!node || node.hidden) return null;
  if (node.type === "stack") {
    const active = (node.children ?? []).find((c) => c.id === node.active) ?? node.children?.[0];
    return buildLayout(active, ps, machine, height);
  }
  if (node.type === "row" || node.type === "column") {
    const row = node.type === "row";
    const nodes = (node.children ?? []).filter((c) => !c.hidden && hasPane(c, ps, machine));
    if (!nodes.length) return null;
    const weights = nodes.map((c) => Math.max(0.01, c.size?.weight ?? 1));
    const totalWeight = weights.reduce((n, w) => n + w, 0) || 1;
    const available = Math.max(nodes.length, height - (nodes.length - 1));
    let used = 0;
    const heights = nodes.map((c, i) => {
      if (i === nodes.length - 1) return Math.max(1, available - used);
      const h = Math.max(1, Math.round(available * weights[i] / totalWeight));
      used += h;
      return h;
    });
    const children = nodes.map((c, i) => {
      const child = buildLayout(c, ps, machine, row ? height : heights[i]);
      return child && { weight: weights[i], node: child };
    }).filter(Boolean);
    if (!children.length) return null;
    if (children.length === 1) return children[0].node;
    return { kind: row ? "row" : "column", height, children };
  }
  if (node.type !== "block") return null;
  const id = paneId(node.id, machine);
  return ps.some((p) => p.pane === id) ? { kind: "block", pane: id, height } : null;
}
// A space speaks up only when something in it needs you.
export function glyph(status) {
  return status === "blocked" || status === "done" ? "●" : "·";
}

export function tone(t, status) {
  return t[status] ?? t.unknown;
}

export default class Spaces extends View {
  init(_props, cx) {
    this.git = {}; // where() -> { name, branch, ahead, behind, repo, linked }, null: not a repo
    this.jj = {}; // where() -> Jujutsu workspace list, null: not a jj workspace
    this.checked = {}; // where() -> when it was last looked at
    this.unsure = new Set(); // where()s git couldn't answer for (a machine away)
    this.pending = new Set(); // where()s to look at next
    this.busy = {}; // pane -> an agent working or a program in front of its shell
    this.ready = {}; // machine -> its layout was readable at the last look
    this.at = {}; // space -> its where() at the last look
    this.watching = new Set(); // local repos' git folders
    // Spaces made while this runs wait (at most a moment) for their git, so a
    // worktree appears under its repo instead of jumping there.
    this.shown = new Set(spaces().map((s) => s.id));
    this.born = {};
    this.pressed = null;
    this.over = null;
    this.machines = [];
    // Each agent's last state and when it changed (ms), kept across restarts.
    this.changed = JSON.parse(localStorage.getItem("changed") ?? "{}");
    this.layouts = {}; // machine -> app layout document (tab split trees)
    this.layoutVersions = {}; // machine -> doc version, so unchanged fetches do not redraw
    this.tabModels = {}; // tab id -> cached split model
    this.layoutsBusy = false;
    this.layoutSig = "";
    this.folded = new Set(JSON.parse(localStorage.getItem("machines.folded") ?? "[]"));
    this.foldedSpaces = new Set(JSON.parse(localStorage.getItem("spaces.folded") ?? "[]"));
    this.tabPressed = null; // tab id being dragged
    this.tabOver = null; // tab id under the pointer
    this.hoveredSpace = null; // space initial showing its fold button
    this.refreshMachines(cx);
    cx.timer.every(30000, cx => this.refreshMachines(cx));
    // Tab splits are app state, not in spaces()/panes(): read the app doc.
    // The signature check below fetches on split changes; this is a fallback.
    this.refreshLayouts(cx);
    cx.timer.every(20000, (cx) => this.refreshLayouts(cx));
    // Keep the durations since a status change moving.
    cx.timer.every(30000, (cx) => cx.notify());
    // `git status` walks the whole tree, on another machine a process there:
    // only when its answer could have changed (see `due`).
    cx.timer.every(500, (cx) => this.checkNew(cx));
    // <mod>.<command> actions from keys.json and `herdr-app do`.
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand();
        if (command === "next") this.stepTab(1, cx);
        else if (command === "prev") this.stepTab(-1, cx);
      }
    });
  }

  checkNew(cx) {
    const now = Date.now();
    const sp = spaces();
    const ps = panes();
    const byTab = {};
    for (const p of ps) (byTab[p.tab] ??= []).push(p.pane);
    const sig = sp.map((s) => `${s.id}:${(s.tabs ?? []).map((t) => `${t.id}:${t.panes}:${t.zoomed}:${(byTab[t.id] ?? []).join(",")}`).join(",")}`).join("|");
    if (sig !== this.layoutSig) {
      this.layoutSig = sig;
      this.tabModels = {};
      this.refreshLayouts(cx);
    }
    for (const s of sp) if (!this.shown.has(s.id)) this.born[s.id] ??= now;
    const due = this.due(now, sp, ps);
    if (due.size) this.refreshGit(due, cx);
    if (sp.some((s) => !this.shown.has(s.id))) cx.notify();
  }

  // Places whose git could have changed: new ones (a new space, a cd), where a
  // command or an agent's turn just ended (a checkout, a commit, edits), those on
  // a machine that is back, and repos in view whose fallback is due.
  due(now, sp, ps) {
    // Moved there: what it knew of that place may be old.
    const at = {};
    for (const s of sp) at[s.id] = where(s, ps);
    const keys = new Set(Object.values(at).filter((k) => JSON.parse(k)[1]));
    const due = new Set([...keys].filter((k) => !(k in this.git)));
    for (const [id, k] of Object.entries(at)) if (this.at[id] && this.at[id] !== k && keys.has(k)) due.add(k);
    this.at = at;
    const spaceOf = {};
    for (const s of sp) for (const t of s.tabs ?? []) spaceOf[t.id] = s;
    const busy = {};
    for (const p of ps) {
      if (!p.terminal || !spaceOf[p.tab]) continue;
      busy[p.pane] = p.status === "working" || !(p.program?.shell || p.program?.agent);
      if (this.busy[p.pane] && !busy[p.pane]) this.sameRepo(at[spaceOf[p.tab].id], keys).forEach((k) => due.add(k));
    }
    this.busy = busy;
    for (const m of machines()) {
      const ready = m.layout === "ready";
      if (ready && this.ready[m.name] === false) for (const k of keys) if (JSON.parse(k)[0] === m.name) due.add(k);
      this.ready[m.name] = ready;
    }
    if (window().active) {
      for (const k of keys) {
        const asks = this.git[k] || this.jj[k] || this.unsure.has(k);
        if (asks && !this.folded.has(JSON.parse(k)[0]) && now - (this.checked[k] ?? 0) > FALLBACK) due.add(k);
      }
    }
    return due;
  }

  // `key` and the other places in its repo (a commit there moves their ahead/behind).
  sameRepo(key, keys) {
    const repo = this.git[key]?.repo;
    return [key, ...(repo ? [...keys].filter((k) => this.git[k]?.repo === repo) : [])];
  }

  refreshMachines(cx) {
    cx.spawn(async cx => {
      try { const r = await hc(["machine", "ls", "--json"]); if (r.code === 0) this.machines = (JSON.parse(r.stdout).machines ?? []).filter((m) => !m.temporary); } catch {}
      cx.notify();
    });
  }

  // One look at a time, each place once however often it was asked for meanwhile.
  refreshGit(keys, cx) {
    for (const k of keys) this.pending.add(k);
    if (this.refreshing) return;
    this.refreshing = true;
    cx.spawn(async (cx) => {
      while (this.pending.size) {
        const keys = [...this.pending];
        this.pending.clear();
        for (const key of keys) await this.check(key, cx);
      }
      const used = new Set(Object.values(this.git).filter(Boolean).map((g) => JSON.parse(g.repo)).filter(([on]) => !on).map(([, repo]) => repo));
      for (const repo of this.watching) if (!used.has(repo)) this.watching.delete(repo);
      this.refreshing = false;
      cx.notify();
    });
  }

  // One place's jj workspaces. Ignore the working copy so a sidebar refresh
  // never snapshots a workspace as a side effect of reading its metadata.
  async checkJj(key, on, cwd) {
    try {
      const r = await exec("jj", ["--ignore-working-copy", "workspace", "list", "--template", 'name ++ "\\t" ++ root ++ "\\n"'], { cwd, on });
      if (r.code !== 0) {
        this.jj[key] = null;
        return;
      }
      const workspaces = r.stdout.split("\n").filter(Boolean).map((line) => {
        const [name, ...path] = line.split("\t");
        return { name, root: path.join("\t").trim() };
      }).filter((workspace) => workspace.name && workspace.root);
      this.jj[key] = workspaces.length ? workspaces : null;
    } catch {
      this.jj[key] = null;
    }
  }

  // Match a space's live folder to its deepest jj workspace root.
  jjFor(s, ps) {
    const workspaces = this.jj[where(s, ps)];
    if (!workspaces) return null;
    const cwd = place(s, ps).replace(/\\/g, "/").replace(/\/$/, "");
    return workspaces
      .filter((workspace) => {
        const root = workspace.root.replace(/\\/g, "/").replace(/\/$/, "");
        return cwd === root || cwd.startsWith(`${root}/`);
      })
      .sort((a, b) => b.root.length - a.root.length)[0] ?? null;
  }

  // One place's git: branch, ahead/behind, its repo.
  async check(key, cx) {
    const [on, cwd] = JSON.parse(key);
    this.checked[key] = Date.now();
    this.unsure.delete(key);
    await this.checkJj(key, on, cwd);
    try {
      // No optional locks: a status that touched the index would wake the watch again.
      // Writes nothing under .git (index lock, fsmonitor cookie): watch() would wake on it.
      const r = await exec("git", ["--no-optional-locks", "-c", "core.fsmonitor=false", "status", "--porcelain=v2", "--branch"], { cwd, on });
      if (r.code !== 0) {
        // Only git's own "no" is remembered as no repo; anything else is asked again.
        if (!/not a git repository/i.test(r.stderr)) this.unsure.add(key);
        this.git[key] = null;
        return;
      }
      // The repo's own .git folder names it; a worktree's top differs from it.
      const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd, on });
      const common = await exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd, on });
      const repo = common.stdout.trim();
      const name = repo.endsWith("/.git") ? base(repo.slice(0, -5)) : base(repo).replace(/\.git$/, "");
      const info = { name, branch: null, ahead: 0, behind: 0, repo: JSON.stringify([on, repo]), linked: repo !== `${top.stdout.trim()}/.git` };
      for (const line of r.stdout.split("\n")) {
        if (line.startsWith("# branch.head ")) info.branch = line.slice(14);
        else if (line.startsWith("# branch.ab ")) {
          const [a, b] = line.slice(12).split(" ");
          info.ahead = Math.abs(parseInt(a, 10)) || 0;
          info.behind = Math.abs(parseInt(b, 10)) || 0;
        }
      }
      this.git[key] = info;
      if (!on) this.watch(repo, cx);
    } catch {
      // Couldn't ask (the machine is away): keep what it showed, look again later.
      this.git[key] ??= null;
      this.unsure.add(key);
    }
  }

  watch(repo, cx) {
    if (this.watching.has(repo)) return;
    this.watching.add(repo);
    cx.spawn(async (cx) => {
      try {
        while (this.watching.has(repo)) {
          await watchFolder(repo);
          const mine = JSON.stringify([null, repo]);
          if (this.watching.has(repo)) this.refreshGit(Object.keys(this.git).filter((k) => this.git[k]?.repo === mine), cx);
        }
      } catch { this.watching.delete(repo); }
    });
  }

  menu(w) {
    // A popup is as tall as its items; height is only the most.
    openOverlay({ mod: "menu-jj", kind: "popup", width: 220, height: 320, props: { tab: "space", target: { id: w.id } } });
  }

  // Spaces in order, each worktree space moved under its main checkout's.
  ordered(ps = panes()) {
    const sp = spaces();
    const ready = (w) => this.shown.has(w.id) || where(w, ps) in this.git || Date.now() - (this.born[w.id] ??= Date.now()) > 1500;
    for (const w of sp) if (!this.shown.has(w.id) && ready(w)) this.shown.add(w.id);
    const list = sp.map((w, i) => ({ w, i, g: this.git[where(w, ps)] ?? null })).filter((r) => this.shown.has(r.w.id));
    const mains = new Set(list.filter((r) => r.g && !r.g.linked).map((r) => r.g.repo));
    const nested = (r) => r.g?.linked && mains.has(r.g.repo);
    const out = [];
    const placed = new Set(); // repos whose worktrees are listed (under the first of its spaces)
    for (const r of list) {
      if (nested(r)) continue;
      out.push({ ...r, tree: null });
      if (!r.g || r.g.linked || placed.has(r.g.repo)) continue;
      placed.add(r.g.repo);
      const kids = list.filter((k) => nested(k) && k.g.repo === r.g.repo);
      kids.forEach((k, n) => out.push({ ...k, tree: n === kids.length - 1 ? "└─" : "├─" }));
    }
    return out;
  }

  // One hc connect call for every machine's app doc; the response carries the
  // tab split trees. The doc is app-owned, so a missing/garbled one just means
  // the old single icon stays.
  refreshLayouts(cx) {
    if (this.layoutsBusy) return;
    const sp = spaces();
    const targets = [];
    if (sp.some((s) => !s.machine)) targets.push("");
    for (const m of new Set(sp.map((s) => s.machine).filter(Boolean))) targets.push(m);
    if (!targets.length) return;
    const quote = (s) => `'${s.replace(/'/g, "'\\''")}'`;
    const requests = targets.map((m, i) => {
      const params = { name: "herdr-app" };
      if (m) params.on = m;
      return JSON.stringify({ jsonrpc: "2.0", id: i + 1, method: "doc.get", params });
    });
    const cmd = `printf '%s\\n' ${requests.map(quote).join(" ")} | hc connect`;
    this.layoutsBusy = true;
    cx.spawn(async (cx) => {
      try {
        const r = await exec("sh", ["-c", cmd]);
        if (r.code !== 0) return;
        const next = { ...this.layouts };
        let changed = false;
        for (const line of r.stdout.split("\n")) {
          if (!line.trim()) continue;
          try {
            const reply = JSON.parse(line);
            const m = targets[(reply.id ?? 0) - 1];
            if (m === undefined || reply.result?.version === undefined) continue;
            if (reply.result.version === this.layoutVersions[m]) continue;
            this.layoutVersions[m] = reply.result.version;
            if (reply.result.value) next[m] = reply.result.value;
            else delete next[m];
            changed = true;
          } catch {}
        }
        if (changed) {
          this.layouts = next;
          this.tabModels = {};
          cx.notify();
        }
      } catch {} finally {
        this.layoutsBusy = false;
      }
    });
  }

  // Stamps agents whose state changed. Done and idle count as one: looking at a
  // finished agent turns done into idle, and looking isn't the agent doing anything.
  track(list, now) {
    let dirty = false;
    for (const a of list) {
      const s = a.status === "done" ? "idle" : a.status;
      if (this.changed[a.address]?.s === s) continue;
      this.changed[a.address] = { s, at: now };
      dirty = true;
    }
    if (!dirty) return;
    const listed = new Set(list.map((a) => a.address));
    for (const [k, c] of Object.entries(this.changed)) if (!listed.has(k) && now - c.at > 30 * 86400000) delete this.changed[k];
    localStorage.setItem("changed", JSON.stringify(this.changed));
  }

  since(agent) {
    return this.changed[agent.address]?.at ?? 0;
  }

  // The next/prev tab across spaces, not around this space only.
  stepTab(direction, cx) {
    const all = spaces();
    const current = all.find((s) => s.active)?.tabs.find((t) => t.active)?.id;
    const tabs = all.flatMap((s) => (s.tabs ?? []).filter((t) => !t.settled).map((t) => t.id));
    const at = tabs.indexOf(current);
    if (at < 0 || !tabs.length) return;
    run("tab.select", { id: tabs[(at + direction + tabs.length) % tabs.length] });
  }

  toggleSpaceTabFold(id, cx) {
    this.foldedSpaces.has(id) ? this.foldedSpaces.delete(id) : this.foldedSpaces.add(id);
    localStorage.setItem("spaces.folded", JSON.stringify([...this.foldedSpaces]));
    cx.notify();
  }

  // The rows, under a header per machine once one isn't this computer. Each
  // space brings its tabs along unless its chevron folded them.
  grouped(t, collapsed) {
    const ps = panes();
    const byPane = new Map(ps.map((p) => [p.pane, p]));
    const rows = this.ordered(ps);
    const all = terminals(), list = agents();
    const now = Date.now();
    this.track(list, now);
    this.listed = new Map(list.map((a) => [a.address, a.status]));
    this.agentByPane = new Map(list.filter((a) => a.pane).map((a) => [a.pane, a]));
    const shown = list.find((a) => a.focused)?.address;
    const draw = (r) => {
      if (collapsed) return this.compact(r, t);
      const content = h_flex().w_full().items_stretch().children([
        this.spaceBanner(r, t),
        v_flex().flex_1().min_w(0).children(this.tabRows(r, t, ps, byPane, all, list, shown, now)),
      ]);
      return v_flex().w_full().my(3).rounded(8).border(1)
        .border_color(r.w.active ? t.selected : t.border)
        .overflow_hidden()
        .bg(t.chrome)
        .child(content);
    };
    const remote = [...new Set([...rows.map(r => r.w.machine).filter(Boolean), ...this.machines.map(m => m.name)])].sort();
    const loading = m => {
      const layout = machines().find(k => k.name === m)?.layout;
      return layout === "loading" || (!layout && this.machines.some(k => k.name === m && k.state === "connected"))
        || spaces().some(s => (s.machine ?? null) === m && !this.shown.has(s.id));
    };
    const loadingRow = m => div().id(`machine-loading-${m ?? "local"}`).h(28).flex_none().px(8).text_size(12).text_color(t.dim).child(collapsed ? "…" : "Loading…");
    if (!remote.length) return loading(null) && !rows.length ? [loadingRow(null)] : rows.map(draw);
    const machineNames = [null, ...remote];
    return machineNames.flatMap((m) => {
      const mine = rows.filter((r) => (r.w.machine ?? null) === m);
      const machine = this.machines.find(k => k.name === m);
      const connected = !m || machine?.state === "connected";
      const folded = this.folded.has(m);
      const head = h_flex().id(`machine-${m ?? "local"}`).h(26).flex_none().px(collapsed ? 2 : 8).gap(7).items_center().text_size(11).text_color(t.dim)
        .cursor_pointer().hover(s => s.bg(t.hover))
        .on_click((_e, cx) => {
          folded ? this.folded.delete(m) : this.folded.add(m);
          localStorage.setItem("machines.folded", JSON.stringify([...this.folded]));
          cx.notify();
        })
        .child(svg(`mods/workspace-chrome/${m ? "server" : "monitor"}.svg`).size(13).flex_none())
        .when(!collapsed, el => el.child(div().flex_1().truncate().child(m ?? "This computer"))
          .when(!connected, el => el.child(div().flex_none().child((machine?.state ?? "asleep").replace(/_/g, " "))))
          .when(connected, el => el.child(div().id(`machine-add-${m ?? "local"}`).flex_none().px(4).rounded(4).hover(s => s.bg(t.hover).text_color(t.foreground))
            .on_click((_e, cx) => { cx.stop_propagation(); run("space.new", m ? { machine: m } : {}); }).child("+")))
          .child(div().size(6).rounded(3).flex_none().bg(connected ? t.ansi2 : t.dim))
          .child(svg(`mods/workspace-chrome/chevron-${folded ? "right" : "down"}.svg`).size(11).flex_none()));
      const empty = h_flex().id(`machine-new-${m ?? "local"}`).h(28).flex_none().px(8).gap(7).items_center().rounded(7)
        .text_size(12).text_color(t.dim).hover(s => s.bg(t.hover).text_color(t.foreground))
        .on_click(() => run("space.new", m ? { machine: m } : {}))
        .child(svg("mods/workspace-chrome/plus.svg").size(12)).when(!collapsed, el => el.child("New space there"));
      return [head, ...(folded ? [] : mine.length ? mine.map(draw) : [loading(m) ? loadingRow(m) : empty])];
    });
  }

  // Only what's unusual, after the name: "herdr \u00b7 spike \u21912 \u21931". The repo or
  // branch goes when the name already says it (a worktree is named after its branch),
  // and master/main go: nearly every space is on one.
  gitTail(g, tree, name, t) {
    const raw = g?.branch ?? "detached";
    const same = (a) => a.toLowerCase() === name.toLowerCase();
    const branch = g && (same(raw) || raw === "master" || raw === "main") ? "" : (g ? raw : "");
    const repo = g && (tree || same(g.name)) ? "" : (g?.name ?? "");
    const where = [repo, branch].filter(Boolean).join(" \u00b7 ");
    return h_flex()
      .flex_1()
      .min_w(0)
      .gap(5)
      .justify_end()
      .items_center()
      .text_size(11.5)
      .text_color(t.dim)
      .when(Boolean(where), (el) => el.child(div().min_w(0).truncate().child(where)))
      .when(g.ahead > 0, (el) => el.child(div().flex_none().text_color(t.ansi2).child(`\u2191${g.ahead}`)))
      .when(g.behind > 0, (el) => el.child(div().flex_none().text_color(t.ansi1).child(`\u2193${g.behind}`)));
  }

  // The space is a thin colored rail with its initial. The full name is in
  // the tooltip; no header row and no stacked letters.
  spaceBanner({ w }, t) {
    const colors = shared("space.colors") ?? {};
    const color = colors[w.id] ?? "ansi6";
    const fill = color.startsWith("#") ? color : (MARK[color] ?? t[color]);
    return v_flex()
      .id(`space-banner-${w.id}`)
      .w(20)
      .flex_none()
      .min_h(0)
      .rounded_l(7)
      .bg(fill)
      .border_r(1)
      .border_color(t.border)
      .items_center()
      .py(2)
      .cursor_pointer()
      .tooltip(w.name)
      .on_click(() => run("space.select", { id: w.id }))
      .on_mouse_down("right", () => this.menu(w))
      .child(div().id(`space-fold-${w.id}`).size(14).flex_none().rounded(4)
        .text_size(9).font_bold().text_color("#ffffff")
        .flex().items_center().justify_center()
        .cursor_pointer()
        .hover((s) => s.opacity(0.9))
        .on_hover((on, cx) => {
          if (on) this.hoveredSpace = w.id;
          else if (this.hoveredSpace === w.id) this.hoveredSpace = null;
          cx.notify();
        })
        .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .on_click((_e, cx) => { cx.stop_propagation(); this.toggleSpaceTabFold(w.id, cx); })
        .child(this.hoveredSpace === w.id
          ? svg(`mods/workspace-chrome/chevron-${this.foldedSpaces.has(w.id) ? "right" : "down"}.svg`).size(9).text_color("#ffffff")
          : div().child([...w.name][0]?.toUpperCase() ?? "?")));
  }

  row({ w, i, g, tree }, t) {
    const on = w.active;
    const jj = this.jjFor(w, panes());
    const colors = shared("space.colors") ?? {};
    const color = colors[w.id] ?? "ansi6";
    const fill = color.startsWith("#") ? color : (MARK[color] ?? t[color]);
    return v_flex()
      .relative()
      .id(`space-${w.id}`)
      .px(8)
      .h(rowHeight({ tree }))
      .flex_none()
      .justify_center()
      .rounded(8)
      .when(!on, (el) => el.hover((s) => s.bg(t.hover)))
      .when(this.pressed !== null && this.over === i && this.pressed !== i, (el) => el.border_t(2).border_color(t.accent))
      .on_mouse_down("left", () => {
        this.pressed = i;
        this.over = i;
      })
      .on_mouse_up("left", (_e, cx) => {
        const from = this.pressed;
        this.pressed = null;
        if (from !== null && from !== i) run("space.move", { id: spaces()[from].id, index: i + 1 });
        else run("space.select", { id: w.id });
        cx.notify();
      })
      .on_mouse_down("right", () => this.menu(w))
      .child(
        h_flex()
          .gap(9)
          .items_center()
          .when(Boolean(tree), el => el.pl(22).child(svg("mods/workspace-chrome/branch.svg").size(13).text_color(t.dim)))
          .when(!tree, el => el.child(h_flex().size(18).flex_none().rounded(5).bg(fill).items_center().justify_center().text_size(10.5).font_bold().text_color("#ffffff").child([...w.name][0]?.toUpperCase() ?? "?")))
          .child(div().flex_shrink(0).max_w(150).truncate().text_color(t.foreground).child(w.name))
          .child(g ? this.gitTail(g, tree, w.name, t) : div().flex_1())
          .when(Boolean(jj), (el) => el.child(div().flex_none().max_w(110).truncate().text_size(11.5).text_color(t.dim).child(`jj ${jj.name}`)))
          .child(div().id(`space-fold-${w.id}`).flex_none().p(3).rounded(4).text_color(t.dim).cursor_pointer()
            .hover(s => s.bg(t.hover).text_color(t.foreground))
            .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
            .on_click((_e, cx) => { cx.stop_propagation(); this.toggleSpaceTabFold(w.id, cx); })
            .child(svg(`mods/workspace-chrome/chevron-${this.foldedSpaces.has(w.id) ? "right" : "down"}.svg`).size(11).flex_none())),
      );
  }

  // A space's tabs are their panes: no separate tab row. A split tab is the
  // pane tree itself; a single-pane tab is one pane button (with the tab's
  // name, when it has one).
  tabRows({ w }, t, ps, byPane, all, list, shown, now) {
    if (this.foldedSpaces.has(w.id)) return [];
    return (w.tabs ?? []).flatMap((c, ti) => {
      const doc = this.layouts[w.machine ?? ""];
      const spaceDoc = doc?.spaces?.find((s) => s.id === localId(w.id, w.machine));
      const tabDoc = spaceDoc?.tabs?.find((t) => t.id === localId(c.id, w.machine));
      const tree = tabDoc?.root;
      const menu = () => openOverlay({ mod: "menu-jj", kind: "popup", width: 200, height: 240, props: { tab: "tab", target: { id: c.id, space: w.id } } });
      const kids = list.filter((a) => a.tab === c.id).flatMap((a) => this.tree(all, a.address).map((s) => this.subRow(t, s, shown)));
      let panes = null;
      if (tree) {
        if (!(c.id in this.tabModels)) this.tabModels[c.id] = buildLayout(tree, ps, w.machine, paneHeight(tree, ps, w.machine));
        const model = this.tabModels[c.id];
        if (model?.kind === "block") {
          const pane = byPane.get(model.pane);
          panes = pane ? this.paneButton(pane, t, model.height, now, c.named ? c.name : null, menu, false) : null;
        } else if (model) {
          panes = this.paneTree(model, byPane, t, now, menu, true);
        }
      } else {
        const pane = ps.find((p) => p.tab === c.id && p.focused) ?? ps.find((p) => p.tab === c.id);
        panes = pane ? this.paneButton(pane, t, 24, now, c.named ? c.name : null, menu, false) : null;
      }
      const content = [panes, ...kids].filter(Boolean);
      return content.length ? [v_flex().w_full().min_w(0)
        .when(ti > 0, (el) => el.border_t(2).border_color(t.border))
        .children(content)] : [];
    });
  }

  // A tab's panes as real buttons, laid out from the cached split model.
  // Clicking one focuses that pane (and selects its tab/space).
  paneTree(model, byPane, t, now = 0, menu = null, compact = false) {
    if (!model) return null;
    if (model.kind === "block") {
      const pane = byPane.get(model.pane);
      return pane ? this.paneButton(pane, t, model.height, now, null, menu, compact) : null;
    }
    const row = model.kind === "row";
    const kids = model.children.map(({ weight, node }, i) => {
      const kid = this.paneTree(node, byPane, t, now, menu, compact);
      if (!kid) return null;
      return div()
        .flex()
        .when(row, (el) => el.flex_1().min_w(0).h(model.height).flex_grow(weight))
        .when(!row, (el) => el.w_full().flex_none())
        .when(i > 0 && row, (el) => el.border_l(1).border_color(t.border))
        .when(i > 0 && !row, (el) => el.border_t(1).border_color(t.border))
        .child(kid);
    }).filter(Boolean);
    if (!kids.length) return null;
    if (kids.length === 1) return kids[0];
    return (row ? h_flex() : v_flex()).h(model.height).w_full().min_w(0).children(kids);
  }

  paneButton(pane, t, height = 24, now = 0, label = null, menu = null, compact = false) {
    const program = pane.program;
    const agent = this.agentByPane?.get(pane.pane);
    const status = agent?.status ?? pane.status;
    const since = agent ? this.since(agent) : 0;
    const title = (pane.title ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();
    const name = label || (!program?.shell && program?.name) || cwdName(pane.cwd) || title || program?.name || "Terminal";
    return h_flex()
      .id(`pane-${pane.pane}`)
      .h(height)
      .w_full()
      .min_w(0)
      .px(6)
      .gap(6)
      .items_center()
      .when(pane.focused, (el) => el.bg(t.raised))
      .when(!pane.focused, (el) => el.hover((s) => s.bg(t.hover)))
      .on_click(() => run("pane.focus", { pane: pane.pane }))
      .on_mouse_down("right", () => menu?.())
      .when(Boolean(program?.icon), (el) => el.child(agentIcon(program, 12, t.muted)))
      .when(!program?.icon, (el) => el.child(div().size(12).flex_none()))
      .child(div().flex_1().min_w(0).truncate().text_color(pane.focused ? t.foreground : t.muted).child(pane.zoomed ? `${name} Z` : name))
      .when(Boolean(since), (el) => el.child(div().flex_none().text_size(11).text_color(t.dim).child(duration(now - since))))
      .when(Boolean(status), (el) => el.child(this.status(t, { status }, compact)));
  }

  peek(address) {
    run("terminal.peek", { terminal: address });
  }

  // Live sub-agents under their tab, depth first, with the tree lines in front.
  tree(all, address, lead = []) {
    const kids = all.filter((k) => k.parent === address && k.state === "live");
    return kids.flatMap((k, i) => {
      const last = i === kids.length - 1;
      return [
        { t: k, lines: [...lead, last ? "└" : "├"] },
        ...this.tree(all, k.address, [...lead, last ? "" : "│"]),
      ];
    });
  }

  subRow(t, s, shown) {
    const k = s.t;
    const status = kidStatus(k, this.listed);
    const pic = agentIcon(k.program, 14, t.foreground);
    const on = k.address === shown;
    return h_flex()
      .id(`sub-${k.address}`)
      .pl(22)
      .pr(8)
      .rounded(8)
      .h(26)
      .flex_none()
      .gap(0)
      .items_center()
      .text_size(12.5)
      .when(on, (el) => el.bg(t.raised))
      .hover((s) => s.bg(t.hover))
      .on_click(() => this.peek(k.address))
      .children(s.lines.map((l) => div().self_start().mt(-4).w(9).h(17).mr(4).flex_none()
        .when(Boolean(l), el => el.border_l(1.5).border_color(t.input))
        .when(l === "└" || l === "├", el => el.border_b(1.5).rounded_bl(6))))
      .when(Boolean(pic), el => el.child(div().mr(8).child(pic)))
      .child(div().flex_1().truncate().text_color(on ? t.foreground : t.muted).child(k.name || k.template || k.program?.name || k.address))
      .child(this.status(t, { status }));
  }

  // The same status marks the agents list used: spinner, Needs you, idle ring,
  // done dot. Tabs without an agent draw none of them.
  status(t, a, compact = false) {
    const color = t[a.status] ?? t.dim;
    if (a.status === "working") return svg("mods/workspace-chrome/spinner.svg").size(12).mx(1).flex_none().text_color(t.working).spin(900);
    if (a.status === "blocked" && compact) return div().size(14).flex_none().rounded(4).bg(t.blocked + "26").text_size(10.5).font_bold().text_color(t.blocked).flex().items_center().justify_center().child("!");
    if (a.status === "blocked") return div().flex_none().px(6).h(18).rounded(5).bg(t.blocked + "26").text_size(10.5).font_semibold().text_color(t.blocked).flex().items_center().child("Needs you");
    if (a.status === "idle") return div().size(7).mx(3).flex_none().rounded(4).border(1.5).border_color(t.idle ?? t.dim);
    return div().size(7).mx(3).flex_none().rounded(4).bg(a.status === "done" ? color : t.dim + "00");
  }

  compact({ w, i }, t) {
    return h_flex()
      .id(`space-${w.id}`)
      .h(26)
      .flex_none()
      .justify_center()
      .gap(4)
      .when(w.active, (el) => el.bg(t.raised))
      .hover((s) => s.bg(t.hover))
      .on_click(() => run("space.select", { id: w.id }))
      .child(div().text_color(w.active ? t.foreground : t.muted).child(String(i + 1)))
      .child(div().text_color(tone(t, w.status)).child(glyph(w.status)));
  }

  render() {
    const t = theme();
    const collapsed = narrow();
    const palette = ["ansi6", "ansi3", "ansi4", "ansi5", "ansi2", "ansi1"];
    const sp = spaces();
    const ids = new Set(sp.map(p => p.id));
    const kept = Object.fromEntries(Object.entries(shared("space.colors") ?? {}).filter(([id]) => ids.has(id)));
    let changed = Object.keys(kept).length !== Object.keys(shared("space.colors") ?? {}).length;
    for (const p of sp) {
      if (kept[p.id] || p.name === "~") continue;
      const uses = c => Object.values(kept).filter(v => v === c).length;
      kept[p.id] = palette.reduce((best, c) => uses(c) < uses(best) ? c : best);
      changed = true;
    }
    if (changed) setShared("space.colors", kept);
    return v_flex().size_full().min_h(0).bg(t.chrome).text_size(13)
      .child(h_flex().h(31).pl(16).pr(10).items_center().justify_between().text_size(11.5).text_color(t.dim)
        .when(!collapsed, el => el.child("Spaces"))
        .child(div().id("space-new").p(4).rounded(5).hover(s => s.bg(t.hover).text_color(t.foreground)).on_click(() => run("space.new")).child("+")))
      .child(v_flex().flex_1().min_h(0).px(8).pb(14).overflow_y_scrollbar().mode("always")
        .on_mouse_up("left", (_e, cx) => { this.pressed = null; this.tabPressed = null; this.tabOver = null; cx.notify(); })
        .children(this.grouped(t, collapsed)));
  }
}
