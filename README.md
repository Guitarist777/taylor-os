# taylor-os

TAYLOR OS: Bazzite (NVIDIA, open kernel modules) with Hyprland added and KDE Plasma kept as the backup login.

- `recipes/recipe.yml` says what goes in the image.
- `.github/workflows/build.yml` builds it every day at 06:00 UTC and on every change, and signs it.
- `cosign.pub` is the public half of the signing key. The private half lives only in the `SIGNING_SECRET` repo secret and in Key Vault.

The image is published to `ghcr.io/guitarist777/taylor-os`.

## Credits

- Icons: Slot-Dark-Icons by L4ki, from [L4ki/Slot-Plasma-Themes](https://github.com/L4ki/Slot-Plasma-Themes), GPL-3.0. Not stored in this repository: the image build fetches one pinned commit, checks its sha256, and installs the theme unchanged with its LICENSE and a note (`files/scripts/slot-icons.sh`).
- Fonts: Manrope and Share Tech Mono, SIL Open Font License (`files/system/usr/share/fonts/taylor/`).
