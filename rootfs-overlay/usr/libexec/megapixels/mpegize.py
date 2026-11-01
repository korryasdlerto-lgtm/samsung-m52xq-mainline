#!/usr/bin/python3
# Copyright 2022, 2024 Pavel Machek, GPLv2+

import os, sys, time, copy, subprocess
import shutil
import gi
gi.require_version('Gst', '1.0')
from gi.repository import Gst, GLib
import os
import time

# https://stackoverflow.com/questions/11779490/how-to-add-a-new-audio-not-mixing-into-a-video-using-ffmpeg
# https://ottverse.com/create-video-from-images-using-ffmpeg/

# https://github.com/kkroening/ffmpeg-python/issues/95

# sudo apt install ffmpeg

# Usage: mpegize convert
# head -c 1000 < /dev/zero > /tmp/delme.sm/1.foo.sa

def gst_convert(mega_dir, out_file, use_jpeg):
    def sa_read(name, t):
        with open(name, "rb") as file:
            rgb_data = file.read(10*1024*1024)

        caps_string = "audio/x-raw,format=U16LE,channels=2,rate=48000,layout=interleaved,channel-mask=3"
        caps = Gst.Caps.from_string(caps_string)

        buffer = Gst.Buffer.new_wrapped(rgb_data)
        if False:
            time.sleep(1/30.)
            # nanoseconds
            buffer.pts = time.time() * 1000*1000*1000
            buffer.dts = time.time() * 1000*1000*1000
        elif True:
            buffer.pts = t
            buffer.dts = t
        buffer.duration = (1000*1000*1000)/10.

        return buffer, caps

    def sa_src(appsrc):
        def on_need_data(appsrc, data, length):
            name = audio.get_path()
            if name == None or name[-22:] != ".48000-s16le-stereo.sa":
                appsrc.emit("end-of-stream")
                print("End of audio stream")
                return
            t = audio.get_time()
            #print("Audio: ", name, " need ", data, t)
            buffer, caps = sa_read(name, t)
            os.unlink(name)
            appsrc.set_property("caps", caps)
            appsrc.emit("push-buffer", buffer)

        appsrc.set_property("format", Gst.Format.TIME)
        appsrc.set_property("is-live", False)
        appsrc.set_property("block", True)

        name = audio.get_path()
        buffer, caps = sa_read(name, 0)

        appsrc.set_property("caps", caps)
        #appsrc.emit("push-buffer", buffer)

        s = appsrc.connect("need-data", on_need_data, "")
        print("Connect", s)

    class grwBase:
        def init(m, dir):
            m.dir = dir
            m.slen = len(m.suffix)
            m.start_time = 0
            m.scan()
            print("Movie", len(m.list))

        def scan(m):
            m.list = os.listdir(m.dir)
            m.list.sort()
            m.length = len(m.list)

        def get_path(m):
            s = m.get_name()
            if s: return m.dir + s
            return s

        def get_name(m):
            m.scan()
            #print("Get path -- ")
            while True:
                if (len(m.list)) == 0:
                    return None
                #print("Get path: ", m.list[0], m.suffix)
                if m.list[0][-m.slen:] != m.suffix:
                    m.pop()
                    continue
                return m.list[0]

        def get_time(m):
            s = m.get_name()
            s = s[:-m.slen]
            t = int(s)
            res = t * 1000 - m.start_time
            t = t / (1000*1000.)
            while (time.time() - t < 1):
                print("Too fast: ", time.time(), t, file=sys.stderr)
                print("Message: WA")
                sys.stdout.flush()
                time.sleep(.1)
            return res

        def pop(m):
            m.list = m.list[1:]

        def progress(m):
            i = len(m.list)
            print("Message: %d" % i)
            sys.stdout.flush()

    class grwVideo(grwBase):
        suffix = ".grw"
        def __init__(m, dir):
            m.init(dir)

    class grwJPEG(grwBase):
        suffix = ".jpeg.sv"
        def __init__(m, dir):
            m.init(dir + "sm/")

    class grwAudio(grwVideo):
        suffix = ".48000-s16le-stereo.sa"
        def __init__(m, dir):
            m.init(dir + "sm/")

    def grw_read(name, t):
        with open(name, "rb") as file:
            rgb_data = file.read(10*1024*1024)
        i = len(rgb_data)
        i -= 1
        while rgb_data[i] != 0:
            i -= 1
        footer = rgb_data[i+1:]
        sp = str(footer, 'ascii').split('\n')
        # Create caps for the file
        caps_string = sp[0][6:]
        caps = Gst.Caps.from_string(caps_string)
        if sp[0][:6] != "Caps: ":
            print("Bad footer")
        if sp[1][:6] != "Size: ":
            print("Bad footer")
        if sp[-1] != "GRW":
            print("Missing GRW footer")

        buffer = Gst.Buffer.new_wrapped(rgb_data)
        # This does not work for interactive use.
        if False:
            time.sleep(1/30.)
            # nanoseconds
            buffer.pts = time.time() * 1000*1000*1000
            buffer.dts = time.time() * 1000*1000*1000
        elif True:
            buffer.pts = t
            buffer.dts = t
        buffer.duration = (1000*1000*1000)/30.

        return buffer, caps

    def grwsrc(appsrc):
        def on_need_data(appsrc, data, length):
            name = movie.get_path()
            if name == None or name[-4:] != ".grw":
                appsrc.emit("end-of-stream")
                print("End of video stream")
                return
            t = movie.get_time()
            #print("Video: ", name, t)
            movie.progress()
            buffer, caps = grw_read(name, t)
            os.unlink(name)
            appsrc.set_property("caps", caps)
            appsrc.emit("push-buffer", buffer)

        appsrc.set_property("format", Gst.Format.TIME)
        appsrc.set_property("is-live", False)
        appsrc.set_property("block", True)

        name = movie.get_path()
        buffer, caps = grw_read(name, 0)

        appsrc.set_property("caps", caps)
        #appsrc.emit("push-buffer", buffer)

        s = appsrc.connect("need-data", on_need_data, "")
        print("Connect", s)

    def jpeg_read(name, t):
        with open(name, "rb") as file:
            rgb_data = file.read(10*1024*1024)
        i = len(rgb_data)
        buffer = Gst.Buffer.new_wrapped(rgb_data)

        caps_string = "image/jpeg"
        caps = Gst.Caps.from_string(caps_string)

        # This does not work for interactive use.
        if False:
            time.sleep(1/30.)
            # nanoseconds
            buffer.pts = time.time() * 1000*1000*1000
            buffer.dts = time.time() * 1000*1000*1000
        elif True:
            buffer.pts = t
            buffer.dts = t
        buffer.duration = (1000*1000*1000)/30.

        return buffer, caps

    def jpeg_src(appsrc):
        def on_need_data(appsrc, data, length):
            name = movie.get_path()
            if name == None or name[-8:] != ".jpeg.sv":
                appsrc.emit("end-of-stream")
                print("End of video stream")
                return
            t = movie.get_time()
            #print("Video: ", name, t)
            buffer, caps = jpeg_read(name, t)
            os.unlink(name)
            appsrc.set_property("caps", caps)
            appsrc.emit("push-buffer", buffer)

        appsrc.set_property("format", Gst.Format.TIME)
        appsrc.set_property("is-live", False)
        appsrc.set_property("block", True)

        name = movie.get_path()
        buffer, caps = jpeg_read(name, 0)

        appsrc.set_property("caps", caps)
        #appsrc.emit("push-buffer", buffer)

        s = appsrc.connect("need-data", on_need_data, "")
        print("Connect", s)

    def v_src(appsrc):
        if not use_jpeg:
            grwsrc(appsrc)
        else:
            jpeg_src(appsrc)

    count = 0
    path = mega_dir
    if use_jpeg:
        movie = grwJPEG(path)
    else:
        movie = grwVideo(path)
    audio = grwAudio(path)
    t1 = movie.get_time()
    t2 = audio.get_time()
    tm = min(t1,t2)
    print("Time base is", tm)
    movie.start_time = tm
    audio.start_time = tm

    def pipeline_264enc():
        if Gst.Registry.get().find_plugin("x264"):
            s = "x264enc bitrate=3072 speed-preset=ultrafast"
        else:
            s = "openh264enc bitrate=3145728 ! h264parse"
        return s

    def pipeline_video():
        if True:
            s = "appsrc name=source"
            if use_jpeg:
                s += " ! jpegdec "
        else:
            s = "videotestsrc"
            s += " ! video/x-raw,width=(int)640,height=(int)480,format=(string)RGB "
        if False:
            s += " ! videoconvert ! jpegenc"
            s += " ! appsink name=sink"
        elif True:
            s += " ! videoconvert ! autovideosink"
        else:
            s += " ! videoconvert ! " + pipeline_264enc() + " ! matroskamux ! filesink location=" + out_file

        pipeline = Gst.parse_launch(s)

        p = pipeline.get_by_name("source")
        if p:
            if False:
                mysrc(p)
            else:
                v_src(p)
        p = pipeline.get_by_name("sink")
        if p:
            mysink(p)
        return pipeline

    def pipeline_audio():
        # audiotestsrc ! audioconvert ! audioresample ! autoaudiosink
        if True:
            s = "appsrc name=source"    
        else:
            s = "audiotestsrc"

        if True:
            s += " ! audiobuffersplit ! audioconvert ! audioresample ! autoaudiosink"
        else:
            s += " ! ! ! "

        pipeline = Gst.parse_launch(s)

        p = pipeline.get_by_name("source")
        if p:
            sa_src(p)
        p = pipeline.get_by_name("sink")
        if p:
            mysink(p)
        return pipeline

    def pipeline_both():
        if True:
            s = "appsrc name=asrc"
        else:
            s = "audiotestsrc"
        # Audiobuffersplit creates problems with A/V synchronization, avoid.
        #s += "! audiobuffersplit"
        s += " ! audioconvert ! vorbisenc ! mux. "

        if True:
            s += "appsrc name=vsrc"
            if use_jpeg:
                s += " ! jpegdec "
        else:
            s += "videotestsrc"
            s += " ! video/x-raw,width=(int)640,height=(int)480,format=(string)RGB "

        s += " ! videoconvert ! " + pipeline_264enc() + " ! matroskamux name=mux"
        if False:
            s += " ! decodebin ! playsink"
        else:
            s += " ! filesink location="+out_file

        pipeline = Gst.parse_launch(s)

        p = pipeline.get_by_name("asrc")
        if p:
            sa_src(p)
        p = pipeline.get_by_name("vsrc")
        if p:
            v_src(p)
        return pipeline

    Gst.init(None)
    Gst.debug_set_default_threshold(Gst.DebugLevel.WARNING)
    if False:
        Gst.debug_set_default_threshold(Gst.DebugLevel.INFO)

    if False:
        pipeline = pipeline_video()
    elif False:
        pipeline = pipeline_audio()
    else:
        pipeline = pipeline_both()

    # Function to handle end of stream
    def on_eos(bus, message):
        print("End of stream")
        pipeline.set_state(Gst.State.NULL)
        loop.quit()

    # Set up bus to handle messages
    bus = pipeline.get_bus()
    bus.add_signal_watch()
    bus.connect("message::eos", on_eos)

    # Set the pipeline to the playing state
    pipeline.set_state(Gst.State.PLAYING)

    # Run the main loop to handle GStreamer events
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pipeline.set_state(Gst.State.NULL)
        loop.quit()

