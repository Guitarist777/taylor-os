#!/usr/bin/env bash
# Her window buttons' plugin (hyprbars: minimise, full screen, close; her pick 2026-11-23), built in its own plain Fedora
# 45 stage of the image build (2026-11-26), against the same Hyprland the image installs. hyprbars-install.sh then puts
# the finished package into the image, only if it was built for the Hyprland there.
#
# Why: Hyprland only loads a plugin built against itself. On 2026-11-25 the sdegler/hyprland COPR rebuilt Hyprland and its
# family on a new hyprgraphics but not the plugin (no title bars in the virtual PC, run 45709330733), and pinning the old
# set broke that night when the COPR deleted the old libraries (build run 45752251318). Why a separate stage: Hyprland's
# developer files need Fedora's mesa developer package, which Bazzite's own mesa blocks (build run 45754308614); the
# plugin itself does not use mesa (it needs Hyprland, hyprutils and GLES only). Nothing of the build reaches her image
# but the one package.
set -euo pipefail

SRC_URL="https://download.copr.fedorainfracloud.org/results/sdegler/hyprland/srpm-builds/11336655/hyprland-plugins-0.57.0-1.src.rpm"
SRC_SHA256="0548c9d18485c8c46280f11eb0c7c58184a93244c6340cd536c9d57a9ab32b99"
TOP=/tmp/hyprbars-build
OUT=/out

mkdir -p "$TOP" "$OUT"
dnf5 -y install dnf5-plugins rpm-build
dnf5 -y copr enable sdegler/hyprland
dnf5 -y install hyprland
echo "hyprbars: building against $(rpm -q hyprland)"
curl -fsSL --retry 3 -o "$TOP/src.rpm" "$SRC_URL"
echo "$SRC_SHA256  $TOP/src.rpm" | sha256sum -c -
rpm -i --define "_topdir $TOP" "$TOP/src.rpm"
dnf5 -y builddep "$TOP/SPECS/hyprland-plugins.spec"
[ "$(rpm -q --qf '%{VERSION}-%{RELEASE}' hyprland-devel)" = "$(rpm -q --qf '%{VERSION}-%{RELEASE}' hyprland)" ] \
  || { echo "hyprbars: hyprland-devel $(rpm -q hyprland-devel) does not match $(rpm -q hyprland)"; exit 1; }
rpmbuild --define "_topdir $TOP" --define "dist .fc45.taylor" -bb "$TOP/SPECS/hyprland-plugins.spec"
cp "$TOP"/RPMS/x86_64/hyprland-plugin-hyprbars-[0-9]*.taylor.x86_64.rpm "$OUT/"
rpm -q --qf '%{VERSION}-%{RELEASE}\n' hyprland > "$OUT/built-against.txt"
ls -la "$OUT"
echo "hyprbars: built for $(cat "$OUT/built-against.txt")"
