#!/usr/bin/bash
# Her icon set (her build brief, "Icons"): Slot-Dark-Icons by L4ki, from github.com/L4ki/Slot-Plasma-Themes,
# folder "Slot Icons Themes/Slot-Dark-Icons". Licence: GPL-3.0 (the repository's LICENSE, shipped beside the icons).
# Fetched at build time from ONE pinned commit, checked against its sha256, so this public repo stays small and holds
# none of the icons. Changes made: none to the icons themselves; only this one theme is taken from the repository, and
# its icon lookup cache is rebuilt for this image. Written to /usr/share/icons/Slot-Dark-Icons/ with LICENSE and
# TAYLOR-OS-NOTE.txt (where it came from, what was changed).
set -euo pipefail
COMMIT=e0f0d69ef253cbc971dd0b1f4315b08a4b7a5ed1     # 2026-11-06, the repository's newest commit on 2026-11-21
SHA256=95d53442366501e10c893ab98fed705401c3e1c601ffc8a81a9027abfa7a6c54
URL="https://github.com/L4ki/Slot-Plasma-Themes/archive/$COMMIT.tar.gz"
DEST=/usr/share/icons/Slot-Dark-Icons
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -fsSL --retry 5 --retry-delay 10 -o "$work/slot.tar.gz" "$URL"
echo "$SHA256  $work/slot.tar.gz" | sha256sum -c -
top="Slot-Plasma-Themes-$COMMIT"
tar -xzf "$work/slot.tar.gz" -C "$work" "$top/LICENSE" "$top/Slot Icons Themes/Slot-Dark-Icons"
rm -rf "$DEST"
mv "$work/$top/Slot Icons Themes/Slot-Dark-Icons" "$DEST"
cp "$work/$top/LICENSE" "$DEST/LICENSE"
cat > "$DEST/TAYLOR-OS-NOTE.txt" <<NOTE
Slot-Dark-Icons, by L4ki: https://github.com/L4ki/Slot-Plasma-Themes
Taken from commit $COMMIT, folder "Slot Icons Themes/Slot-Dark-Icons" (also offered at https://store.kde.org/p/2234808).
Licensed under the GNU General Public License, version 3 (LICENSE in this folder). The source is the repository above.
Changes made for TAYLOR OS: none to the icons. Only this theme was taken from the repository, and its icon-theme.cache
was rebuilt with gtk-update-icon-cache when the TAYLOR OS image was built.
NOTE
chmod -R u=rwX,go=rX "$DEST"
if command -v gtk-update-icon-cache >/dev/null; then gtk-update-icon-cache -f -q "$DEST" || true; fi
# the checks: the theme and the icons the desktop uses are there
test -f "$DEST/index.theme" && test -f "$DEST/LICENSE"
for f in apps/48/firefox.svg apps/48/microsoft-edge.svg apps/48/google-chrome.svg apps/48/steam.svg apps/48/Battle.net.svg \
         apps/48/spotify.svg apps/48/kitty.svg apps/48/system-file-manager.svg apps/48/preferences-system.svg \
         apps/48/multimedia-volume-control.svg status/22/network-wireless-signal-excellent.svg status/22/audio-volume-high.svg; do
    test -s "$DEST/$f" || { echo "missing from the icon set: $f"; exit 1; }
done
echo "Slot-Dark-Icons: $(find "$DEST" -type f | wc -l) files, $(du -sh "$DEST" | cut -f1)"
