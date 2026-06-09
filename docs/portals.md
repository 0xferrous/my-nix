# XDG portals

Standard `xdg-desktop-portal` interfaces:

- `org.freedesktop.portal.Access` — sandbox access grants
- `org.freedesktop.portal.Account` — account information
- `org.freedesktop.portal.AppChooser` — app selection dialogs
- `org.freedesktop.portal.Background` — background/autostart requests
- `org.freedesktop.portal.Camera` — camera access
- `org.freedesktop.portal.Clipboard` — clipboard access
- `org.freedesktop.portal.DynamicLauncher` — launcher shortcuts
- `org.freedesktop.portal.Email` — email compose / mailto handling
- `org.freedesktop.portal.FileChooser` — file open/save dialogs
- `org.freedesktop.portal.FileTransfer` — file transfer between sandboxed apps
- `org.freedesktop.portal.GlobalShortcuts` — global shortcut registration
- `org.freedesktop.portal.Inhibit` — inhibit suspend/idle/session actions
- `org.freedesktop.portal.Location` — location access
- `org.freedesktop.portal.Notification` — notifications
- `org.freedesktop.portal.OpenURI` — open URLs / URIs
- `org.freedesktop.portal.Print` — printing
- `org.freedesktop.portal.RemoteDesktop` — remote desktop / input sharing
- `org.freedesktop.portal.ScreenCast` — screen capture streams
- `org.freedesktop.portal.Screenshot` — screenshots
- `org.freedesktop.portal.Secret` — secret service access
- `org.freedesktop.portal.Settings` — desktop settings queries
- `org.freedesktop.portal.Trash` — trash / recycle operations
- `org.freedesktop.portal.Wallpaper` — wallpaper changes

Notes:

- Backend packages like `xdg-desktop-portal-gtk`, `xdg-desktop-portal-gnome`, `xdg-desktop-portal-hyprland`, and `xdg-desktop-portal-termfilechooser` implement some of these interfaces.
- Availability depends on the compositor/session and the installed backend set.
