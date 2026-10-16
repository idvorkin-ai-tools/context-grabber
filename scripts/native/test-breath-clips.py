#!/usr/bin/env python3
"""#279: every breathing clip ends in silence, so none stops on a click.

The shipped clips (assets/audio/breathe/*.wav, 16-bit PCM) are what the app plays; this reads them as audio:
the last 20 ms must be under -50 dBFS and the last sample within 0.5% of zero.
"""
import glob
import math
import struct
import sys
import wave

failed = 0
clips = sorted(glob.glob("assets/audio/breathe/*.wav"))
if not clips:
    print("test-breath-clips: no clips found")
    sys.exit(1)
for path in clips:
    with wave.open(path) as w:
        rate, channels = w.getframerate(), w.getnchannels()
        frames = w.readframes(w.getnframes())
    samples = struct.unpack("<%dh" % (len(frames) // 2), frames)[::channels]
    tail = samples[-int(rate * 0.02):]
    rms = math.sqrt(sum(x * x for x in tail) / len(tail)) / 32768
    db = 20 * math.log10(rms + 1e-9)
    last = abs(samples[-1]) / 32768
    ok = db < -50 and last < 0.005
    failed += not ok
    print(f"{'ok  ' if ok else 'FAIL'} {path.split('/')[-1]}: last 20 ms {db:.0f} dBFS, last sample {last:.3f}")
sys.exit(1 if failed else 0)
