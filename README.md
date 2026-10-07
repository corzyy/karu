# Dynamic Island

A top-centre **Dynamic Island** bar for [Quickshell](https://quickshell.outfoxxed.me/)
(QML / Qt 6 / Wayland layer-shell). A small rounded pill expands on click into a
full control centre.

Everything is **placeholder-safe**: it runs with no services present, no WM
integration and no system state. Widgets degrade gracefully to inert visuals when
their service is unavailable, but the workspace widget, Control Center, media,
lock screen, notifications, polkit prompt, wallpapers, themes and Settings app
are all live (see the table at the end).

The workspace row always shows the ids in `Theme.persistentWorkspaces`
(`[1, 2, 3, 4, 5]` by default), even when a workspace is empty or not yet
created, so its width stays stable. Any other numeric workspace Hyprland
reports is merged in too. Switching workspaces is animated as motion: one accent
lens glides from the old slot to the new one, squash-and-stretching as it travels
(elongating off the mark, relaxing as it settles), and both the glide time and
the amount of stretch scale with the distance travelled — so a hop to the next
workspace is quick and light while a jump across the row is longer and
stretchier. The highlight follows the **focused** workspace (not just the bar's
own monitor), so activating a workspace on a second output still lights up its
dot here. Hover a dot to see it grow and brighten, **click** it to switch
workspaces, or **scroll** over the row to step through them (wrapping at the
ends). The row is sized to match the status icons on the right, so the collapsed
pill stays symmetric and its clock stays centred.

The Session panel's **Lock** button — and `karu lock` — raise a macOS-style
lockscreen built with Quickshell's session-lock protocol and PAM. It lives
entirely inside this config; **no SDDM changes** are involved.

## Layout

```
shell.qml                  entry point: PanelWindow + expand/collapse + session lock
lock-test.qml              render the lockscreen as a normal window (safe preview)
core/                      non-visual modules (QML singletons)
  config/                  user configuration
    qmldir                 singleton registrations
    Settings.qml           user settings (persisted to settings.json; edited by the Settings app)
    ControlCatalog.js      the Control Center control registry + grid math
  theme/                   palette + theme manager
    qmldir                 singleton registrations
    Theme.qml              colors, radii, sizes, fonts
    GameMode.qml           lightweight "Game Mode" state (flat bar, no motion)
    Colors.qml             the mutable active palette (written by Themes.qml)
    Themes.qml             Matugen-backed theme manager
  services/                system services
    qmldir                 singleton registrations
    Brightness.qml         ddcutil brightness for every DDC/CI monitor
    Notifications.qml      freedesktop notification hub (server + banner/history models)
    Polkit.qml             polkit authentication agent (island prompt)
    Wallhaven.qml          Wallhaven search API client (Browse tab)
    Wallpaper.qml          wallpaper catalogue + setter
ui/                        visual components
  bar/                     the always-present island chrome
    Clock.qml              shared HH:mm; grows + reveals the date in the Control Center
    NotchBar.qml           the fused notch-mode silhouette (one Shape path)
    PanelShadow.qml        drop shadow drawn behind the tile-detail card
    PanelStack.qml         owns the selected panel
    StatusIcons.qml        Wi-Fi / Bluetooth / volume glyphs
    WorkspaceIndicator.qml live Hyprland workspaces
  panels/                  the expanded panels (plus the shared detail card)
    AppLauncherPanel.qml   app grid + search
    BluetoothPanel.qml     the Bluetooth dialog's content (in a DetailCard)
    BrightnessPanel.qml    the Display dialog: per-monitor brightness sliders
    ControlCenterPanel.qml clock/date header (with a Settings button), the grid of quick controls, notifications
    DetailCard.qml         shared tile-detail card (grows out of the tile)
    ControlItem.qml        one live control, shared by the panel and the editor
    ControlNotificationsCard.qml  the Control Center's live notification list
    ControlTrayCard.qml    the Control Center's system tray (a row of tray icons)
    GameModePanel.qml      the Game Mode confirmation prompt (in a DetailCard)
    NetworkPanel.qml       the merged Wi-Fi + LAN dialog's content
    Overview.qml           Alt+Tab expo: one mirrored workspace per column
    PolkitPanel.qml        the polkit authentication prompt (in the island)
    SessionPanel.qml       Lock / Suspend / Log Out / Reboot / Power Off
    ThemePanel.qml         theme picker
    VolumePanel.qml        the volume OSD, shown as the island
    WallpaperPanel.qml     wallpaper picker (Local + Wallhaven Browse sub-tabs)
    WallhavenBrowse.qml    Wallhaven search UI: filters, thumbnail grid, paging
  widgets/                 reusable small controls
    BluetoothDeviceRow.qml one Saved / Nearby device row in the Bluetooth dialog
    BrightnessDisplay.qml  one DDC/CI monitor (ddcutil get/set)
    SliderRow.qml          heading + icon + track + accent fill
    VerticalSlider.qml     the upright slider (tall Sound / Display slots)
    Switch.qml             small on/off pill
    IconButton.qml         square single-glyph control tile (Lock / DND)
    ToggleButton.qml       pill toggle
    WifiNetworkRow.qml     one Wi-Fi network row in the Network dialog
    TrayMenu.qml           Karu-styled menu for a system tray item (DBusMenu)
  media/
    MediaIsland.qml        round MPRIS companion; opens into a horizontal Now Playing panel
  settings/                 the standalone Settings app (SUPER + comma)
    SettingsWindow.qml     the floating window: sidebar + detail pane
    SettingsPanel.qml      the same UI hosted as an island panel (Docked mode)
    SettingsSidebar.qml    search box + category list
    SettingsPage.qml       renders a category (header card + section cards + rows)
    Catalog.js             the page model: every category and setting row
    ControlLayoutEditor.qml  drag-and-drop editor for the Control Center grid
    ControlPreviewTile.qml   one draggable/resizable control in that editor
    SettingSliderRow.qml   labelled slider with a "33 px" value
    SettingSwitchRow.qml   labelled on/off row
    SettingTextRow.qml     labelled text field
    SettingActionRow.qml   tappable action row
    SettingInfoRow.qml     read-only label/value row
    SettingThemePicker.qml theme swatch picker (Appearance)
    SettingAccentPicker.qml accent swatches / "Follow theme" (Appearance)
    SettingGameModeRow.qml live Game Mode switch (System)
  notifications/
    NotificationStack.qml  the banner stack that drops out of the island
    NotificationToast.qml  one notification banner card
  lock/
    LockContext.qml        shared lock state + PAM conversation
    Lockscreen.qml         macOS-style lock surface
    pam/password.conf      Quickshell-local PAM config (password only)
```

## Running

From the directory that *contains* `shell.qml`:

```sh
quickshell -c /path/to/karu
```

Or symlink it into your config dir and launch by name:

```sh
ln -s /path/to/karu ~/.config/quickshell/karu
quickshell -c karu
```

Quickshell hot-reloads on file changes, so you can tweak `Theme.qml` and watch it
update live.

## Command line (`karu`)

`bin/karu` is a small control script, symlinked to `~/.local/bin/karu` (already
on `PATH`), so from any terminal:

```sh
karu start            # start the shell (single instance, detached)
karu restart          # restart it
karu close            # stop it
karu launch themes    # open a panel: control | themes | wallpapers | session | launcher
karu toggle launcher  # toggle a panel open/closed
karu settings         # open/close the Settings app (also: `karu settings open|close`)
karu collapse         # collapse back to the pill
karu gamemode [on|off] # toggle the lightweight edge-to-edge Game Mode bar
karu overview         # toggle the Alt+Tab window overview (open|close to force)
karu lock             # lock the screen with the Karu lockscreen
karu unlock           # release the lock (emergency / scripting)
karu lockstate        # print locked/unlocked and whether it is secure
karu status           # print whether it is running
karu notify "T" "B"   # send a test notification (see Notifications below)
karu notify-demo      # send five notifications in a row to see them stack
```

`launch` starts the shell first if it is not already running. Commands reach the
live shell through Quickshell IPC — the `IpcHandler` in `shell.qml` maps the
friendly names onto the panels built by `PanelStack`. Override the config
directory or the Quickshell binary with `KARU_CONFIG` / `KARU_QS`.

## Settings

Karu ships a standalone **Settings app** in the style of macOS System Settings:
a floating window with a searchable category sidebar on the left and a detail
pane on the right, headed by a card showing the category's icon, title and
description.

- **Open it with `SUPER + comma`** (bound in `~/.config/hypr/configs/binds.lua`
  to `karu settings`), from the command line with `karu settings`, or with
  `karu settings open|close`. It is an ordinary floating window, so the
  compositor can move, focus and close it like any other; `Esc` and the window's
  × close it too. A Hyprland window rule (`windows.lua`) floats and centres it.
- **Docked mode** (**System ▸ Docked settings**) hosts the whole app *inside the
  island* instead of in a window. With it on, `SUPER + comma` / `karu settings`
  grows the island out of the pill exactly like the Control Center and shows the
  same searchable sidebar and pages, with the island's own fill, border, corner
  radius and open/close motion; clicking outside (or Esc) collapses it again. The
  floating window is not used while it is on, and flipping the switch hands the
  app over live between the two hosts.
- **Categories are grouped into sidebar sections**: **Appearance** (**Bar &
  Island**, **Appearance**, **Clock & Date**, **Motion**), **Features**
  (**Launcher**, **Notifications**, **Control Center**) and **System** (**Lock
  Screen**, **System**). The section order, labels and page membership live in
  `ui/settings/Catalog.js`, so the structure can be reshuffled in one place.
  Search across all pages from the sidebar; empty sections drop out of the list
  while a query is active.
- **Pages are responsive card grids.** Each page is split into labelled
  sub-sections, drawn as separate cards by `ui/settings/SettingsGroupCard.qml`.
  The pane packs them into **two columns** when it is wide enough (the floating
  window) and a **single column** when it is narrow (docked mode, or while
  searching). The theme and accent carousels and the Control Center layout
  editor are full-width. The sub-section labels and row order live in
  `ui/settings/Catalog.js`.
- **Handy extras** the app exposes beyond the main look-and-feel: pill and island
  padding (`collapsedPadding` / `panelPadding`), Control Center control height
  (`toggleHeight`), show the date in the bar (`barShowDate`), the gap between the
  bar and the first banner (`notificationTopGap`), the overview's preview width
  (`overviewMirrorWidth`) and the wallpaper folder (`wallpaperDir`).
- **Control Center** is a drag-and-drop layout editor rather than a list of
  rows. The expanded island is a grid (`Settings.controlColumns` columns of
  `Theme.toggleHeight` rows) and `Settings.controlLayout` is the ordered list of
  controls on it — each `{ type, col, row, w, h }`. The panel's own width is set
  by **Panel width** (`Settings.controlPanelWidth`, 320–760 px, default 420), so
  the Control Center can be widened independently of the shared *Expanded width*.
  Drag a tile to move it, pull
  its corner to resize, right-click for the sizes it supports, click the palette
  under **Add a control** to drop a new one in, and use the **Tidy / Undo /
  Reset** buttons (or the `4`–`9` chips for the grid width) to reorganise. With a
  control selected the arrow keys nudge it, `[` / `]` step through its sizes and
  Delete removes it. A **Sound or Display slider** resized taller than it is wide
  (e.g. a `1×3` slot, offered in the right-click size menu) becomes a **vertical**
  bar; wide slots keep the horizontal row. Edits are written straight to
  `Settings`, so the live panel re-lays-out as you work. The available controls
  (Wi-Fi, Bluetooth, Focus, Game Mode, Lock, Do Not Disturb, Sound, Display,
  Notifications, Now Playing, System Tray) and their default sizes live in
  `core/config/ControlCatalog.js`.
- **Every control is live.** The rows edit the `Settings` singleton
  (`core/config/Settings.qml`), and `Theme.qml` binds its sizes, radii, motion, fonts
  and clock tokens straight to it — so dragging *Bar height*, *Corner radius* or
  a motion duration re-themes the running shell as you move it. Toggles such as
  *Notch mode*, *Status icons*, *Media player*, *Album art circle* and *Do Not
  Disturb* take effect immediately.
- **Values persist** to `~/.config/karu/settings.json` (next to `shell.qml`) and
  are restored on the next launch; delete the file to return to the defaults.
  Every slider also carries a small **revert** button (an undo arrow) that
  appears beside its value as soon as it differs from the factory default and
  restores it with one click.

The pages and their rows are data-driven from
`ui/settings/Catalog.js`, so adding a setting is a matter of adding a
property to `Settings.qml`, binding it where it is used, and listing a row in
the catalog.

## Lockscreen

A macOS-style lock surface (`ui/lock/Lockscreen.qml`) implemented with
Quickshell's `WlSessionLock` (the `ext-session-lock-v1` protocol) and
`Quickshell.Services.Pam`. It shows a blurred + dimmed wallpaper, the localised
date and a large thin clock, the account avatar and name, and a rounded password
field. One surface is created per monitor; they share a single `LockContext`, so
the password typed on any screen is mirrored and one PAM conversation unlocks
them all.

The clock and login box animate. When the lock appears they fade and drift into
place — the clock first, the login cluster (avatar, name, pin box) a beat later —
while the wallpaper's blur and dim fade in beneath them. On a successful unlock
the same elements disperse (clock up, login down) and the wallpaper sharpens and
brightens back out before the session lock is released, so unlocking reads as a
transition rather than a cut to the desktop.

Engage it with any of:

- the Session panel's **Lock** button,
- `karu lock`,
- a Hyprland keybind containing `karu lock` (or a direct
  `qs ipc -p ~/.config/karu call karu lock`).

`karu unlock` releases it without a password (emergency / scripting), and
`karu lockstate` reports the current state.

Authentication uses `ui/lock/pam/password.conf`, read directly by Quickshell
(`configDirectory` is resolved relative to the config), so **nothing under
`/etc/pam.d` is touched**. It is password-only via `pam_unix`; add a
`pam_fprintd` line there for fingerprint support.

The lock is strictly opt-in: `locked` is never set at startup, so editing files
can never leave your session trapped behind a half-finished lock.

To iterate on the look without locking the session, run the preview:

```sh
KARU_LOCK_WALLPAPER=/path/to/wallpaper.png qs -p ~/.config/karu/lock-test.qml
```

That renders the identical `Lockscreen` in an ordinary floating window.

## Keyboard

While the island is expanded on the **Themes**, **Wallpapers** (Local tab),
**Apps**, **Session** or **Overview** panel it takes exclusive keyboard focus;
every other panel (and collapsing) hands the keyboard straight back to the
focused window. The Wallpapers panel only asks for the keyboard on its
keyboard-driven Local carousel — its Browse tab is click-only.

- **Themes** — ←/→ browse, Enter applies.
- **Wallpapers (Local)** — ←/→ (or the wheel) move the centred highlight, Enter
  applies; clicking a thumbnail highlights and sets it.
- **Apps** — the search field is focused the moment the tab opens, so you can
  type immediately; ↑/↓ move the selection, Enter launches, Esc clears the
  query (or closes when it is already empty).
- **Session** — ←/→ (or ↑/↓) move the highlight, Enter activates, Esc closes.
- **Overview** — Alt+Tab toggles it; Tab / Shift+Tab / ←→ move the highlight,
  Enter focuses the selected window, Esc or a click outside closes. Drag a card
  onto another workspace column to move that window there; middle-click a card
  to force-kill it.

## Game Mode

Game Mode is the lightweight profile: it turns the Dynamic Island into a plain,
**edge-to-edge top bar** and strips the shell of everything that costs a frame
while a game has the foreground.

- The collapsed island spans the full screen width with square corners, an
  opaque fill and no hover lift, so it reads as a conventional top bar
  (workspaces hard left, clock centred, status icons hard right). Expanding a
  panel still grows the normal centred card, so the Control Center stays
  reachable.
- Every shell animation is switched off: the shared motion tokens in
  `Theme.qml` (`motionSnap` / `motionFast` / `motionMedium` / `motionSlow` and
  their `expandDuration` / `fadeDuration` aliases) collapse to zero, hover
  scaling flattens, and the workspace indicator's travelling lens and urgent
  breathing snap instead of animating.
- The floating media companion is hidden.
- The Wallpapers panel drops its Wallhaven **Browse** sub-tab, so nothing hits
  the network or decodes remote thumbnails.

Toggle it from the Control Center's **Game Mode** tile — which opens a
confirmation card ("Enable Game Mode?") out of the tile, exactly like the
Bluetooth / Network / Display dialogs — or from the command line with
`karu gamemode` (`on` / `off` force the state, no argument toggles). The state
lives in the `GameMode` singleton (`core/theme/GameMode.qml`).

## Overview (Alt+Tab)

`ui/panels/Overview.qml` is a window switcher that is just another island
panel: opening it selects it and grows the island out of its pill exactly like
the Control Center (only wider — `Theme.overviewWidth` — so the workspaces fit),
and it shrinks back into the pill on close. It is drawn from
`Quickshell.Hyprland`: one column per workspace — ordered left-to-right by the
physical position of each workspace's monitor (and by workspace id within a
monitor), so the overview matches the way your screens sit on the desk — each a
**scaled mirror of that workspace**. The column body is the monitor drawn at its
true aspect ratio and every window is placed at its real position and size
(mapped from the toplevel's `lastIpcObject.at` / `.size` onto the monitor's
logical box), so two tiled windows appear side by side, a floating dialog sits
in the middle and a fullscreen window fills the screen — exactly the arrangement
on the workspace, rather than a stack of thumbnails. Window content is captured
per-toplevel with `ScreencopyView` (Hyprland exposes the toplevel-capture
protocols), so these are real **live** thumbnails. The focused card is ringed in
the accent colour; clicking a card focuses that window, its × closes it, and
**middle-clicking a card force-kills it**; the highlight follows Tab/arrows.
**Drag a card onto another workspace** and it is
moved there — the target column lights up as you hover it and the move is silent,
so your current workspace and focus are left alone.

