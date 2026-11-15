# taylor-os

TAYLOR OS: Bazzite (NVIDIA, open kernel modules) with Hyprland added and KDE Plasma kept as the backup login.

- `recipes/recipe.yml` says what goes in the image.
- `.github/workflows/build.yml` builds it every day at 06:00 UTC and on every change, and signs it.
- `cosign.pub` is the public half of the signing key. The private half lives only in the `SIGNING_SECRET` repo secret and in Key Vault.

The image is published to `ghcr.io/guitarist777/taylor-os`.
