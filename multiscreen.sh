#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Clone the top bar and dock onto every attached screen.
#
# Plasma panels belong to ONE screen. Plug in a second monitor and it gets an
# empty desktop with no panels, which is why the setup "disappears" there.
# This mirrors screen 0's panels onto any screen that has none.
#
#   ./multiscreen.sh            mirror onto all screens missing panels
#   ./multiscreen.sh --list     show screens and which have panels
#   ./multiscreen.sh --clean    remove panels from screens other than 0
#
# Run it after connecting a monitor. Plasma does not do this automatically.
# ---------------------------------------------------------------------------
set -uo pipefail

GRN=$'\e[32m'; YEL=$'\e[33m'; BLD=$'\e[1m'; OFF=$'\e[0m'
say()  { printf '%s>>%s %s\n' "$BLD" "$OFF" "$*"; }
ok()   { printf '   %s+%s %s\n' "$GRN" "$OFF" "$*"; }
warn() { printf '   %s!%s %s\n' "$YEL" "$OFF" "$*"; }

QD=$(command -v qdbus6 || command -v qdbus) || { echo "need qdbus"; exit 1; }
ps_eval() { "$QD" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1" 2>&1; }

case "${1:-}" in
  -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
  --list)
    ps_eval '
      print("screens attached: " + screenCount);
      var have = {};
      panels().forEach(function (p) { have[p.screen] = (have[p.screen] || 0) + 1; });
      for (var s = 0; s < screenCount; s++) {
        var g = screenGeometry(s);
        print("  screen " + s + "  " + g.width + "x" + g.height +
              "  panels: " + (have[s] || 0));
      }
      panels().forEach(function (p) {
        print("    " + p.location + " on screen " + p.screen +
              " (" + p.widgetIds.length + " widgets)");
      });'
    exit 0 ;;
  --clean)
    say "Removing panels from secondary screens"
    ps_eval '
      var n = 0;
      panels().forEach(function (p) { if (p.screen > 0) { p.remove(); n++; } });
      print("removed " + n);'
    exit 0 ;;
  "") ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

say "Mirroring panels onto secondary screens"
ps_eval '
// --- read the reference layout off screen 0 -----------------------------
var ref = { top: null, dock: null };
panels().forEach(function (p) {
    if (p.screen !== 0) return;
    if (p.location === "top")    ref.top  = p;
    if (p.location === "bottom") ref.dock = p;
});
if (!ref.top && !ref.dock) { print("ERROR: no panels on screen 0 to copy"); }

function widgetTypes(panel) {
    var out = [];
    panel.widgetIds.forEach(function (i) { out.push(panel.widgetById(i).type); });
    return out;
}
function launchersOf(panel) {
    var L = "";
    panel.widgetIds.forEach(function (i) {
        var w = panel.widgetById(i);
        if (w.type === "org.kde.plasma.icontasks") {
            w.currentConfigGroup = ["General"];
            L = w.readConfig("launchers");
        }
    });
    return L;
}

var topTypes  = ref.top  ? widgetTypes(ref.top)  : [];
var dockTypes = ref.dock ? widgetTypes(ref.dock) : [];
var dockLaunchers = ref.dock ? launchersOf(ref.dock) : "";

// --- which screens already have panels ----------------------------------
var have = {};
panels().forEach(function (p) { have[p.screen] = true; });

var made = 0;
for (var s = 1; s < screenCount; s++) {
    if (have[s]) { print("screen " + s + ": already has panels, skipped"); continue; }

    if (ref.top) {
        var t = new Panel;
        t.location   = "top";
        t.screen     = s;
        t.height     = ref.top.height;
        t.lengthMode = "fill";
        t.floating   = false;
        t.hiding     = "none";
        topTypes.forEach(function (ty) {
            var w = t.addWidget(ty);
            if (ty === "org.kde.plasma.panelspacer") {
                w.currentConfigGroup = ["General"];
                w.writeConfig("expanding", "true");
            }
        });
        if (t.screen === s) { made++; print("screen " + s + ": top bar created"); }
        else { t.remove(); print("screen " + s + ": top bar REJECTED (screen came back " + t.screen + ")"); }
    }

    if (ref.dock) {
        var d = new Panel;
        d.location   = "bottom";
        d.screen     = s;
        d.height     = ref.dock.height;
        d.lengthMode = ref.dock.lengthMode;
        d.alignment  = "center";
        d.floating   = true;
        d.hiding     = ref.dock.hiding;
        dockTypes.forEach(function (ty) {
            var w = d.addWidget(ty);
            if (ty === "org.kde.plasma.icontasks" && dockLaunchers) {
                w.currentConfigGroup = ["General"];
                w.writeConfig("launchers", dockLaunchers);
                w.writeConfig("showOnlyCurrentScreen", "false");
                w.writeConfig("groupingStrategy", "1");
                w.writeConfig("maxStripes", "1");
            }
        });
        if (d.screen === s) { made++; print("screen " + s + ": dock created"); }
        else { d.remove(); print("screen " + s + ": dock REJECTED (screen came back " + d.screen + ")"); }
    }
}

if (screenCount < 2) print("only " + screenCount + " screen attached - nothing to mirror");
print("PANELS_CREATED:" + made);
'

echo
ok "done - run './multiscreen.sh --list' to check, or '--clean' to undo"
