#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Download the third-party pieces this setup sits on top of.
#
# They are NOT bundled in this repo - they belong to their authors, and the
# Nothing wallpapers are copyrighted artwork. This pulls them from source.
# Run once, before ./restore.sh.
#
#   ./fetch.sh                everything
#   ./fetch.sh --no-font      skip the 78MB Nerd Font
#   ./fetch.sh --no-wallpaper skip the wallpapers
# ---------------------------------------------------------------------------
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d /tmp/nothing-fetch.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

DO_FONT=1; DO_WALL=1
for a in "$@"; do case "$a" in
  --no-font) DO_FONT=0 ;;
  --no-wallpaper) DO_WALL=0 ;;
  -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
  *) echo "unknown option: $a" >&2; exit 2 ;;
esac; done

GRN=$'\e[32m'; YEL=$'\e[33m'; BLD=$'\e[1m'; OFF=$'\e[0m'
say()  { printf '%s>>%s %s\n' "$BLD" "$OFF" "$*"; }
ok()   { printf '   %s+%s %s\n' "$GRN" "$OFF" "$*"; }
warn() { printf '   %s!%s %s\n' "$YEL" "$OFF" "$*"; }

for c in curl kpackagetool6; do command -v $c >/dev/null || { echo "need $c"; exit 1; }; done

OCS="https://api.kde-look.org/ocs/v1/content/data"
dl_url() { curl -sS --max-time 30 "$OCS/$1" | grep -oP '(?<=<downloadlink1>)[^<]+' | head -1; }

# --- 1. Plasma widgets -----------------------------------------------------
# plugin id -> store content id
WIDGETS="
com.pras.syspeek:2304482
com.jaxparrow07.nothingkdewidgets.digitalclock:2330436
com.jaxparrow07.nothingkdewidgets.analogclock:2330402
com.jaxparrow07.nothingkdewidgets.date:2330435
com.jaxparrow07.nothingkdewidgets.media:2330420
com.jaxparrow07.nothingkdewidgets.battery:2330427
com.jaxparrow07.nothingkdewidgets.weather:2330433
com.jaxparrow07.nothingkdewidgets.worldclock:2330432
com.jaxparrow07.nothingkdewidgets.photo:2330428
org.omar.nothingisland:2369621
com.jaxparrow07.macoswidgets.clock-square:2362930
com.jaxparrow07.macoswidgets.music:2362920
com.jaxparrow07.macoswidgets.calendar:2362937
com.jaxparrow07.macoswidgets.timer:2362934
com.jaxparrow07.macoswidgets.weather:2362933
com.github.boraerciyas.controlcentre:2138485
org.kde.plasma.codesnippets:2333778
desktopnotification:2364808
"
say "Plasma widgets"
OK=0; FAIL=0
for entry in $WIDGETS; do
  plug="${entry%%:*}"; id="${entry##*:}"
  if [ -d "$HOME/.local/share/plasma/plasmoids/$plug" ]; then
    printf '   %s=%s %s (already installed)\n' "$GRN" "$OFF" "$plug"; OK=$((OK+1)); continue
  fi
  url="$(dl_url "$id")"
  if [ -z "$url" ]; then warn "$plug - no download link (store id $id)"; FAIL=$((FAIL+1)); continue; fi
  f="$WORK/$(basename "${url%%\?*}")"
  curl -sSL --max-time 180 -o "$f" "$url" 2>/dev/null
  if kpackagetool6 -t Plasma/Applet -i "$f" >/dev/null 2>&1; then
    ok "$plug"; OK=$((OK+1))
  else
    warn "$plug - install failed"; FAIL=$((FAIL+1))
  fi
done
echo "   $OK ok, $FAIL failed"

# --- 2. Icons --------------------------------------------------------------
say "YAMIS icon theme"
if [ -d "$HOME/.local/share/icons/YAMIS" ]; then ok "already installed"; else
  url="$(dl_url 2303161)"
  if [ -n "$url" ]; then
    curl -sSL --max-time 300 -o "$WORK/yamis.tar.gz" "$url"
    mkdir -p "$HOME/.local/share/icons"
    tar xzf "$WORK/yamis.tar.gz" -C "$HOME/.local/share/icons/" && ok "installed"
  else warn "could not resolve download link"; fi