Launch it with `karu overview` (toggle) or the `karu overview open|close` forms.
The intended binding is **Alt+Tab**, added to `~/.config/hypr/hyprland.lua`:

```lua
hl.bind("ALT + TAB", hl.dsp.exec_cmd("karu overview"))
```

The shell takes exclusive keyboard focus while the overview is open, so the same
Alt+Tab key reaches the shell and toggles it closed again — **Alt+Tab is a plain
toggle**: it opens and closes the overview and never cycles or switches windows.
(Run `hyprctl reload` after editing the bind.) It shows windows from every
monitor and workspace. Tune its look from the **Overview** block in `Theme.qml`.

## Restyling

Open **`core/theme/Theme.qml`** for the theme tokens, and **`core/config/Settings.qml`**
for the persisted user values they bind to (colors come from `Theme.qml` /
`Colors.qml`, sizes, radii, fonts and motion from `Settings.qml`).

- **Accent color** (selected workspace glow, active toggles, borders, active
  power button): `accent` (`#A8E6D8` by default).
- **Slider fill** (Sound / Display): `sliderAccent` (`#E8B4D0`).
- **Card shadow**: `shadowColor`, `shadowBlur`, `shadowBlurMax` — the drop
  shadow behind the tile-detail card (Bluetooth / Wi-Fi / Display / Game Mode),
  matching Hyprland's `decoration:shadow` (Hyprland can't shadow layer-shell
  surfaces, so `ui/bar/PanelShadow.qml` draws it). The islands themselves — the
  pill, an expanded panel and the Notch-mode slab — cast **no** shadow; with
  Panel blur the backdrop blur is what separates them from the desktop.
