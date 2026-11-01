#!/usr/bin/python3
# List the entries of an Android DTBO image (magic d7b7ab1e) and optionally extract one (dtbo_entryN.dtb).
# On the M52 the bootloader applies entry 3 (board-id <0x22 0x05>).
# Usage: dtbo_list.py <dtbo.img> [N]
import struct, sys
d = open(sys.argv[1], 'rb').read()
magic, total, hsize, esize, count, eoff, page, ver = struct.unpack('>8I', d[:32])
assert magic == 0xd7b7ab1e, hex(magic)
print('entries', count, 'version', ver, 'page', page)
for i in range(count):
    size, off, eid, rev, *custom = struct.unpack('>8I', d[eoff + i * esize: eoff + i * esize + 32])
    print(i, 'offset', off, 'size', size, 'id', hex(eid), 'rev', hex(rev), 'custom', [hex(c) for c in custom])
    if len(sys.argv) > 2 and int(sys.argv[2]) == i:
        open('dtbo_entry%d.dtb' % i, 'wb').write(d[off:off + size])
