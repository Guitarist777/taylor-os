#!/usr/bin/env bash
# Her icon set (her build brief, "Icons" and "Source for the icons"): Slot-Dark-Icons by l4k1, from
# https://github.com/L4ki/Slot-Plasma-Themes at a pinned commit, installed under its real theme name with the
# author's GPL-3.0 licence and credit beside it. Used by the KDE look (and anything else that asks for the theme).
# Skipped if another step of the build already put the same theme in.
set -euo pipefail
COMMIT=e0f0d69ef253cbc971dd0b1f4315b08a4b7a5ed1
DEST=/usr/share/icons/Slot-Dark-Icons
if [ -f "$DEST/index.theme" ]; then echo "Slot-Dark-Icons already in the image"; exit 0; fi
tmp=$(mktemp -d)
curl -fsSL --retry 3 -o "$tmp/slot.tar.gz" "https://codeload.github.com/L4ki/Slot-Plasma-Themes/tar.gz/$COMMIT"
top="Slot-Plasma-Themes-$COMMIT"
tar -xzf "$tmp/slot.tar.gz" -C "$tmp" "$top/Slot Icons Themes/Slot-Dark-Icons" "$top/LICENSE"
mv "$tmp/$top/Slot Icons Themes/Slot-Dark-Icons" "$DEST"
cp "$tmp/$top/LICENSE" "$DEST/LICENSE"
cat > "$DEST/CREDIT.txt" <<EOT
Slot-Dark-Icons by l4k1, from Slot Plasma Themes: https://github.com/L4ki/Slot-Plasma-Themes
(commit $COMMIT), under the GNU General Public License version 3 (LICENSE). Not changed.
EOT
grep -q '^Name=Slot-Dark-Icons' "$DEST/index.theme"
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -q "$DEST" || true
rm -rf "$tmp"
echo "Slot-Dark-Icons installed: $(find "$DEST" -type f | wc -l) files"
