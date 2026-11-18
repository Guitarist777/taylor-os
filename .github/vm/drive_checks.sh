#!/usr/bin/bash
# Checks inside the test virtual PC for the Windows-drive mount (2026-11-18). Run as root; prints PASS / FAIL lines.
#   drive_checks.sh hibernated   the made-up Windows drive is "hibernated": it must NOT be mounted, with a plain reason
#   drive_checks.sh mounted      the drive is clean: mounted the safe way, then SQLite WAL on it survives kill -9
#   drive_checks.sh leave        kill -9 the writers once more and leave the -wal file behind for the runner to open
U=tester
M=/var/mnt/windows
T=$M/Users/$U/taylor-test
say() { if eval "$2" >/dev/null 2>&1; then echo "PASS $1"; else echo "FAIL $1"; fi; }

case "$1" in
hibernated)
    echo "status: $(cat /run/taylor-os/windows-drive 2>&1)"
    journalctl -b -u taylor-windows-mount --no-pager | tail -8
    say "a hibernated Windows drive is refused, with the reason" "grep -q 'refused: Windows on .* is hibernated' /run/taylor-os/windows-drive"
    say "nothing is mounted at /var/mnt/windows while Windows is hibernated" "! mountpoint -q $M"
    say "the reason is in the journal" "journalctl -b -u taylor-windows-mount --no-pager | grep -q 'is hibernated'"
    say "the mount service finished (the boot was not held up)" "systemctl is-active -q taylor-windows-mount.service"
    say "her user manager waits for the mount" "systemctl show -p After user@1000.service | grep -q taylor-windows-mount.service"
    ;;
mounted)
    echo "status: $(cat /run/taylor-os/windows-drive 2>&1)"
    findmnt $M
    journalctl -b -u taylor-windows-mount --no-pager | tail -8
    dev=$(findmnt -no SOURCE $M)
    say "the Windows drive is mounted at /var/mnt/windows" "mountpoint -q $M"
    say "it is mounted with the kernel's ntfs3 driver" "[ \"\$(findmnt -no FSTYPE $M)\" = ntfs3 ]"
    say "it is mounted read-write" "findmnt -no OPTIONS $M | grep -q '^rw,'"
    say "it picked the partition that holds Windows, not the data partition" "[ \"\${dev##*[a-z]}\" = 2 ]"
    say "the data partition is not mounted" "! findmnt -S ${dev%2}1"
    say "the files belong to her account" "[ \"\$(stat -c %U $M/Users)\" = $U ]"
    say "only she can open it (mode 700)" "[ \"\$(stat -c %a $M/Users)\" = 700 ]"
    say "another account cannot read it" "! runuser -u nobody -- ls $M/Users"
    say "a file name Windows could not open is refused (windows_names)" "! runuser -u $U -- touch '$T/bad:name'"
    say "an ordinary file name works" "runuser -u $U -- touch '$T/ordinary name.txt'"
    say "the status line says mounted" "grep -q '^mounted .* rw for $U' /run/taylor-os/windows-drive"
    echo "--- SQLite WAL on ntfs3, kernel $(uname -r), SQLite $(python3 -c 'import sqlite3; print(sqlite3.sqlite_version)')"
    runuser -u $U -- python3 $T/wal_proof.py crash $T/brain 5
    ;;
leave)
    runuser -u $U -- python3 $T/wal_proof.py leave $T/brain
    ls -la $T/brain
    ;;
esac
