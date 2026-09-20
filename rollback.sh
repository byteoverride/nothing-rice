#!/usr/bin/env bash
# Undo a restore.sh run by putting back the snapshot it took first.
#   ./rollback.sh              use the most recent snapshot
#   ./rollback.sh 20260920-105500   use a specific one
#   ./rollback.sh --list       show what is available
set -uo pipefail

BASE="$HOME/.nothing-rice-rollback"
BLD=$'\e[1m'; GRN=$'\e[32m'; YEL=$'\e[33m'; OFF=$'\e[0m'
say()  { printf '%s>>%s %s\n' "$BLD" "$OFF" "$*"; }
ok()   { printf '   %s+%s %s\n' "$GRN" "$OFF" "$*"; }
warn() { printf '   %s!%s %s\n' "$YEL" "$OFF" "$*"; }

[ -d "$BASE" ] || { echo "no snapshots in $BASE"; exit 1; }

if [ "${1:-}" = "--list" ]; then
  say "Snapshots"
  for d in "$BASE"/*/; do
    [ -d "$d" ] || continue
    printf '   %s  (%s)\n' "$(basename "$d")" "$(du -sh "$d" 2>/dev/null | cut -f1)"
  done
  exit 0
fi

STAMP="${1:-$(ls -1 "$BASE" | sort | tail -1)}"
SNAP="$BASE/$STAMP"
[ -d "$SNAP" ] || { echo "no such snapshot: $STAMP"; echo "try: $0 --list"; exit 1; }

echo
echo "${BLD}Rolling back to $STAMP${OFF}"
echo "  from: $SNAP"
echo
read -rp "Proceed? [y/N] " r; [[ "$r" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }

say "Restoring files"
[ -d "$SNAP/.config" ]      && cp -a "$SNAP/.config/."      "$HOME/.config/"      && ok "config"
[ -d "$SNAP/.local/share" ] && cp -a "$SNAP/.local/share/." "$HOME/.local/share/" && ok "local/share"

say "Reapplying"
SCHEME="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
[ -n "$SCHEME" ] && plasma-apply-colorscheme "$SCHEME" >/dev/null 2>&1 && ok "colour scheme: $SCHEME"
THEME="$(kreadconfig6 --file plasmarc --group Theme --key name 2>/dev/null)"
[ -n "$THEME" ] && plasma-apply-desktoptheme "$THEME" >/dev/null 2>&1 && ok "plasma style: $THEME"

rm -f  "$HOME"/.cache/plasma-svgelements* "$HOME"/.cache/plasma_theme_*.kcache 2>/dev/null
rm -rf "$HOME"/.cache/ksvg-elements 2>/dev/null
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || qdbus org.kde.KWin /KWin reconfigure >/dev/null 2>&1

say "Restarting plasmashell"
kquitapp6 plasmashell >/dev/null 2>&1 || systemctl --user stop plasma-plasmashell >/dev/null 2>&1
sleep 3
(setsid plasmashell >/dev/null 2>&1 &)
sleep 8
pgrep -x plasmashell >/dev/null && ok "plasmashell up" || warn "start plasmashell manually"

echo
echo "${GRN}${BLD}Rolled back.${OFF}  Log out and back in for GTK apps and the login screen."
echo "Note: the SDDM login theme is system-wide and is NOT rolled back."
echo "      To drop it:  sudo rm /etc/sddm.conf.d/10-nothing.conf"
echo
