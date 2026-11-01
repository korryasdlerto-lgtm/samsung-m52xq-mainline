#!/bin/sh
# в41: run before building a zip: rootfs-files must NOT contain anything (files, links, even EMPTY DIRECTORIES) below or at a
# directory that is a symlink in the rootfs (usr/sbin -> bin, bin -> usr/bin, sbin -> usr/bin, lib -> usr/lib): TWRP's toybox
# `cp -a` fails with "Too many symbolic links encountered" and the installer prints "WARNING: cp of rootfs-files failed partway through"
# (v40: file usr/sbin/ModemManager; v41 first build: leftover empty directory usr/sbin). The top-level bin/lib/sbin are handled by
# update-binary; nested ones are not.
# Usage: check-rootfs-files-paths.sh <path to mainline-extras/rootfs-files>
d=${1:?rootfs-files directory}
bad=$(cd "$d" && find usr/sbin bin sbin 2>/dev/null)
if [ -n "$bad" ]; then echo "BAD (put them under the real directory, usr/sbin -> usr/bin; remove empty dirs):"; echo "$bad"; exit 1; fi
echo "rootfs-files paths ok"
