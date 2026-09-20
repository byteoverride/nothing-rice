#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Restore the "Nothing OS" KDE Plasma 6 setup.
#
#   ./restore.sh              interactive
#   ./restore.sh --yes        no prompts
#   ./restore.sh --no-sddm    skip the login screen (avoids needing sudo)
#   ./restore.sh --no-pkgs    skip apt installs
#
# Everything is bundled in ./files - nothing is downloaded, so this keeps
# working even after the KDE Store links rot.
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/files"
STAMP="$(date +%Y%m%d-%H%M%S)"
ROLLBACK="$HOME/.nothing-rice-rollback/$STAMP"

ASSUME_YES=0; DO_SDDM=1; DO_PKGS=1
for a in "$@"; do
  case "$a" in
    --yes|-y)   ASSUME_YES=1 ;;
    --no-sddm)  DO_SDDM=0 ;;
    --no-pkgs)  DO_PKGS=0 ;;
    -h|--help)  sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; DIM=$'\e[90m'; BLD=$'\e[1m'; OFF=$'\e[0m'
say()  { printf '%s>>%s %s\n' "$BLD" "$OFF" "$*"; }
ok()   { printf '   %s+%s %s\n' "$GRN" "$OFF" "$*"; }
warn() { printf '   %s!%s %s\n' "$YEL" "$OFF" "$*"; }
die()  { printf '%s!! %s%s\n' "$RED" "$*" "$OFF" >&2; exit 1; }

# --- preflight -------------------------------------------------------------
[ -d "$SRC" ] || die "bundle not found at $SRC"
[ "$(id -u)" -ne 0 ] || die "run as your normal user, not root (sudo is used only where needed)"
# shellcheck disable=SC1091
. "$SRC/MANIFEST"

command -v plasmashell >/dev/null || die "plasmashell not found - is KDE Plasma installed?"
CUR_PLASMA="$(plasmashell --version 2>/dev/null | awk '{print $2}')"
case "$CUR_PLASMA" in
  6.*) ;;
  *) warn "bundle was made on Plasma $PLASMA, you are on ${CUR_PLASMA:-unknown} - proceeding anyway" ;;
esac

CUR_RES="$(kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -oP 'Geometry:\s*[0-9]+,[0-9]+\s+\K[0-9]+x[0-9]+' | head -1)"

cat <<EOF

${BLD}Nothing OS - Plasma restore${OFF}
  bundle built : $ORIGIN_DATE  (Plasma $PLASMA, user $ORIGIN_USER)
  restoring to : $HOME  (user $USER)
  rollback to  : $ROLLBACK
  login screen : $([ $DO_SDDM -eq 1 ] && echo "yes (needs sudo)" || echo "skipped")
  packages     : $([ $DO_PKGS -eq 1 ] && echo "yes (needs sudo)" || echo "skipped")

This overwrites your panels, widgets, colours, fonts and window decoration.
Your current setup is copied to the rollback path first.

