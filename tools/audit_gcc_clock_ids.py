#!/usr/bin/env python3
"""Audit of GCC clock IDs in an entry36 DTS (downstream-decompiled DT used with a mainline kernel).

For every `clocks = <...>` / `clock-names = "..."` pair whose provider is gcc (phandle 0x28) and whose name is (a variant of)
a GCC clock macro, the ID in the DT is compared with the mainline header. Downstream and mainline GCC IDs diverge after ~20.
Usage: audit_gcc_clock_ids.py entry36_current_vNN.dts
"""
import os, re, sys
ROOT = os.environ.get('M52XQ_ROOT', './')
def hdr(p):
    d = {}
    for l in open(p):
        m = re.match(r'#define\s+(GCC_\w+)\s+(\d+)', l)
        if m: d[m.group(1).lower()] = int(m.group(2))
    return d
ml = hdr(ROOT + 'linux/include/dt-bindings/clock/qcom,gcc-sc7280.h')
ds = hdr(ROOT + 'lineage_kernel_sm7325/include/dt-bindings/clock/qcom,gcc-yupik.h')
lines = open(sys.argv[1]).read().split('\n')
def node(i):
    while i > 0:
        if re.match(r'\t\t[\w@,.\-]+ \{', lines[i]): return lines[i].strip()
        i -= 1
    return '?'
bad = 0
for i, l in enumerate(lines):
    m = re.match(r'\s*clocks = <(.*)>;', l)
    if not m: continue
    names = None
    for k in range(i - 1, min(i + 4, len(lines))):
        mm = re.match(r'\s*clock-names = "(.*)";', lines[k])
        if mm: names = mm.group(1).split('\\0'); break
    if not names: continue
    cells = [int(x, 16) for x in m.group(1).split()]
    pairs = [(cells[k], cells[k + 1]) for k in range(0, len(cells) - 1, 2)]
    if len(pairs) != len(names): continue
    for (ph, cid), nm in zip(pairs, names):
        if ph != 0x28: continue
        key = nm.lower()
        for cand in (key, key + '_src', key + '_clk', key.replace('_clk_src', '_clk'), key.replace('_clk', '_clk_src')):
            if cand in ml:
                if ml[cand] != cid:
                    bad += 1
                    print('line %d %s: %s DT=%#x mainline(%s)=%#x %s' % (i + 1, node(i)[:34], nm, cid, cand, ml[cand], '[downstream ID]' if ds.get(cand) == cid else ''))
                break
print('mismatches:', bad)
