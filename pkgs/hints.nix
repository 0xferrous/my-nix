{
  lib,
  source,
  python314Packages,
  wrapGAppsHook3,
  gtk3,
  atspi2Core,
  gtkLayerShell,
  libwnck,
  dbus,
  glib,
  pango,
  gdk-pixbuf,
  harfbuzz,
  grim,
}:

let
  py = python314Packages;
in
py.buildPythonApplication rec {
  pname = "hints";
  version = "0.1.1";
  src = source;
  format = "setuptools";

  nativeBuildInputs = [
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    atspi2Core
    gtkLayerShell
    libwnck
    dbus
    glib
    pango
    gdk-pixbuf
    harfbuzz
  ];

  propagatedBuildInputs = with py; [
    pygobject3
    pillow
    pyscreenshot
    opencv4
    numpy
    evdev
    dbus-python
    rich
  ];

  dontWrapGApps = true;

  postPatch = ''
    substituteInPlace setup.py \
      --replace-fail 'cmdclass={"install": PostInstallCommand},' 'cmdclass={}'

    # When hints is launched from a compositor keybinding, the trigger key can
    # be delivered to the newly-created overlay. For Mod+Alt+H, that leaked
    # "h" may immediately select a hint and close the overlay. Ignore the
    # initial key burst right after the overlay is shown.
    python - <<'PY'
    from pathlib import Path

    path = Path("hints/huds/overlay.py")
    text = path.read_text()
    text = text.replace(
        '        keymap = Gdk.Keymap.get_for_display(Gdk.Display.get_default())',
        '        if time() - getattr(self, "shown_at", 0) < 0.25:\n'
        '            return\n\n'
        '        keymap = Gdk.Keymap.get_for_display(Gdk.Display.get_default())',
        1,
    )
    text = text.replace(
        '        if not self.is_wayland:\n'
        '            seat = Gdk.Display.get_default().get_default_seat()\n',
        '        self.shown_at = time()\n\n'
        '        if not self.is_wayland:\n'
        '            seat = Gdk.Display.get_default().get_default_seat()\n',
        1,
    )
    path.write_text(text)
    PY
  '';

  preFixup = ''
    makeWrapperArgs+=(
      "''${gappsWrapperArgs[@]}"
      --prefix GI_TYPELIB_PATH : ${
        lib.makeSearchPath "lib/girepository-1.0" [
          glib.out
          pango.out
          gdk-pixbuf
          gtk3
          atspi2Core
          gtkLayerShell
          libwnck
          harfbuzz.out
        ]
      }
      --prefix XDG_DATA_DIRS : ${
        lib.makeSearchPath "share" [
          gtk3
          atspi2Core
          gtkLayerShell
          libwnck
          gdk-pixbuf
        ]
      }
      --prefix PATH : ${lib.makeBinPath [ grim ]}
    )
  '';

  pythonImportsCheck = [
    "hints"
    "hints.cli"
  ];

  meta = with lib; {
    description = "Click, scroll, and drag with your keyboard";
    homepage = "https://github.com/AlfredoSequeida/hints";
    license = licenses.gpl3Plus;
    mainProgram = "hints";
    platforms = platforms.linux;
  };
}
