#!/usr/bin/env bash

# TAYLOR OS: Bazzite's own brew.sh, but not for the login screen's account (greetd) and with brew's errors kept off the
# screen: greetd reads this file when it starts her login screen, and brew's "Permission denied" flashed on the screen.
# Prioritize system binaries to prevent brew overriding things like dbus
# See: https://github.com/ublue-os/brew/blob/54b30cc07d3211fca65ca5cc724e9812c8c79b77/system_files/usr/lib/systemd/system/brew-upgrade.service#L17-L22
if [[ "$(id -un 2>/dev/null)" != greetd && -z "${HOMEBREW_PREFIX:-}" && -d /home/linuxbrew/.linuxbrew && ! "$PATH" =~ "/home/linuxbrew.linuxbrew" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null | grep -Ev '\bPATH=')"
  HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
  export PATH="${PATH}:${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin"
fi
