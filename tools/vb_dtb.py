#!/usr/bin/python3
# Replace the LAST device tree (the one the Samsung bootloader uses on the M52: entry36) in a vendor_boot v3 image.
# The other DTBs, the vendor ramdisk and the header are kept; dtb_size is updated. vendor_boot_v238.img + the DTB of
# device-tree/vendor_boot-m52xq-v148.dts gives a byte-identical vendor_boot_v238.img.
# Usage: vb_dtb.py <base vendor_boot.img> <new.dtb> <out vendor_boot.img>
import struct, sys
base, newdtb, out = sys.argv[1], sys.argv[2], sys.argv[3]
v = open(base, 'rb').read()
assert v[:8] == b'VNDRBOOT' and struct.unpack_from('<I', v, 8)[0] == 3
P = struct.unpack_from('<I', v, 12)[0]           # page size
rs = struct.unpack_from('<I', v, 24)[0]          # vendor ramdisk size
hs, ds = struct.unpack_from('<II', v, 2096)      # header size, dtb size
pad = lambda n: (n + P - 1) // P * P
d0 = pad(hs) + pad(rs)                           # start of the DTB section
dtbs = v[d0:d0 + ds]
offs, o = [], 0
while o < len(dtbs):                             # walk the concatenated FDTs
    assert dtbs[o:o + 4] == b'\xd0\x0d\xfe\xed', o
    offs.append(o)
    o += struct.unpack('>I', dtbs[o + 4:o + 8])[0]
new = dtbs[:offs[-1]] + open(newdtb, 'rb').read()   # replace only the last FDT
hdr = bytearray(v[:d0])
struct.pack_into('<I', hdr, 2100, len(new))
img = bytes(hdr) + new
img += b'\0' * (pad(len(img)) - len(img))
open(out, 'wb').write(img)
print('FDTs', len(offs), 'last at', offs[-1], 'dtb_size', ds, '->', len(new))
