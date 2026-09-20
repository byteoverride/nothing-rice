# Credits and licensing

This repo contains **only the work that is mine to publish**. Everything else is
downloaded from source by `./fetch.sh`, because it belongs to its authors - and
in one case is copyrighted artwork that must not be redistributed at all.

## In this repo

| Component | Licence | Note |
|---|---|---|
| `restore.sh`, `fetch.sh`, `backup.sh`, `rollback.sh` | GPL-3.0 | |
| `NothingDark.colors`, `NothingVSCode.colors` | GPL-3.0 | original |
| Konsole profile + colour scheme | GPL-3.0 | original |
| kitty / fastfetch configs, dot-matrix logo | GPL-3.0 | original |
| **Nothing Dots** Aurorae decoration | GPL-3.0 | **derived from WhiteSur-kde** |
| **NothingLogin** SDDM theme | GPL-3.0 | **derived from WhiteSur-kde** |
| `overlays/.../tasks.svgz` | GPL-3.0 | **modified from WhiteSur-kde** |

The repo is GPL-3.0 because three of those are derivative works of
[WhiteSur-kde](https://github.com/vinceliuice/WhiteSur-kde) by **vinceliuice**,
which is GPL-3.0. Copyleft carries over - that is not optional.

What was changed in each derivative:

- **Nothing Dots** - WhiteSur-dark Aurorae with the button SVGs recoloured
  (close `#e9524a`→`#d71921`, minimise `#f1ae1b`→`#9a9a9a`,
  maximise/restore `#59c837`→`#9a9a9a`) and the titlebar gradient darkened to
  near-black.
- **NothingLogin** - WhiteSur 6.2 SDDM theme with `Input.qml` restyled to a dark
  pill with a red focus ring, and `theme.conf` retargeted to JetBrains Mono.
- **tasks.svgz** - `normal-*` and `minimized-*` groups switched from
  `ColorScheme-Text` to `ColorScheme-NegativeText` so background and minimised
  apps show a red dock indicator.

## Fetched by `fetch.sh`, not bundled

**Plasma widgets** - installed from the KDE Store:

| Author | Widgets | Licence |
|---|---|---|
| **jaxparrow07** | Nothing OS set (clock, analog clock, date, media, battery, weather, world clock, photo frame) and macOS Liquid Glass set (clock, music, calendar, timer, weather) | GPL-2.0+ / GPL-3.0 |
| **PRAS Samin** | SysPeek | GPL-2.0+ |
| **omar** | Nothing Dynamic Island | MIT |
| **boraerciyas** | Control Centre 6 | GPLv3 |
| - | Code Snippet Holder | GPL-2.0+ |
| - | Desktop Notification | MIT |

**KWin scripts**

- **KZones** by *gerritdevriese* - GPL-3.0 - snap layouts
  (<https://github.com/gerritdevriese/kzones>)

**Other**

- **YAMIS** (Yet Another Monochrome Icon Set) by *dirn* - KDE Store
- **WhiteSur-kde** by *vinceliuice* - GPL-3.0 - Plasma style, Aurorae and the
  SDDM theme this one is built on
- **JetBrains Mono Nerd Font** - SIL OFL-1.1 (JetBrains + Nerd Fonts patch)

## Wallpapers - not redistributed

The **Nothing** wallpapers are artwork owned by **Nothing Technology Limited**.
They are not in this repo and never will be. `fetch.sh` downloads them from the
KDE Store, and the SDDM login background is generated locally from the
downloaded file at your own screen resolution.

If you are outside the terms Nothing publishes them under, substitute any
wallpaper you like - nothing in the setup depends on that specific image.

## If you are one of the authors above

and would rather not be listed, or want the attribution worded differently,
open an issue and it will be changed.
