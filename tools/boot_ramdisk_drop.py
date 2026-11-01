#!/usr/bin/python3
# в45: remove files from the (uncompressed newc) ramdisk of an Android boot image v3 (page 4096), kernel and header kept.
# The ramdisk may be gzip compressed (m52xq boot.img: gzip); it is written back gzip compressed.
# Used to take the proprietary IPA firmware (usr/lib/firmware/yupik_ipa_fws.*) out of the boot.img that goes into the zip;
# the installer appends it again on the phone from the phone's own apnhlos partition.
# Usage: boot_ramdisk_drop.py <in boot.img> <out boot.img> <path prefix> [<path prefix> ...]
import gzip, struct, sys

src, out, prefixes = sys.argv[1], sys.argv[2], sys.argv[3:]
PAGE = 4096
pad = lambda n, a=PAGE: (n + a - 1) // a * a
b = open(src, "rb").read()
assert b[:8] == b"ANDROID!" and struct.unpack_from("<I", b, 40)[0] == 3, "not a boot image v3"
ks, rs = struct.unpack_from("<II", b, 8)
roff = PAGE + pad(ks)
raw = b[roff:roff + rs]
gz = raw[:2] == b"\x1f\x8b"
rd = gzip.decompress(raw) if gz else raw
assert rd[:6] == b"070701", "ramdisk is not a newc cpio"

entries, pos, dropped = [], 0, []
while True:
    h = rd[pos:pos + 110]
    assert h[:6] == b"070701", "bad cpio header at %d" % pos
    namesize = int(h[94:102], 16)
    filesize = int(h[54:62], 16)
    name = rd[pos + 110:pos + 110 + namesize - 1].decode()
    end = pad(pad(pos + 110 + namesize, 4) + filesize, 4)
    rec = rd[pos:end]
    if name == "TRAILER!!!":
        break
    if any(name.startswith(p) for p in prefixes):
        dropped.append(name)
    else:
        entries.append(rec)
    pos = end
# the trailer record as it was
trailer = rd[pos:pad(pos + 110 + int(rd[pos + 94:pos + 102], 16), 4)]
nrd = b"".join(entries) + trailer
nrd += b"\0" * (pad(len(nrd), 512) - len(nrd))
if gz:
    nrd = gzip.compress(nrd, compresslevel=9, mtime=0)
hdr = bytearray(b[:PAGE])
struct.pack_into("<I", hdr, 12, len(nrd))
o = bytes(hdr) + b[PAGE:roff] + nrd + b"\0" * (pad(len(nrd)) - len(nrd))
open(out, "wb").write(o)

c = open(out, "rb").read()
assert c[PAGE:PAGE + ks] == b[PAGE:PAGE + ks]
assert struct.unpack_from("<I", c, 12)[0] == len(nrd)
print("dropped:", " ".join(dropped))
print("ok: kernel %d kept, ramdisk %d -> %d, total %d" % (ks, rs, len(nrd), len(c)))