EOF
# the third-party half lives outside this repo - fetch.sh installs it
MISSING_DEPS=()
[ -d "$HOME/.local/share/plasma/desktoptheme/WhiteSur-dark" ] || MISSING_DEPS+=("WhiteSur Plasma style")
[ -d "$HOME/.local/share/icons/YAMIS" ]                      || MISSING_DEPS+=("YAMIS icons")
[ -d "$HOME/.local/share/plasma/plasmoids/com.pras.syspeek" ] || MISSING_DEPS+=("Plasma widgets")
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
  echo "${YEL}Missing third-party pieces:${OFF}"
  for m in "${MISSING_DEPS[@]}"; do echo "   - $m"; done
  echo "Run ${BLD}./fetch.sh${OFF} first (they are not bundled - see CREDITS.md)."
  echo
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  read -rp "Proceed? [y/N] " r; [[ "$r" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }
fi

# --- 1. rollback snapshot --------------------------------------------------
say "Snapshotting current setup"
mkdir -p "$ROLLBACK/.config" "$ROLLBACK/.local/share"
for f in kdeglobals kwinrc plasmarc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc konsolerc \
         dolphinrc katerc arkrc gwenviewrc okularrc spectaclerc systemsettingsrc kcalcrc; do
  [ -f "$HOME/.config/$f" ] && cp -a "$HOME/.config/$f" "$ROLLBACK/.config/" 2>/dev/null
done
for d in kitty fastfetch gtk-3.0 gtk-4.0; do
  [ -d "$HOME/.config/$d" ] && cp -a "$HOME/.config/$d" "$ROLLBACK/.config/" 2>/dev/null
done
for d in color-schemes konsole aurorae; do
  [ -d "$HOME/.local/share/$d" ] && cp -a "$HOME/.local/share/$d" "$ROLLBACK/.local/share/" 2>/dev/null
done
ok "rollback saved to $ROLLBACK"

# --- 2. packages -----------------------------------------------------------
if [ "$DO_PKGS" -eq 1 ]; then
  say "Installing packages"
  MISSING=()
  command -v kitty     >/dev/null || MISSING+=(kitty)
  command -v fastfetch >/dev/null || MISSING+=(fastfetch)
  fc-list 2>/dev/null | grep -qi 'jetbrains mono' || MISSING+=(fonts-jetbrains-mono)
  if [ ${#MISSING[@]} -gt 0 ]; then
    if command -v apt-get >/dev/null; then
      sudo apt-get install -y "${MISSING[@]}" || warn "apt failed - install manually: ${MISSING[*]}"
    else
      warn "not a Debian/Ubuntu system - install manually: ${MISSING[*]}"
    fi
  else
    ok "all present"
  fi
fi

# --- 3. user files ---------------------------------------------------------
say "Restoring config"
mkdir -p "$HOME/.config" "$HOME/.local/share"
cp -a "$SRC/home/.config/." "$HOME/.config/"
ok "config files"

say "Restoring our themes"
S="$SRC/home/.local/share"; D="$HOME/.local/share"
mkdir -p "$D/color-schemes" "$D/aurorae/themes" "$D/konsole"
cp -a "$S/color-schemes/."  "$D/color-schemes/"  2>/dev/null
cp -a "$S/aurorae/themes/." "$D/aurorae/themes/" 2>/dev/null
cp -a "$S/konsole/."        "$D/konsole/"        2>/dev/null
ok "colour schemes, Nothing Dots decoration, Konsole profile"

# our patched dock indicators sit on top of the fetched WhiteSur style
TSVG="$D/plasma/desktoptheme/WhiteSur-dark/widgets/tasks.svgz"
if [ -d "$(dirname "$TSVG")" ]; then
  cp -a "$SRC/overlays/WhiteSur-dark/widgets/tasks.svgz" "$TSVG" && ok "red dock indicators overlaid"
fi

# absolute paths baked into the panel config (wallpaper etc.)
if [ "$ORIGIN_HOME" != "$HOME" ]; then
  say "Rewriting paths: $ORIGIN_HOME -> $HOME"
  grep -rlF "$ORIGIN_HOME" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
       "$HOME/.config/kitty" "$HOME/.config/fastfetch" 2>/dev/null \
    | while read -r f; do sed -i "s|$ORIGIN_HOME|$HOME|g" "$f"; done
  ok "paths rewritten"
fi

fc-cache -f >/dev/null 2>&1 && ok "font cache rebuilt"

# per-app colour pins: merged in, so we never clobber an app's own settings
say "Pinning app colour schemes"
for rc in dolphinrc katerc arkrc gwenviewrc okularrc spectaclerc systemsettingsrc \
          kcalcrc kwriterc kinforc filelightrc partitionmanagerrc; do
  kwriteconfig6 --file "$rc" --group UiSettings --key ColorScheme NothingVSCode 2>/dev/null
done
kwriteconfig6 --file konsolerc --group UiSettings --key ColorScheme NothingDark 2>/dev/null
ok "12 KDE apps -> NothingVSCode, Konsole -> NothingDark"


# --- 4. login screen -------------------------------------------------------
if [ "$DO_SDDM" -eq 1 ] && [ -d "$SRC/root/usr/share/sddm/themes/NothingLogin" ]; then
  say "Restoring SDDM login theme (sudo)"
  if sudo -v 2>/dev/null; then
    sudo rm -rf /usr/share/sddm/themes/NothingLogin
    sudo cp -r "$SRC/root/usr/share/sddm/themes/NothingLogin" /usr/share/sddm/themes/
    sudo chown -R root:root /usr/share/sddm/themes/NothingLogin
    sudo chmod -R a+rX      /usr/share/sddm/themes/NothingLogin
    sudo mkdir -p /etc/sddm.conf.d
    sudo cp "$SRC/root/etc/sddm.conf.d/10-nothing.conf" /etc/sddm.conf.d/
    sudo chmod 644 /etc/sddm.conf.d/10-nothing.conf
    ok "login theme installed"
  else
    warn "no sudo - skipped. Re-run later or use --no-sddm"
  fi
fi

# --- 5. apply --------------------------------------------------------------
say "Applying"
plasma-apply-colorscheme  NothingDark   >/dev/null 2>&1 && ok "colour scheme: NothingDark"
plasma-apply-desktoptheme WhiteSur-dark >/dev/null 2>&1 && ok "plasma style: WhiteSur-dark"

# window decoration: custom monochrome Aurorae
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library "org.kde.kwin.aurorae"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme   "__aurorae__svg__NothingDots"
ok "decoration: Nothing Dots"

# KZones snap layouts (installed by fetch.sh; layouts ride along in kwinrc)
if [ -d "$HOME/.local/share/kwin/scripts/kzones" ]; then
  kwriteconfig6 --file kwinrc --group Plugins --key kzonesEnabled true
  ok "KZones enabled"
else
  warn "KZones not installed - run ./fetch.sh for snap layouts"
fi

# Plasma caches theme SVGs hard - the red dock indicators need these gone
rm -f  "$HOME"/.cache/plasma-svgelements* "$HOME"/.cache/plasma_theme_*.kcache 2>/dev/null
rm -rf "$HOME"/.cache/ksvg-elements       "$HOME"/.cache/plasmashell/qmlcache  2>/dev/null
ok "theme caches cleared"

qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 \
  || qdbus org.kde.KWin /KWin reconfigure >/dev/null 2>&1
ok "kwin reloaded"

say "Restarting plasmashell"
kquitapp6 plasmashell >/dev/null 2>&1 || systemctl --user stop plasma-plasmashell >/dev/null 2>&1
sleep 3
(setsid plasmashell >/dev/null 2>&1 &)
sleep 8
pgrep -x plasmashell >/dev/null && ok "plasmashell up" || warn "plasmashell did not start - run it manually"

# --- done ------------------------------------------------------------------
cat <<EOF

${GRN}${BLD}Done.${OFF}

${DIM}Notes${OFF}
  * Log out and back in for GTK apps, the login screen and any running
    app to pick everything up.
  * Desktop widget positions are saved for a ${BLD}$ORIGIN_RES${OFF} logical screen.
EOF
if [ -n "${CUR_RES:-}" ] && [ "$CUR_RES" != "$ORIGIN_RES" ]; then
cat <<EOF
    ${YEL}This screen is $CUR_RES${OFF} - the widget column will land in the
    wrong place. Drag them, or ask for the grid to be recomputed.
EOF
fi
cat <<EOF
  * Konsole is pinned to the near-black scheme; other KDE apps use the
    VS Code grey. Both are in System Settings > Colours.
  * To undo: ${BLD}$HERE/rollback.sh $STAMP${OFF}

EOF
