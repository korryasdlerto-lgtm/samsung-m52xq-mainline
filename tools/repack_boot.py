#!/usr/bin/python3
# Replace the kernel Image in an Android boot image v3 (page 4096) that carries a DTB tail after the Image
# inside the kernel blob (m52xq: boot.img kernel = Image + appended DTB). Ramdisk and header fields kept.
# Usage: repack_boot.py <base boot.img> <old Image size> <new Image> <out boot.img>
import struct, sys

base, old_image_size, new_image, out = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
PAGE = 4096
b = open(base, "rb").read()
assert b[:8] == b"ANDROID!", "not a boot image"
kernel_size, ramdisk_size = struct.unpack_from("<II", b, 8)
header_version = struct.unpack_from("<I", b, 40)[0]
assert header_version == 3, "header v%d" % header_version
pad = lambda n: (n + PAGE - 1) // PAGE * PAGE
kernel = b[PAGE:PAGE + kernel_size]
roff = PAGE + pad(kernel_size)
ramdisk = b[roff:roff + ramdisk_size]
tail = kernel[old_image_size:]
img = open(new_image, "rb").read()
assert img[0x38:0x3c] == b"ARM\x64", "not an arm64 Image"
nk = img + tail
hdr = bytearray(b[:PAGE])
struct.pack_into("<I", hdr, 8, len(nk))
o = bytes(hdr) + nk + b"\0" * (pad(len(nk)) - len(nk)) + ramdisk + b"\0" * (pad(ramdisk_size) - ramdisk_size)
open(out, "wb").write(o)

# read back
c = open(out, "rb").read()
ks, rs = struct.unpack_from("<II", c, 8)
assert ks == len(img) + len(tail) and rs == ramdisk_size
assert c[PAGE:PAGE + len(img)] == img and c[PAGE + len(img):PAGE + ks] == tail
r2 = PAGE + pad(ks)
assert c[r2:r2 + rs] == ramdisk
print("ok: Image %d + DTB tail %d = kernel_size %d, ramdisk %d, total %d" % (len(img), len(tail), ks, rs, len(c)))