class Mpegize:
    base = '/tmp/delme.'
    fps = 30.5

    def prepare(m):
        m.source = m.base+'sm'
        m.work = m.base+'smt'
        m.output = m.base+'smo'

    def prepare_work(m):
        m.prepare()
        if not os.path.exists(m.output):
            os.mkdir(m.output)
        if not os.path.exists(m.work):
            os.mkdir(m.work)
        os.chdir(m.work)
        os.system("rm *.jpeg output.*")

    def prepare_source(m):
        m.prepare()
        m.out_index = 0
        l = os.listdir(m.source)
        print("Have", m.display_frames(len(l)), "frames")
        l.sort()
        m.frames = l
        m.unused_frames = copy.deepcopy(l)

    def parse_frame(m, n):
        if n[-5:] != ".mark" and n[-3:] != ".sa" and n[-3:] != ".sv":
            return "", "", 0,
        s = n.split(".")
        i = int(s[0])
        return s[2], s[1], i

    def help(m):
        print("mpegize command base-dir destination-movie fps dng|grw")

    def cleanup(m):
        shutil.rmtree(m.base)
        print("Message: Rec")
        sys.stdout.flush()

    def run(m, argv):
        if len(argv) > 2:
            m.base = argv[2]
            mode = argv[1]
            fps = argv[4]
            ext = argv[5]
            if mode == "start":
                print("Phase 0: start, mode ", ext, file=sys.stderr)

                if ext!="grw":
                    return
                print("Phase 0: wait", file=sys.stderr)
                
                print("Message: W1")
                sys.stdout.flush()
                
                time.sleep(1)

                print("Phase 1: parallel fun", file=sys.stderr)
                
                print("Message: proc")
                sys.stdout.flush()
                gst_convert(m.base, argv[3], ext=="dng")
                m.cleanup()
                return
            if mode == "convert" or mode == "stop":
                if ext=="grw":
                    return
                print("Phase 1: jpegize", file=sys.stderr)
                print("Message: 0%")
                sys.stdout.flush()
                m.prepare()
                m.jpegize()
                print("Phase 2: mpegize -- ", argv[3], file=sys.stderr)
                print("Message: enc")
                sys.stdout.flush()
                gst_convert(m.base, argv[3], ext=="dng")
                m.cleanup()
                return
            if mode == "gaps":
                print("Video gaps")
                m.stat_gaps("sv")
                print("Audio gaps")
                m.stat_gaps("sa")
                return
            if mode == "jpegize":
                m.prepare()
                m.jpegize()
                return
        m.help()

    def stat_gaps(m, e):
        m.prepare_source()
        last = 0
        num = 0
        total = 0
        limit = 1000000 / m.fps + 15000
        for n in m.frames:
            ext, mid, i = m.parse_frame(n)
            if ext != e:
                continue
            if i - last > limit:
                print("Gap at", i, (i - last) / 1000., "msec")
                num += 1
            last = i
            total += 1
        print("Total", num, "gaps of", total)
        print("Expected", (1000000 / m.fps) / 1000., "msec, limit", limit / 1000., "msec")

    def display_usec(m, v):
        return "%.2f sec" % (v/1000000.)

    def display_frames(m, v):
        return "%d frames %s" % (v, m.display_usec(v * 1000000 / 30.))

    def dcraw_detect(m):
        m.dcraw_bin = shutil.which("dcraw_emu")
        if not m.dcraw_bin and os.path.isfile("/usr/lib/libraw/dcraw_emu"):
            m.dcraw_bin = "/usr/lib/libraw/dcraw_emu"
        if not m.dcraw_bin:
            m.dcraw_bin = "dcraw"
        return m.dcraw_bin

    def tiffname(m, f):
        if m.dcraw_bin == "dcraw":
            f = f[:-4]
        return f + '.tiff'

    def read_preview(m):
        # m52xq: viewfinder parameters written by Megapixels (gain, red, blue, black level, gamma)
        p = {'gain': 1.0, 'red': 1.0, 'blue': 1.0, 'black': 64.0 / 1023.0, 'gamma': 2.2}
        try:
            cache = os.environ.get('XDG_CACHE_HOME') or os.path.expanduser('~/.cache')
            for kv in open(os.path.join(cache, 'megapixels-preview')).read().split():
                k, v = kv.split('=')
                p[k] = float(v)
        except Exception as e:
            print("no viewfinder parameters:", e, file=sys.stderr)
        return p

    def jpegize(m):
        i = 0
        os.chdir(m.base)
        l = os.listdir(m.base)
        l = filter(lambda n: n[-4:] == ".dng", l)
        l = list(l)
        l.sort()
        print("Have", m.display_frames(len(l)), "dngs")
        m.dcraw_detect()
        par = m.read_preview()
        linear = m.dcraw_bin != "dcraw"
        # m52xq r35: the front camera DNG carries Orientation 4 (mirror vertical); dcraw/ImageMagick leave the developed
        # frames upside down (same as the stills, see postprocess.sh): flip them back
        flip = []
        try:
            if l:
                o = subprocess.run(['exiftool', '-s3', '-n', '-Orientation', l[0]], capture_output=True, text=True).stdout.strip()
                if o == '4':
                    flip = ['-flip']
        except Exception as e:
            print("orientation not read:", e, file=sys.stderr)
        for n in l:
            if n[-4:] != ".dng":
                print("Something went terribly wrong")
                continue
            i += 1
            print("Message: %.0f%%" % ((100*i) / len(l)))
            sys.stdout.flush()
            base = n[:-4]
            tiffname = m.tiffname(n)
            try:
                if linear:
                    # m52xq: same development as the viewfinder shader: linear, no white balance / matrix / auto brightness,
                    # half size (fast), then black level, white balance gains, gain, gamma (see postprocess.sh)
                    r = subprocess.run([m.dcraw_bin, '-4', '-T', '-o', '0', '-q', '0', '-h', '-M',
                                        '-r', '1', '1', '1', '1', n])
                    if r.returncode != 0 or not os.path.exists(tiffname):
                        raise RuntimeError("dcraw failed")
                    r = subprocess.run(['convert', tiffname] + flip + ['-set', 'colorspace', 'RGB',
                                        '-evaluate', 'subtract', '%.4f%%' % (par['black'] * 100.0), '-clamp',
                                        '-channel', 'R', '-evaluate', 'multiply', '%.5f' % par['red'], '+channel',
                                        '-channel', 'B', '-evaluate', 'multiply', '%.5f' % par['blue'], '+channel',
                                        '-evaluate', 'multiply', '%.5f' % par['gain'], '-clamp',
                                        '-evaluate', 'pow', '%.5f' % (1.0 / par['gamma']), '-clamp',
                                        '-function', 'polynomial', '-1,1.5,0.5,0',
                                        '-color-matrix', '3x3: 1.17525 -0.14675 -0.0285  -0.07475 1.10325 -0.0285  -0.07475 -0.14675 1.2215', '-clamp',
                                        '-set', 'colorspace', 'sRGB', '-quality', '90', base + '.jpeg'])
                else:
                    subprocess.run([m.dcraw_bin,
                                    '-w',      # -w Use camera white balance
                                    '+M',      # +M use embedded color matrix
                                    '-H', '2', # -H 2 Recover highlights by blending them
                                    '-o', '1', # -o 1 Output in sRGB colorspace
                                    '-q', '0', # -q 0 Debayer with fast bi-linear interpolation
                                    '-f',      # -f Interpolate RGGB as four colors
                                    '-T', n])  # -T Output TIFF
                    r = subprocess.run(['convert', tiffname, base+'.jpeg'])
                if r.returncode != 0 or not os.path.exists(base + '.jpeg'):
                    raise RuntimeError("convert failed")
                os.rename(base+'.jpeg', m.source+"/"+base+'.jpeg.sv')
            except Exception as e:
                # m52xq: a damaged or half written frame must not kill the whole video
                print("skipping frame", n, e, file=sys.stderr)
            finally:
                for junk in (tiffname, base + '.jpeg', n):
                    try:
                        os.unlink(junk)
                    except OSError:
                        pass

m = Mpegize()
m.run(sys.argv)