- **Panel blur** (frosted glass): `Settings.panelBlur` (Settings ▸ Appearance ▸
  Panel blur). When on, an *open* panel asks the compositor to blur what is
  behind it through the `ext-background-effect-v1` protocol (see the
  `BackgroundEffect` in `shell.qml`) and fades `Theme.panelGlassTop` →
  `Theme.panelGlassBottom` over it — a fully opaque band as tall as the
  collapsed island at the top, then transparent at the bottom, so the blurred
  desktop shows through below. Works with the
  standard floating panels *and* the Notch-mode slab (`NotchBar` carries the
  same gradient), but not the collapsed pill or the media island, and it is
  switched off under Game Mode. Your compositor must support
  `ext-background-effect-v1` and have its blur enabled (Hyprland 0.5x does).
  Tiles and cards reuse the same gradient (`Theme.tileGlassTop` →
  `Theme.tileGlassBottom`, painted by `ui/widgets/TileGlass.qml`) so they read
  as part of the same sheet; with Panel blur off their stops collapse to the
  flat `surface` fill.
- **Backgrounds / borders / text**: `background`, `surface`, `surfaceElevated`,
  `border`, `textPrimary`, `textSecondary`.
- **Shape & motion**: `radiusPanel`, `radiusCard`, `radiusInner`,
  `collapsedWidth`, `collapsedHeight`, `expandedWidth`.
  Animation timing lives in the **Motion** block: durations step up with the
  size of the change (`motionSnap`, `motionFast`, `motionMedium`, `motionSlow`)
  and the curves are shared as `easeOut` (settle), `easeEmphasized` (long
  glides) and `easeSpring` (+ `springOvershoot`, for grow/shrink). Components
  reference these instead of raw durations so the whole shell moves as one.
  In the Settings app these are not tuned one by one: **Motion ▸ Preset** offers
  a handful of named feels (`motionPreset` — Snappy, Balanced, Smooth, Bouncy),
  each bundling every timing value, with a live preview of the selected one. The
  individual values are still what the presets write (and what the shell reads),
  so hand-editing them in `settings.json` remains possible.
  `detailContentDelay` is the beat a tile dialog's contents wait out before
  fading in (see **Tile details** below).
