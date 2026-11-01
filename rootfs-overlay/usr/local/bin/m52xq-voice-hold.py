#!/usr/bin/env python3
# Open CS-Voice (hw:0,5) playback+capture, prepare+start, hold without data (like q6voiced).
import ctypes, sys, time, signal
a = ctypes.CDLL('libasound.so.2')
def pcm(stream):
    h = ctypes.c_void_p()
    r = a.snd_pcm_open(ctypes.byref(h), b'hw:0,5', stream, 0)
    if r < 0: sys.exit('open %d: %s' % (stream, a.snd_strerror(r)))
    r = a.snd_pcm_set_params(h, 2, 3, 1, 8000, 1, 500000)  # S16_LE, RW_INTERLEAVED, mono, 8 kHz
    print('set_params', stream, r, flush=True)
    if stream == 0:
        # hostless: no data is ever written; stop_threshold = boundary keeps it running
        sw = ctypes.c_void_p(); a.snd_pcm_sw_params_malloc(ctypes.byref(sw))
        a.snd_pcm_sw_params_current(h, sw)
        b = ctypes.c_ulong(); a.snd_pcm_sw_params_get_boundary(sw, ctypes.byref(b))
        a.snd_pcm_sw_params_set_stop_threshold(h, sw, b)
        a.snd_pcm_sw_params_set_start_threshold(h, sw, b)
        print('sw_params', a.snd_pcm_sw_params(h, sw), flush=True)
    r = a.snd_pcm_prepare(h); print('prepare', stream, r, flush=True)
    r = a.snd_pcm_start(h); print('start', stream, r, flush=True)
    return h
a.snd_strerror.restype = ctypes.c_char_p
p = pcm(0); c = pcm(1)
print('holding', flush=True)
signal.signal(signal.SIGTERM, lambda *x: sys.exit(0))
while True: time.sleep(1)
