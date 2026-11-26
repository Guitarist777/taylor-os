#!/usr/bin/env bash
# Puts her window buttons' plugin, built in the image build's own Fedora stage (hyprbars-stage.sh), into the image, and
# stops the build unless it was built for exactly the Hyprland installed here (release and all).
set -euo pipefail
IN=/tmp/hyprbars-out
want=$(rpm -q --qf '%{VERSION}-%{RELEASE}' hyprland)
got=$(cat "$IN/built-against.txt")
[ "$want" = "$got" ] || { echo "hyprbars: built for hyprland $got, but the image has $want"; exit 1; }
# built just now from the checksummed source, so it carries no signature: Fedora 45 refuses unsigned packages unless told
rpm -Uvh --force --nosignature "$IN"/hyprland-plugin-hyprbars-*.taylor.x86_64.rpm
rpm -q --qf '%{RELEASE}\n' hyprland-plugin-hyprbars | grep -q '\.taylor$' || { echo "hyprbars: the rebuilt plugin is not installed"; exit 1; }
test -s /usr/lib64/hyprland/libhyprbars.so
rm -rf "$IN"
echo "hyprbars: installed $(rpm -q hyprland-plugin-hyprbars) for $(rpm -q hyprland)"