- **Panel open & close (physics spring)**: the island does not expand on a
  fixed duration — it is driven by a real `SpringAnimation`, so it visibly
  overshoots its target and settles back. `panelSpring` is the stiffness
  (higher = faster and more energetic) and `panelDamping` how quickly it comes
  to rest (lower = bouncier); both are set by the chosen **Motion** preset
  and drive closing as well as opening. Game Mode / Reduce Motion
  disables the spring outright, so the size snaps.
- **Content reveal**: as a panel opens its rows do not simply appear — they
  cascade in, each fading and rising into place a beat after the one above, and
  the whole panel eases out of a slight zoom. It is tuned by `contentStagger`
  (the beat between rows), `contentRevealDelay` (the lead-in), `contentRise`
  (how far each row travels) and `contentScaleFrom` (the zoom) — all part of the
  chosen **Motion** preset. See `ui/widgets/ContentReveal.qml`.
- **Lockscreen motion**: `lockRevealDuration` (the entrance glide),
  `lockRevealStagger` (the beat before the login cluster follows the clock) and
  `lockLeaveDuration` (the dismissal the shell waits on before releasing the
  session lock).
- **Hover feedback**: `hoverScale` (how far the pill and media circle grow),
  `hoverBorder` / `hoverBorderWidth` (the accent edge) and `hoverSurface` (the
  fill lift). Set `hoverScale` to `1` for a flat, no-motion hover.
