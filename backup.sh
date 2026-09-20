#!/usr/bin/env bash
# Re-snapshot the CURRENT desktop into ./files, so the bundle matches
# whatever you have tweaked since. Run this before you switch away.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DST="$HERE/files"
BLD=$'\e[1m'; GRN=$'\e[32m'; OFF=$'\e[0m'
say() { printf '%s>>%s %s\n' "$BLD" "$OFF" "$*"; }
ok()  { printf '   %s+%s %s\n' "$GRN" "$OFF" "$*"; }

read -rp "Overwrite the bundle in $DST with your current setup? [y/N] " r
[[ "$r" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }

rm -rf "$DST"
mkdir -p "$DST/home/.config" "$DST/home/.local/share" \
         "$DST/root/etc/sddm.conf.d" "$DST/root/usr/share/sddm/themes"

say "Config"
# NOTE: per-app rc files are deliberately NOT bundled - they carry recent-file
# history. restore.sh merges the ColorScheme key in with kwriteconfig6 instead.
for f in kdeglobals kwinrc plasmarc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc konsolerc; do
  [ -f "$HOME/.config/$f" ] && cp "$HOME/.config/$f" "$DST/home/.config/"
done
for d in kitty fastfetch; do
  [ -d "$HOME/.config/$d" ] && mkdir -p "$DST/home/.config/$d" && cp "$HOME/.config/$d"/* "$DST/home/.config/$d/" 2>/dev/null
done
for d in gtk-3.0 gtk-4.0; do
  [ -d "$HOME/.config/$d" ] || continue
  mkdir -p "$DST/home/.config/$d"
  for f in settings.ini colors.css gtk.css; do
    [ -f "$HOME/.config/$d/$f" ] && cp "$HOME/.config/$d/$f" "$DST/home/.config/$d/"
  done
done
ok "$(find "$DST/home/.config" -type f | wc -l) files"

say "Themes, widgets, fonts"
S="$HOME/.local/share"; D="$DST/home/.local/share"
mkdir -p "$D/aurorae/themes" "$D/plasma/desktoptheme" "$D/wallpapers"
cp -r "$S/color-schemes"                  "$D/"                      2>/dev/null
cp -r "$S/konsole"                        "$D/"                      2>/dev/null
cp -r "$S/icons/YAMIS"                    "$D/icons_YAMIS"           2>/dev/null
cp -r "$S/fonts/JetBrainsMonoNerd"        "$D/fonts_JetBrainsMonoNerd" 2>/dev/null
cp -r "$S/aurorae/themes/NothingDots"     "$D/aurorae/themes/"       2>/dev/null
cp -r "$S/plasma/desktoptheme/WhiteSur-dark" "$D/plasma/desktoptheme/" 2>/dev/null
cp -r "$S/plasma/plasmoids"               "$D/plasma/"               2>/dev/null
for w in Nothing1 Nothing2 Nothing3; do cp -r "$S/wallpapers/$w" "$D/wallpapers/" 2>/dev/null; done
ok "$(ls "$D/plasma/plasmoids" 2>/dev/null | wc -l) widgets"

say "Login screen"
cp -r /usr/share/sddm/themes/NothingLogin "$DST/root/usr/share/sddm/themes/" 2>/dev/null && ok "sddm theme"
cp /etc/sddm.conf.d/10-nothing.conf       "$DST/root/etc/sddm.conf.d/"       2>/dev/null && ok "sddm config"

RES="$(kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -oP 'Geometry:\s*[0-9]+,[0-9]+\s+\K[0-9]+x[0-9]+' | head -1)"
cat > "$DST/MANIFEST" <<EOF
ORIGIN_HOME=$HOME
ORIGIN_USER=$USER
ORIGIN_RES=${RES:-unknown}
ORIGIN_DATE=$(date -Iseconds)
PLASMA=$(plasmashell --version 2>/dev/null | awk '{print $2}')
EOF

# safety: never let a secret into the bundle
if [ -n "${SUDO_PASS:-}" ] && grep -rqF "$SUDO_PASS" "$DST" 2>/dev/null; then
  echo "!! a secret was found in the bundle - removing those files" >&2
  grep -rlF "$SUDO_PASS" "$DST" 2>/dev/null | tee /dev/stderr | xargs -r rm -f
fi

echo
echo "${GRN}${BLD}Bundle updated${OFF} - $(du -sh "$DST" | cut -f1)"