fi

# --- 3. WhiteSur Plasma style + Aurorae ------------------------------------
say "WhiteSur (Plasma style, Aurorae, SDDM base)"
if command -v git >/dev/null; then
  if git clone --depth 1 -q https://github.com/vinceliuice/WhiteSur-kde.git "$WORK/WhiteSur-kde" 2>/dev/null; then
    ( cd "$WORK/WhiteSur-kde" && bash install.sh -c dark >/dev/null 2>&1 ) && ok "installed (dark)"
    # our patched dock indicators go on top of the freshly installed theme
    if [ -f "$HERE/files/overlays/WhiteSur-dark/widgets/tasks.svgz" ]; then
      cp "$HERE/files/overlays/WhiteSur-dark/widgets/tasks.svgz" \
         "$HOME/.local/share/plasma/desktoptheme/WhiteSur-dark/widgets/tasks.svgz" \
        && ok "red dock indicators overlaid"
    fi
  else warn "clone failed - install WhiteSur-kde manually"; fi
else warn "git not installed"; fi

# --- 3b. KZones (Windows-11-style snap layouts) ----------------------------
say "KZones window-snapping script"
if [ -d "$HOME/.local/share/kwin/scripts/kzones" ]; then ok "already installed"; else
  url="$(dl_url 1909220)"
  if [ -n "$url" ]; then
    f="$WORK/kzones.kwinscript"
    curl -sSL --max-time 180 -o "$f" "$url" 2>/dev/null
    kpackagetool6 -t KWin/Script -i "$f" >/dev/null 2>&1 && ok "installed" \
      || warn "install failed - get it from store.kde.org/p/1909220"
  else warn "could not resolve download link"; fi
fi

# --- 4. JetBrains Mono Nerd Font -------------------------------------------
if [ "$DO_FONT" -eq 1 ]; then
  say "JetBrainsMono Nerd Font (~78MB)"
  if fc-list 2>/dev/null | grep -qi 'JetBrainsMono Nerd'; then ok "already installed"; else
    mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerd"
    if curl -sSL --max-time 900 -o "$WORK/JetBrainsMono.zip" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip; then
      unzip -oq "$WORK/JetBrainsMono.zip" -d "$HOME/.local/share/fonts/JetBrainsMonoNerd" \
        'JetBrainsMonoNerdFont-*.ttf' 'JetBrainsMonoNLNerdFont-*.ttf' 2>/dev/null
      fc-cache -f >/dev/null 2>&1; ok "installed"
    else warn "download failed"; fi
  fi
fi

# --- 5. Wallpapers (copyright: Nothing Technology Ltd) ---------------------
if [ "$DO_WALL" -eq 1 ]; then
  say "Nothing wallpapers"
  mkdir -p "$HOME/.local/share/wallpapers"
  for id in 2116657 2116658 2116659; do
    url="$(dl_url "$id")"; [ -z "$url" ] && { warn "id $id unavailable"; continue; }
    f="$WORK/$(basename "${url%%\?*}")"
    curl -sSL --max-time 240 -o "$f" "$url" 2>/dev/null
    tar xf "$f" -C "$HOME/.local/share/wallpapers/" 2>/dev/null && ok "$(basename "${f%%.tar*}")"
  done
  # the SDDM login background is derived from the desktop wallpaper
  WP="$(find "$HOME/.local/share/wallpapers/Nothing1" -name '*.png' -o -name '*.jpg' 2>/dev/null | head -1)"
  if [ -n "$WP" ] && command -v magick >/dev/null; then
    RES="$(kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' \
          | grep -oP 'Geometry:\s*[0-9]+,[0-9]+\s+\K[0-9]+x[0-9]+' | head -1)"
    RES="${RES:-2880x1800}"
    magick "$WP" -resize "${RES}^" -gravity center -extent "$RES" -quality 92 \
      "$WORK/background.png" 2>/dev/null \
      && sudo cp "$WORK/background.png" /usr/share/sddm/themes/NothingLogin/background.png 2>/dev/null \
      && ok "SDDM login background generated at $RES"
  fi
fi

echo
echo "${GRN}${BLD}Done.${OFF} Now run: ${BLD}./restore.sh${OFF}"
