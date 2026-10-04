#!/usr/bin/env bash
# Re-snapshot the CURRENT desktop into ./files, so the bundle matches whatever
# you have tweaked since. Run this before you switch away.
#
# Only captures what is OURS to publish. Third-party assets (widgets, icons,
# WhiteSur, fonts) and the copyrighted Nothing wallpapers are deliberately left
# out - fetch.sh pulls those from source. See CREDITS.md.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DST="$HERE/files"
GRN=$'\e[32m'; YEL=$'\e[33m'; BLD=$'\e[1m'; OFF=$'\e[0m'
say()  { printf '%s>>%s %s\n' "$BLD" "$OFF" "$*"; }
ok()   { printf '   %s+%s %s\n' "$GRN" "$OFF" "$*"; }
warn() { printf '   %s!%s %s\n' "$YEL" "$OFF" "$*"; }

if [ "${1:-}" != "--yes" ]; then
  read -rp "Overwrite the bundle in $DST with your current setup? [y/N] " r
  [[ "$r" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }
fi

rm -rf "$DST"
mkdir -p "$DST/home/.config" "$DST/home/.local/share" \
         "$DST/overlays/WhiteSur-dark/widgets" \
         "$DST/root/etc/sddm.conf.d" "$DST/root/usr/share/sddm/themes"

# --- config ---------------------------------------------------------------
# per-app rc files are NOT bundled: they carry recent-file history, and
# restore.sh merges the ColorScheme key in with kwriteconfig6 instead.
say "Config"
for f in kdeglobals kwinrc plasmarc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc konsolerc \
         kscreenlockerrc; do
  [ -f "$HOME/.config/$f" ] && cp "$HOME/.config/$f" "$DST/home/.config/"
done
for d in kitty fastfetch; do
  [ -d "$HOME/.config/$d" ] && mkdir -p "$DST/home/.config/$d" \
    && cp "$HOME/.config/$d"/* "$DST/home/.config/$d/" 2>/dev/null
done
for d in gtk-3.0 gtk-4.0; do
  [ -d "$HOME/.config/$d" ] || continue
  mkdir -p "$DST/home/.config/$d"
  for f in settings.ini colors.css gtk.css; do
    [ -f "$HOME/.config/$d/$f" ] && cp "$HOME/.config/$d/$f" "$DST/home/.config/$d/"
  done
done
# Plasma 6 keeps the ACTIVE colour scheme / style pointers here, not in
# ~/.config/kdeglobals - kreadconfig6 finds them via the config cascade.
if [ -d "$HOME/.config/kdedefaults" ]; then
  mkdir -p "$DST/home/.config/kdedefaults"
  cp "$HOME/.config/kdedefaults"/* "$DST/home/.config/kdedefaults/" 2>/dev/null
fi
ok "$(find "$DST/home/.config" -type f | wc -l) files"

# --- our themes only ------------------------------------------------------
say "Our themes"
S="$HOME/.local/share"; D="$DST/home/.local/share"
mkdir -p "$D/color-schemes" "$D/aurorae/themes" "$D/konsole"
# only the schemes we authored - not Otto / WhiteSur*, which ship with others
for c in NothingDark NothingVSCode; do
  [ -f "$S/color-schemes/$c.colors" ] && cp "$S/color-schemes/$c.colors" "$D/color-schemes/"
done
cp -r "$S/aurorae/themes/NothingDots" "$D/aurorae/themes/" 2>/dev/null
rm -f "$D/aurorae/themes/NothingDots"/*.bak
cp "$S/konsole/NothingDark."* "$D/konsole/" 2>/dev/null
ok "$(ls "$D/color-schemes" | wc -l) colour schemes, Nothing Dots, Konsole profile"

# --- the one patched third-party file we overlay --------------------------
TS="$S/plasma/desktoptheme/WhiteSur-dark/widgets/tasks.svgz"
if [ -f "$TS" ]; then
  cp "$TS" "$DST/overlays/WhiteSur-dark/widgets/"
  ok "dock-indicator overlay"
else
  warn "WhiteSur-dark not installed - overlay not captured"
fi

# our slideshow patch for the Nothing photo frame
PW="$HOME/.local/share/plasma/plasmoids/com.jaxparrow07.nothingkdewidgets.photo"
if grep -q FolderListModel "$PW/contents/ui/main.qml" 2>/dev/null; then
  mkdir -p "$DST/overlays/photo-widget/contents/ui/config" \
           "$DST/overlays/photo-widget/contents/config"
  cp "$PW/contents/ui/main.qml"            "$DST/overlays/photo-widget/contents/ui/"
  cp "$PW/contents/config/main.xml"        "$DST/overlays/photo-widget/contents/config/"
  cp "$PW/contents/ui/config/ConfigImage.qml" "$DST/overlays/photo-widget/contents/ui/config/"
  ok "photo-frame slideshow patch"
else
  warn "photo frame is unpatched - slideshow overlay not captured"
fi

# --- login screen (without the wallpaper-derived background) --------------
say "Login screen"
if [ -d /usr/share/sddm/themes/NothingLogin ]; then
  cp -r /usr/share/sddm/themes/NothingLogin "$DST/root/usr/share/sddm/themes/"
  # background.png is generated from the Nothing wallpaper: copyrighted, never shipped
  rm -f "$DST/root/usr/share/sddm/themes/NothingLogin/background.png"
  ok "sddm theme (background excluded by design)"
fi
cp /etc/sddm.conf.d/10-nothing.conf "$DST/root/etc/sddm.conf.d/" 2>/dev/null && ok "sddm config"

# --- manifest -------------------------------------------------------------
RES="$(kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' \
      | grep -oP 'Geometry:\s*[0-9]+,[0-9]+\s+\K[0-9]+x[0-9]+' | head -1)"
cat > "$DST/MANIFEST" <<EOF
ORIGIN_HOME=$HOME
ORIGIN_USER=$USER
ORIGIN_RES=${RES:-unknown}
ORIGIN_DATE=$(date -Iseconds)
PLASMA=$(plasmashell --version 2>/dev/null | awk '{print $2}')
EOF

# --- guards ---------------------------------------------------------------
if [ -n "${SUDO_PASS:-}" ] && grep -rqF "$SUDO_PASS" "$DST" 2>/dev/null; then
  echo "!! a secret was found in the bundle - removing those files" >&2
  grep -rlF "$SUDO_PASS" "$DST" 2>/dev/null | tee /dev/stderr | xargs -r rm -f
fi
BIG="$(find "$DST" -type f -size +2M 2>/dev/null)"
[ -n "$BIG" ] && { warn "unexpectedly large files - check these are yours to publish:"; echo "$BIG" | sed 's/^/     /'; }

echo
echo "${GRN}${BLD}Bundle updated${OFF} - $(du -sh "$DST" | cut -f1)"
