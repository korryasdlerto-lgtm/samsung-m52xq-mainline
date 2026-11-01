#!/usr/bin/python3
# Append a newc cpio (gzip-compressed here) after the ramdisk of a boot v3 image and update ramdisk_size.
# Release v1 adds the IPA firmware this way: an uncompressed cpio after the 70-byte vendor ramdisk is not 4-byte
# aligned and the kernel rejects it ("invalid magic"); a gzip member is found at any offset.
# Usage: boot_ramdisk_append.py <boot.img> <extra.cpio> <out boot.img>
import gzip, struct, sys
src, extra, out = sys.argv[1], sys.argv[2], sys.argv[3]   # extra = a newc cpio (from: cpio -o -H newc)
P = 4096
pad = lambda n, a=P: (n + a - 1) // a * a
b = open(src, 'rb').read()
assert b[:8] == b'ANDROID!' and struct.unpack_from('<I', b, 40)[0] == 3
ks, rs = struct.unpack_from('<II', b, 8)
roff = P + pad(ks)
rd = b[roff:roff + rs]
rd += b'\0' * ((4 - len(rd) % 4) % 4)
rd += gzip.compress(open(extra, 'rb').read(), 9, mtime=0)   # gzip: found by the kernel at any offset
hdr = bytearray(b[:P])
struct.pack_into('<I', hdr, 12, len(rd))
img = bytes(hdr) + b[P:roff] + rd
img += b'\0' * (pad(len(img)) - len(img))
open(out, 'wb').write(img)
print('ramdisk', rs, '->', len(rd))