- **Workspaces always shown**: `persistentWorkspaces` (`[1, 2, 3, 4, 5]`).
  Add or remove ids here to change the fixed set. `dotCircle` / `dotCircleHover`
  and `dotWidth` set the capsule width (resting / hovered / focused),
  `dotHeightInactive` / `dotHeightHover` / `dotHeightActive` set their lengths,
  and the row stretches to the status icons' width (see `matchWidth` in
  `WorkspaceIndicator.qml`). The travelling lens's distance-scaled motion is
  tuned by `workspaceTravelBaseMs`,
  `workspaceTravelPerPx`, `workspaceTravelMaxMs`, `workspaceStretchRef` and
  `workspaceStretchMin`.
- **Monitor**: `barMonitor` (`"DP-1"`) pins the island to a specific output by
  its Wayland name (`DP-1`, `HDMI-A-1`, `eDP-1`, …). It re-binds on startup and
  on hotplug, falling back to the first screen while the named one is absent.
  Set to `""` to use the compositor default.
- **Icons / text**: `fontFamily` (SF Pro Display) and `iconFont`
  (Symbols Nerd Font).
- **Lockscreen font**: `lockFont` (`"SF Pro Display"`). A proportional sans so
  the big clock reads like macOS; set to `""` for the system default.
- **Notifications**: `notificationWidth` / `notificationMinHeight` size the
  banners, `notificationGap` spaces them, `notificationMaxVisible` caps the
  stack, `notificationTimeout` is the fallback lifetime (seconds) and
  `notificationMaxHistory` bounds the Control Center list.
- **Volume OSD**: `volumeOsdWidth` is the width of the short volume bar,
  `volumeOsdTimeout` is how long the island stays morphed into it (seconds) and
  `Settings.volumeOsd` turns the OSD off. It uses the island's normal corner
  radius, fill and shadow.

## How the expand/collapse works

See the big comment block in `shell.qml`. In short: `PanelWindow` holds a single
`Rectangle` (`island`) anchored to the top-centre. It is driven by one boolean —
`expanded` (the animated target size). Clicking the pill calls
`toggleExpanded()`, opening it on the Control Center; clicking it again (or the
top header band around the clock) collapses it, and a click on empty space below
that band is swallowed so a panel's body never closes it by accident. Width and height (and the
corner radii) ride a **physics spring**, so the pill springs open from its
centre-top with a lively overshoot and settles back; the panel's contents
cascade in behind it (see `ui/widgets/ContentReveal.qml`). Hovering never opens
it — it only makes the pill scale up slightly and brighten its border
(`Theme.hoverScale`).

