# TAYLOR OS installer (her yes, 2026-11-15): Fedora's own network installer, told to install the TAYLOR OS image.
# It downloads the image from ghcr.io while it installs, so the installer stays small (a full offline ISO of a
# Bazzite image is 8-9 GB, over GitHub's 2 GB limit for a file).
#
# On purpose this file does NOT set the disk, language, keyboard, time zone or user: the installer asks for each
# of those on screen. It can never pick a disk by itself, so it can never wipe the Windows drive unless she
# chooses it. She picks the SanDisk.

ostreecontainer --url=ghcr.io/guitarist777/taylor-os:latest --transport=registry --no-signature-verification
network --bootproto=dhcp --activate

%post --erroronfail
# From now on, only accept updates signed with this repo's key (cosign.pub; the image's signing module wrote the policy).
bootc switch --mutate-in-place --enforce-container-sigpolicy --transport registry ghcr.io/guitarist777/taylor-os:latest
%end

%post
# Start in picture mode (the login screen), whatever the installer decides for an image payload. A safety net: her
# first boot's text console (2026-11-18) came from the image itself (fixed in the recipe); taylor-heal checks this too.
systemctl set-default graphical.target
%end

%post
# Secure Boot: queue Universal Blue's driver-signing key so the NVIDIA driver loads. On the first boot a blue
# screen asks once to enroll it; the password it asks for is: universalblue
mokutil --timeout -1 || :
if [ -f /etc/pki/akmods/certs/akmods-ublue.der ]; then
    printf 'universalblue\nuniversalblue\n' | mokutil --import /etc/pki/akmods/certs/akmods-ublue.der || :
fi
%end
