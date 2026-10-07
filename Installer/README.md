# Karu Installer

A small, dependency-free installer for **Karu** (the Quickshell "Dynamic Island")
and the **Hyprland + matugen** desktop it was built for. It is a pure-bash
true-colour TUI styled after the shell itself — no `dialog`, `whiptail` or `gum`.

```
Installer/
├── install.sh              entry point / TUI flow
├── lib/
│   ├── ui.sh               ANSI TUI toolkit (palette, menus, spinners)
│   ├── env.sh              OS detection, paths, sudo handling
│   ├── packages.sh         Fedora packages + COPR repositories
│   └── files.sh            deployment of shell / hypr / matugen / fonts
├── hypr/                   bundled snapshot of ~/.config/hypr
└── matugen/                bundled snapshot of ~/.config/matugen
```

## Usage

### Quick install (curl)

The installer needs its `lib/` scripts and bundled configs, so it downloads the
repository and runs the TUI from the checkout. Run this **directly** (not
piped to `bash`) so it keeps the terminal for the TUI:

```sh
tmp="$(mktemp -d)" \
  && curl -fsSL https://github.com/corzyy/karu/archive/refs/heads/main.tar.gz | tar -xz -C "$tmp" \
  && "$tmp/karu-main/Installer/install.sh"
```

Add `--yes` after `install.sh` for an unattended run.

### From a checkout

```sh
./install.sh            # interactive TUI
./install.sh --yes      # unattended, installs everything to the defaults
./install.sh --help
```

Run it as your normal user (it uses `sudo` for the package step). Existing
`~/.config/karu`, `~/.config/hypr` and `~/.config/matugen` are moved aside to
`…bak.<timestamp>` before anything is written.

## What it does

| Component    | Action                                                                 |
|--------------|------------------------------------------------------------------------|
| Dependencies | `dnf` + COPR `lionheartp/Hyprland`: quickshell, hyprland, matugen, awww, ddcutil, brightnessctl, playerctl, hyprshot, pipewire, curl |
| Nerd Font    | Symbols Nerd Font (COPR `che/nerd-fonts`) for the status/lock glyphs    |
| Karu shell   | Installs to `~/.config/karu`, links the `karu` driver into `~/.local/bin` |
| Hyprland     | Installs the bundled Lua config to `~/.config/hypr`                     |
| matugen      | Installs `config.toml`, templates and post-hooks to `~/.config/matugen` |
| SF Pro       | Copied from `~/Downloads` into `~/.local/share/fonts` if present        |

### Notes

* **SF Pro Display** is proprietary and cannot be bundled. If it is missing the
  shell falls back to the system font; drop the OTFs into
  `~/.local/share/fonts` and run `fc-cache -f` to get the intended look.
* Keybind applications (terminal, file manager, browser) are **not** installed,
  but the bundled Hyprland binds already reference them.
* The bundled configs are templated on install: the author's hard-coded
  `/home/jakob` paths are rewritten to the installing user's `$HOME`.
* The install log is written to a temp file; its path is printed at the end and
  on any failure.