The window spans the full screen width for reliable centring. At rest a `Region`
mask listing `island`, the media island and the notification stack makes only
those clickable, so the rest passes clicks through. While a panel or media card
is open the surface grows to cover the screen and the mask is dropped, so a click
on the backdrop outside the islands dismisses everything (`dismissAll()`). The
same backdrop is mirrored on every *other* output (a `Variants` over
`Quickshell.screens`), so a click on a second monitor dismisses an open panel
too; at rest those surfaces have an empty mask and pass clicks straight through.

## Control Center layout

The expanded Control Center is a grid rather than a fixed column. `Settings`
holds its width in cells (`controlColumns`, 4–9, default 7) and the ordered list
of controls (`controlLayout`), and `ui/panels/ControlCenterPanel.qml` renders one
live `ControlItem` per entry: Wi-Fi, Bluetooth, Focus (Do Not Disturb) and Game
Mode tiles; the small Lock and Do Not Disturb buttons; the Sound and Display
sliders (horizontal in a wide slot, vertical in a tall one); the notification
list (`ControlNotificationsCard`), which auto-grows its tile — and with it the
island — to show every tracked notification, capped to the screen, then scrolls
under its pinned header once it hits that cap; a System Tray
tile (`ControlTrayCard`) holding one clickable icon per StatusNotifierItem on the
session — left click activates, middle click secondary-activates, the wheel
scrolls the item and a right click (or a menu-only item's left click) opens its
own menu as a Karu-styled card (`TrayMenu`) that floats outside the island's
clip, with submenus, separators, check / radio state and disabled rows; the row
scrolls sideways when it outgrows its slot; and an
iOS-style Now Playing tile that adapts
to its grid slot — a one-row mini player, a narrow vertical stack, or the full
artwork / scrubber / transport card — with album art, elapsed / total time and
play / pause (and skip buttons when wide enough). Tapping anywhere but the
transport buttons opens the media companion; the buttons act in place. The
**Control Center** page of the Settings
app is a drag-and-drop editor for that list (see **Settings** above); it draws the
very same `ControlItem` (made non-interactive) at the panel's real width and row
height, so the preview is pixel-for-pixel the panel. Arranging controls there
re-lays-out the running panel immediately, and every edit is settled so controls
can never overlap — a control dropped onto others pushes them straight down. The
registry of control types, their icons and default sizes lives in
`core/config/ControlCatalog.js`; the editor is
`ui/settings/ControlLayoutEditor.qml` and each tile is a `ControlPreviewTile`.

## Tile details

The Bluetooth, Wi-Fi/LAN and Display tiles in the Control Center open a compact
dialog by **growing it straight out of the tile**. The tile hands
`ui/panels/DetailCard.qml` not just its screen rectangle but its own look
— its corner radius and its fill and border colours — so the card's very first
frame is a pixel-aligned copy of the tile (a tinted fill is flattened over the
island background first, so an active tile's translucent accent starts opaque).
It then morphs its position, size, radius and colour into the floating card on
the island's own physics spring, so the two move as one shape (with the same
overshoot on the way out).

The card stays fully **opaque for the whole trip** — opening and closing — and
only disappears once it has settled back onto the tile, so there is no
cross-fade and the tile never shows through a half-faded card. The tile it came
from is **suppressed** (hidden, keeping its slot so the grid never reflows) while
its card is open, so the card *replaces* the tile rather than floating off it and
leaving the tile behind; the tile returns as the card shrinks home. The dialog's
contents hold back for `Theme.detailContentDelay` before cascading in (the same
staggered reveal the panels use), so they are never clipped by the still-small
shape while it travels; on close they are dropped **instantly**, so no text
lingers over the shrinking surface and only the shape morphs back into the tile.
All three dialogs share this one component, so they move identically.

## Clock

`ui/bar/Clock.qml` is a **single shared clock** for the whole island, not one
per state. Collapsed, it sits centred in the pill at `Theme.clockSize`; opening
the **Control Center** glides it down into the header that panel reserves
(`Theme.clockHeaderHeight`), growing the time to `Theme.clockExpandedSize` and
unfolding the date (`Theme.clockDateSize`) beside it — so the clock visibly
morphs out of the main island into the control centre rather than cross-fading.
On any other panel (Themes, Wallpapers, Session, Apps, Overview) it fades out
with the rest of the bar content. It updates from a plain QML `Timer`, so it
needs no services.

## Status icons

The collapsed pill's right cluster (`ui/bar/StatusIcons.qml`) shows the
Wi-Fi, Bluetooth and volume glyphs; clicking anywhere on it opens the Control
Center. Like the clock it is a **single shared element** (`shell.qml`), not one
per state: at rest it hugs the pill's right edge, and opening the **Control
Center** glides it down into the same header the clock settles into, staying
vertically centred against it, so the cluster morphs out of the pill rather than
cross-fading. On any other panel it fades out with the rest of the bar content.
The volume glyph tracks the default PipeWire sink and can be nudged
directly: **scroll the wheel over it** to change the volume in 5% steps (wheel up
is louder, and raising it clears mute). The network glyph is still a static
placeholder. The Bluetooth glyph is too, except that while **Do Not Disturb** is
on it becomes a moon to show that banners are silenced.

## Volume OSD

Changing the default sink's volume or mute — from hardware/media keys, a keyboard
volume slider, the status-icon wheel, or any other client — makes the island
**morph into the volume panel** (`ui/panels/VolumePanel.qml`) exactly
like the Control Center or Session panels do: it grows out of the pill, shows a
speaker glyph, a filled track and the percentage (or **Muted**), holds for
`Theme.volumeOsdTimeout` (2 s), then collapses back into the pill. It is a
deliberately **short bar** — `Theme.volumeOsdWidth`, narrower than a normal
panel — so it reads as an OSD rather than a full dialog. The track is draggable,
so the OSD is usable directly as well. It is just another panel, so the island's
own grow/shrink motion, radius, fill and shadow carry it — nothing floats beside
or below the bar.

`shell.qml` watches `Pipewire.defaultAudioSink`, so the OSD reflects whatever
actually changed the sink and needs no keybind wiring of its own. A change is
ignored while another surface owns the island (an expanded panel, the media card,
the lock), so using the Control Center's own Sound slider never pops it; repeat
changes while the OSD is up simply restart its timer.

Tune it from **Settings ▸ Control Center ▸ Volume OSD** (`volumeOsd` to enable,
`volumeOsdWidth` for the bar's width and `volumeOsdTimeout` for how long it
stays).

## Media island

A second, smaller island (`ui/media/MediaIsland.qml`) sits just to the right
of the pill, vertically aligned with its top row. It mirrors the active MPRIS
player (`Quickshell.Services.Mpris`; whichever client is actually playing, or
the first one otherwise).

- **Collapsed** it is a circle showing the album art, or a music glyph when no
  player has a track.
- **On click** it morphs into a wide, horizontal "Now Playing" panel (384×216)
  that drops below the bar: square rounded artwork on the left; the title,
  artist, album and player stacked on the right; a draggable progress scrubber
  with elapsed / total times; and large previous / play-pause / next controls.
  The album art is a **single shared element** — it glides and resizes out of
  the circle into the panel's artwork slot (and back on close) instead of
  cross-fading, so the cover morphs in one continuous motion. Seeking writes
  `player.position`; unavailable actions are dimmed. The card is a solid panel
  (the cover is not used as a backdrop), framed by a 2px frosted rim
  (`Theme.borderMedia`) with the theme's panel corner radius. Clicking it again
  (or any non-control part of the panel) closes it. Hovering only scales the
  circle up slightly.

It is positioned relative to the main island's rendered right edge (`x` tracks
`island.width` *and* the pill's live hover scale), so the pair stays attached
through the card's own expand/collapse animation and keeps a constant gap while
the pill scales up on hover instead of growing into the companion. `shell.qml` sizes its surface to whichever island reaches furthest
down while at rest, and to the full screen while a panel or card is open. With
no MPRIS client running it simply stays a dimmed circle whose card reads
"Nothing Playing". It can be hidden entirely from **Settings ▸ Bar & Island ▸
Media player**.

## Wallpapers

The **Wallpapers** panel (`ui/panels/WallpaperPanel.qml`) has two
sub-tabs, switched from the header:

- **Local** — a centred carousel of the images in the configured folder
  (`/home/jakob/Bilder/wallpapers` by default, `$KARU_WALLPAPER_DIR`, or the path
  set in **Settings ▸ Appearance ▸ Wallpaper**, scanned by `Wallpaper.qml` and
  rescanned live when that setting changes). The highlighted wallpaper sits in
  the middle at its full
  width with an accent border, while the ones either side are narrower and
  squeeze into their visible slice as they slide off the panel. ←/→ (or the
  wheel) move the highlight and the row glides to centre it, Enter applies, and
  clicking a thumbnail highlights and sets it. If the dynamic Wallpaper theme is
  active the island re-colours itself from the new image. The catalogue is
  rescanned whenever the panel opens, so images added while the shell runs show
  up without a restart.
- **Browse** — a [Wallhaven](https://wallhaven.cc/help/api) search. Filter by
  **Category** (General / Anime / People), **Purity** (SFW / Sketchy / NSFW) and
  a sort mode (Top / New / Random / Views / Favorites, with a 1d…1y range for
  Top), page through the results, and click a thumbnail to download the full
  image into the local folder and apply it. The image lands as
  `wallhaven-<id>.<ext>` and is selected as soon as the download finishes.

Requests go through `curl` (see `core/services/Wallhaven.qml`), so no extra QML
module is needed. Wallhaven returns **Sketchy** and **NSFW** results only for
requests carrying an API key; export one and the shell picks it up:

```sh
KARU_WALLHAVEN_API_KEY=your_key_here karu restart
```

Without a key those two chips are dimmed, and selecting one reports that a key
is required instead of querying.

## Notifications

A single `NotificationServer` (`Notifications.qml`) owns the freedesktop
notification DBus name, so notifications from every app arrive in the shell. New
ones appear as **banners that drop out of the island** — a vertical stack under
the pill, newest on top, each sliding down into place while the ones below glide
out of the way. The stack is capped (`Theme.notificationMaxVisible`, 4 by
default): the oldest banner is pushed out but stays in the history. Banners
auto-dismiss after the app's timeout (or `Theme.notificationTimeout`, 5 s) —
except resident and **critical** ones, which stay until dismissed. Clicking a
banner, or its ×, dismisses the notification. Dismissal is animated: a leaving
banner fades, shrinks and collapses its height while the ones below glide up to
close the gap (the stack has no positioner `remove` transition, so each toast
plays its own exit and is dropped once it has finished).

The **Control Center**'s Notifications card lists **every** tracked notification
from the same store, newest first, with a **Clear all** action. The tile grows to
fit the whole list and the island grows with it, then shrinks back to the grid
slot the layout gave the control as notifications are dismissed — so the card
always expands to exactly what it holds, stopping at the screen edge (older,
overflowing rows are clipped). Clicking a row dismisses it, and a row can be
dragged sideways to throw it away (past a third of the width it flies off and is
dismissed, otherwise it springs back). As you drag, the row squashes vertically
and the rows below glide up to close the gap it leaves, then settle back with a
spring.
The **Do not Disturb** toggle silences banners only — the notification is still
recorded in the history. Banners are hidden while the island is expanded or the
media card is open, and reappear when it collapses.

### Testing notifications

The shell must be running (it owns the notification name). Then:

```sh
karu notify "Build finished" "All tests green"   # one notification
karu notify-demo                                 # five, half a second apart
```

or use `notify-send` directly:

```sh
notify-send "Hello" "from notify-send"
notify-send -u critical "Disk almost full" "This one stays until dismissed"
```

If nothing appears, another notification daemon (dunst, mako, swaync, …) is
probably already holding `org.freedesktop.Notifications`; stop it so Karu's
server can take over. Check the current owner with:

```sh
gdbus call --session --dest org.freedesktop.DBus \
  --object-path /org/freedesktop/DBus \
  --method org.freedesktop.DBus.GetNameOwner org.freedesktop.Notifications
```

## Polkit authentication

When an application asks polkit to authorize a privileged action, Karu answers
the prompt itself instead of spawning a separate agent window. A `PolkitAgent`
in `core/services/Polkit.qml` registers the shell as the session's
`org.freedesktop.PolicyKit1.AuthenticationAgent`; when a request arrives the
main island **grows into the authentication card** (the `polkit` panel,
`ui/panels/PolkitPanel.qml`) — same fill, border, corner radius, fonts
and accent as every other panel, so the prompt reads as part of the island
rather than a floating window. It shows the action's message and action id, the
password field (with the prompt polkit supplies), an error line on a failed
attempt, and **Cancel** / **Authenticate** buttons; Enter submits and Esc
cancels. While a request is pending the island is held open — clicking outside,
the media companion and click-to-collapse are all suppressed.

Because Karu is the agent, no other authentication agent
(`hyprpolkitagent`, `polkit-gnome`, …) may be running for the session, or the
two will race for the DBus name.

## Brightness (DDC/CI)

The Control Center's **Display** slider drives every DDC/CI monitor through
`ddcutil` (`core/services/Brightness.qml` + `ui/widgets/BrightnessDisplay.qml`). Dragging it
moves all screens together; the **chevron** on the row opens a Display dialog
(the same morphing card as Bluetooth) with one slider per monitor, so each
screen can be set independently.

Target selection is automatic. To pin it, set `KARU_DDC_BUS` (I2C bus number) or
`KARU_DDC_CONNECTOR` (a DRM connector suffix such as `DP-1`) in the shell's
environment. `ddcutil` needs read/write access to `/dev/i2c-*`; if the Display
slider is inert, the dialog says so — add your user to the `i2c` group or ship a
udev rule (Fedora's `ddcutil` package already tags NVIDIA/VGA buses with
`uaccess`).

## Wiring real functionality later

Search for `// TODO:` throughout. The main hooks are:

| Feature              | Where                          | Status / source |
| -------------------- | ------------------------------ | --------------- |
| Network (Wi-Fi + LAN) | `ToggleButton`, `NetworkPanel` | **done** — live `Quickshell.Networking` |
| Bluetooth            | `ToggleButton`, `BluetoothPanel` | **done** — live `Quickshell.Bluetooth` |
| Volume / Brightness  | `SliderRow`, `Brightness`      | **done** — live Pipewire / ddcutil (per-monitor + synced) |
| Workspaces           | `WorkspaceIndicator`           | **done** — live `Quickshell.Hyprland` |
| Overview / Alt+Tab   | `Overview.qml`                 | **done** — live `Quickshell.Hyprland` + `ScreencopyView` |
| Media player         | `MediaIsland`                  | **done** — live `Quickshell.Services.Mpris` |
| Lock screen          | `Lockscreen`, `LockContext`    | **done** — `WlSessionLock` + PAM |
| Notifications        | `Notifications.qml`, `NotificationStack` | **done** — live `Quickshell.Services.Notifications` |
| System tray          | `ControlTrayCard.qml`          | **done** — live `Quickshell.Services.SystemTray` (activate / menu / scroll) |
| Polkit auth          | `Polkit.qml`, `PolkitPanel`    | **done** — live `Quickshell.Services.Polkit` (island prompt) |
| Wallpapers           | `WallpaperPanel`, `Wallpaper.qml` | **done** — awww / swww / hyprpaper / swaybg / wbg |
| Wallhaven browse     | `WallhavenBrowse.qml`, `Wallhaven.qml` | **done** — live Wallhaven API (curl) |
| Themes               | `ThemePanel`, `Themes.qml`     | **done** — Matugen |
| Settings app         | `SettingsWindow`, `Settings.qml`, `Catalog.js` | **done** — live + persisted (`SUPER + comma`) |
| Power actions        | `SessionPanel`                 | **done** — `uwsm stop` / `systemctl` |
