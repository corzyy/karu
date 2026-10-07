change readme
A top-centre **Dynamic Island** bar for [Quickshell](https://quickshell.outfoxxed.me/)
(QML / Qt 6 / Wayland layer-shell). A small rounded pill expands on click into a
full control centre.

## Install

Fedora installer (dependencies, shell, Hyprland config and matugen themes) —
see [`Installer/`](Installer/README.md):

```sh
tmp="$(mktemp -d)" \
  && curl -fsSL https://github.com/corzyy/karu/archive/refs/heads/main.tar.gz | tar -xz -C "$tmp" \
  && "$tmp/karu-main/Installer/install.sh"
```