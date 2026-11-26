#!/usr/bin/env bash
# Her window buttons (the hyprbars title bar: minimise, full screen, close; her pick 2026-11-23), built HERE against the
# exact Hyprland going into this image (2026-11-26).
#
# Why: Hyprland only loads a plugin built against itself. On 2026-11-25 the sdegler/hyprland COPR rebuilt Hyprland and its
# family on a new hyprgraphics but not the plugin, and Hyprland then loaded no plugin (virtual PC run 45709330733: no title
# bars, no buttons). Pinning the old set stopped working the same night: the COPR deleted the old hyprgraphics and
# hyprtoolkit builds, so nothing could install it (build run 45752251318). Hyprland's own advice for plugins is to build
# them against the Hyprland you run; this does that at image build time, from the COPR's own source package for the
# plugins (pinned by its sha256), so the plugin and Hyprland can never drift apart again.
#
# The rebuilt package is marked ".taylor" in its release, and the build stops unless that one is what is installed.
# The compiler and build tools are removed again afterwards.
set -euo pipefail

SRC_URL="https://download.copr.fedorainfracloud.org/results/sdegler/hyprland/srpm-builds/11336655/hyprland-plugins-0.57.0-1.src.rpm"
SRC_SHA256="0548c9d18485c8c46280f11eb0c7c58184a93244c6340cd536c9d57a9ab32b99"
TOP=/tmp/hyprbars-build

echo "hyprbars: building against $(rpm -q hyprland)"
rm -rf "$TOP"; mkdir -p "$TOP"
rpm -qa --qf '%{NAME}\n' | sort -u > "$TOP/before.txt"

curl -fsSL --retry 3 -o "$TOP/src.rpm" "$SRC_URL"
echo "$SRC_SHA256  $TOP/src.rpm" | sha256sum -c -
rpm -i --define "_topdir $TOP" "$TOP/src.rpm"

# the COPR for hyprland-devel (the same repo the dnf module used), only for this build
dnf5 -y install rpm-build dnf5-plugins
dnf5 -y copr enable sdegler/hyprland
dnf5 -y builddep "$TOP/SPECS/hyprland-plugins.spec"
# hyprland-devel must be the Hyprland that is installed, release and all
[ "$(rpm -q --qf '%{VERSION}-%{RELEASE}' hyprland-devel)" = "$(rpm -q --qf '%{VERSION}-%{RELEASE}' hyprland)" ] \
  || { echo "hyprbars: hyprland-devel $(rpm -q hyprland-devel) does not match $(rpm -q hyprland)"; exit 1; }

rpmbuild --define "_topdir $TOP" --define "dist .fc45.taylor" -bb "$TOP/SPECS/hyprland-plugins.spec"
pkg=$(ls "$TOP"/RPMS/x86_64/hyprland-plugin-hyprbars-[0-9]*.taylor.x86_64.rpm | head -1)
# built just now from the checksummed source, so it carries no signature: Fedora 45 refuses unsigned packages unless told
rpm -Uvh --force --nosignature "$pkg"

# take the build tools away again (only what this script brought in)
rpm -qa --qf '%{NAME}\n' | sort -u > "$TOP/after.txt"
# (never the security policy and its helpers: Fedora protects them, and an image already has them)
extra=$(comm -13 "$TOP/before.txt" "$TOP/after.txt" | grep -vx 'hyprland-plugin-hyprbars' | grep -vE '^(selinux-policy|policycoreutils|rpm-plugin-selinux|libselinux-utils)' || true)
if [ -n "$extra" ]; then
  dnf5 -y remove --no-autoremove $extra || dnf5 -y remove $extra || echo "hyprbars: WARNING: the build tools could not all be removed"
fi
echo "hyprbars: build tools left behind: $(rpm -q gcc-c++ meson rpm-build hyprland-devel 2>/dev/null | grep -vc 'not installed' || true)"
dnf5 -y copr disable sdegler/hyprland || true
rm -rf "$TOP"

# the check: the plugin installed is the one built here, for this Hyprland
rpm -q --qf '%{RELEASE}\n' hyprland-plugin-hyprbars | grep -q '\.taylor$' || { echo "hyprbars: the rebuilt plugin is not installed"; exit 1; }
test -s /usr/lib64/hyprland/libhyprbars.so
rpm -q hyprland hyprland-plugin-hyprbars
echo "hyprbars: built and installed for $(rpm -q hyprland)"
