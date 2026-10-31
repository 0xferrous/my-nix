import { View, div } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, Scrollbar } from "gpui-base";
import { run, props, closeOverlay, theme, spaces, panes, exec, home } from "herdr";

const ROOT = (userHome) => `${userHome}/.herdr/workspaces`;
const slug = (name) => name.replace(/[^A-Za-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "");
const slash = (path) => path.replace(/\\/g, "/").replace(/\/$/, "");
const template = 'name ++ "\\t" ++ root ++ "\\n"';

function place(space) {
  if (!space) return null;
  const tabs = new Set((space.tabs ?? []).map((tab) => tab.id));
  return panes().find((pane) => tabs.has(pane.tab) && pane.cwd)?.cwd || space.folder || null;
}

function workspaceAt(path, workspaces) {
  if (!path) return null;
  const at = slash(path);
  return (workspaces ?? [])
    .filter((workspace) => {
      const root = slash(workspace.root);
      return at === root || at.startsWith(`${root}/`);
    })
    .sort((a, b) => b.root.length - a.root.length)[0] ?? null;
}

function spaceAt(path, machine) {
  return spaces().find((space) => {
    if ((space.machine ?? null) !== (machine ?? null)) return false;
    const at = place(space);
    return at && slash(at) === slash(path);
  });
}

export default class JjWorkspace extends View {
  init(_props, cx) {
    this.action = props()?.action;
    this.space = spaces().find((space) => space.id === props()?.space) ?? null;
    this.on = this.space?.machine ?? props()?.machine ?? null;
    this.folder = props()?.folder || place(this.space) || null;
    this.userHome = this.on ? null : home();
    this.workspaces = undefined;
    this.current = null;
    this.selected = props()?.workspace ?? null;
    this.text = "";
    this.at = 0;
    this.busy = false;
    this.error = "";
    this.handle = cx.focus_handle();
    this.input = InputState.new({ value: "", placeholder: this.action === "open" ? "filter workspaces" : "workspace name" });
    this.input.on("change", (_event, cx) => {
      this.text = this.input.value();
      this.error = "";
      this.at = 0;
      cx.notify();
    });
    this.input.on("submit", (_event, cx) => this.go(cx));
    this.inputFocused = true;
    this.input.on("focus", (_event, cx) => { this.inputFocused = true; cx.notify(); });
    this.input.on("blur", (_event, cx) => { this.inputFocused = false; cx.notify(); });
    if (this.action !== "forget") {
      this.input.focus();
      cx.timer.after(500, () => this.input.focus());
    } else this.handle.focus();

    cx.spawn(async (cx) => {
      try {
        if (this.on) {
          let result;
          try { result = await exec("sh", ["-c", 'printf %s "$HOME"'], { on: this.on }); } catch {}
          if (!result || result.code !== 0 || !result.stdout.trim()) {
            result = await exec("powershell.exe", ["-NoProfile", "-Command", "[Console]::Write($HOME)"], { on: this.on });
          }
          if (result.code !== 0 || !result.stdout.trim()) throw new Error("Could not find the remote home folder.");
          this.userHome = slash(result.stdout.trim());
        }
        if (!this.folder) throw new Error("No workspace folder is available.");
        const result = await exec("jj", ["--ignore-working-copy", "workspace", "list", "--template", template], { cwd: this.folder, on: this.on });
        if (result.code !== 0) throw new Error(result.stderr.trim() || "This folder is not in a jj repository.");
        this.workspaces = result.stdout.split("\n").filter(Boolean).map((line) => {
          const [name, ...path] = line.split("\t");
          return { name, root: path.join("\t").trim() };
        }).filter((workspace) => workspace.name && workspace.root);
        this.current = workspaceAt(this.folder, this.workspaces);
        if (!this.selected) this.selected = this.current?.name ?? null;
        cx.notify();
      } catch (error) {
        this.error = String(error);
        this.workspaces = null;
        cx.notify();
      }
    });
  }

  close() {
    closeOverlay(props()?.overlay);
  }

  shown() {
    const filter = this.text.trim().toLowerCase();
    return (this.workspaces ?? []).filter((workspace) =>
      !filter || `${workspace.name} ${workspace.root}`.toLowerCase().includes(filter));
  }

  go(cx) {
    if (this.busy || !this.workspaces) return;
    if (this.action === "open") return this.open(this.shown()[this.at]);
    cx.spawn(async (cx) => this.perform(cx));
  }

  async perform(cx) {
    if (this.busy) return;
    this.busy = true;
    this.error = "";
    cx.notify();
    try {
      if (this.action === "new") await this.create();
      else if (this.action === "forget") await this.forget();
      else throw new Error("Unknown JJ workspace action.");
      this.close();
    } catch (error) {
      this.error = String(error);
    }
    this.busy = false;
    cx.notify();
  }

  async create() {
    const name = this.text.trim();
    if (!name) throw new Error("Type a workspace name.");
    const path = `${ROOT(slash(this.userHome))}/${slug(this.current?.root.split(/[\\/]/).filter(Boolean).pop() || "repo")}/${slug(name) || "workspace"}`;
    const result = await exec("jj", ["workspace", "add", "--name", name, path], { cwd: this.folder, on: this.on });
    if (result.code !== 0) throw new Error(result.stderr.trim() || "jj workspace add failed.");
    run("space.new", { folder: path, machine: this.on });
  }

  open(workspace) {
    if (!workspace || this.busy) return;
    this.close();
    const existing = spaceAt(workspace.root, this.on);
    if (existing) run("space.select", { id: existing.id });
    else run("space.new", { folder: workspace.root, machine: this.on });
  }

  async forget() {
    const workspace = this.workspaces.find((item) => item.name === this.selected);
    if (!workspace) throw new Error("Workspace not found.");
    if (workspace.name === "default") throw new Error("The default workspace cannot be forgotten here.");
    const result = await exec("jj", ["workspace", "forget", workspace.name], { cwd: this.folder, on: this.on });
    if (result.code !== 0) throw new Error(result.stderr.trim() || "jj workspace forget failed.");
  }

  key(event, cx) {
    if (event.key === "escape") return this.close();
    if (this.action === "open") {
      const count = this.shown().length;
      if (event.key === "enter") this.open(this.shown()[this.at]);
      else if ((event.key === "down" || event.key === "up") && count) this.at = (this.at + (event.key === "down" ? 1 : count - 1)) % count;
      else return;
      cx.stop_propagation();
      return cx.notify();
    }
    if (event.key === "enter" && this.action === "forget") return this.go(cx);
  }

  renderOpen(t) {
    const rows = this.shown();
    const row = (workspace, index) => {
      const selected = index === this.at;
      const open = spaceAt(workspace.root, this.on);
      return v_flex().id(`jj-workspace-${index}`).flex_none().h(46).px(10).justify_center().rounded(7)
        .cursor_pointer().when(selected, (el) => el.bg(t.selected)).when(!selected, (el) => el.hover((s) => s.bg(t.hover)))
        .on_click(() => this.open(workspace))
        .child(h_flex().gap(8).items_center()
          .child(div().flex_1().min_w(0).truncate().text_color(t.foreground).child(workspace.name))
          .when(workspace.name === "default", (el) => el.child(div().flex_none().text_size(11).text_color(t.dim).child("default")))
          .when(Boolean(open), (el) => el.child(div().flex_none().text_size(11).text_color(t.accent).child("open"))))
        .child(div().truncate().text_size(11.5).text_color(t.dim).child(workspace.root));
    };
    return v_flex().id("jj-workspace").track_focus(this.handle).on_key_down((e, cx) => this.key(e, cx))
      .size_full().p(16).gap(10).bg(t.popover).text_size(13)
      .child(h_flex().child(div().flex_1().font_semibold().text_color(t.foreground).child("Open JJ workspace"))
        .child(div().text_size(11).text_color(t.dim).child(`${rows.length}/${this.workspaces?.length ?? 0} workspaces`)))
      .when(this.workspaces === undefined, (el) => el.child(div().text_color(t.muted).child("…")))
      .when(this.workspaces === null, (el) => el.child(div().text_color(t.blocked).child(this.error || "Not a JJ repository.")))
      .when(Array.isArray(this.workspaces), (el) => el
        .child(Input.new(this.input).h(32).px(10).items_center().rounded(6).border(1).border_color(this.inputFocused ? t.accent : t.input).bg(t.background).text_color(t.foreground))
        .child(div().relative().flex_1().min_h(0)
          .child(v_flex().id("jj-workspace-list").size_full().overflow_y_scroll().children(rows.map(row))
            .when(rows.length === 0, (e) => e.child(div().p(10).text_color(t.dim).child("No matching workspaces."))))
          .child(Scrollbar.vertical("jj-workspace-list").absolute().inset_0())))
      .when(Boolean(this.error), (el) => el.child(div().text_color(t.blocked).child(this.error)))
      .child(h_flex().justify_end().text_size(11).text_color(t.dim).child("↑↓ choose · ↵ open · esc close"));
  }

  render() {
    const t = theme();
    if (this.action === "open") return this.renderOpen(t);
    const workspace = this.workspaces?.find((item) => item.name === this.selected);
    const creating = this.action === "new";
    const blocked = this.workspaces === null || (this.action === "forget" && (!workspace || workspace.name === "default"));
    const detail = this.workspaces === undefined ? "Checking repository…"
      : this.workspaces === null ? (this.error || "This folder is not in a JJ repository.")
      : creating ? `Creates a workspace under ${ROOT(slash(this.userHome))}; JJ starts it from this workspace's parent commit.`
      : workspace ? `Forget ${workspace.name}. Its directory and files will remain on disk.`
      : "The current workspace cannot be forgotten here.";
    return v_flex().id("jj-workspace").track_focus(this.handle).on_key_down((e, cx) => this.key(e, cx))
      .size_full().p(16).gap(10).bg(t.popover).text_size(13)
      .child(div().font_semibold().text_color(t.foreground).child(creating ? "New JJ workspace" : `Forget JJ workspace ${this.selected ?? ""}?`))
      .child(div().text_color(t.muted).child(detail))
      .when(creating && !blocked, (el) => el.child(Input.new(this.input).h(32).px(10).items_center().rounded(6).border(1)
        .border_color(this.inputFocused ? t.accent : t.input).bg(t.background).text_color(t.foreground)))
      .when(Boolean(this.error), (el) => el.child(div().text_color(t.blocked).child(this.error)))
      .child(div().flex_1())
      .child(h_flex().justify_end().text_size(11).text_color(t.dim)
        .child(this.busy ? "working…" : blocked ? "esc close" : this.action === "forget" ? "↵ forget · esc cancel" : "↵ create · esc cancel"));
  }
}
