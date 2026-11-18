"""Play a real PCM WAV on the default Windows output; pair with visible prompts.

This is a human cue, never evidence of the actual key-hold interval. The user
confirmed WAV playback is audible; the legacy Beep() API was not reliable.
"""
import argparse
import json
import math
from pathlib import Path
import struct
import time
import wave


def make_wave(path, notes):
    samples, rate = [], 44100
    for frequency, seconds in notes:
        count = round(rate * seconds)
        for n in range(count):
            envelope = min(1, n / (.015 * rate), (count - n - 1) / (.04 * rate))
            samples.append(round(16000 * envelope * math.sin(2 * math.pi * frequency * n / rate)))
        samples.extend([0] * round(.15 * rate))
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(struct.pack('<' + 'h' * len(samples), *samples))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--variant', required=True, choices=['next', 'prime'])
    parser.add_argument('--seconds', type=int, default=8, choices=range(3, 21))
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    import winsound
    audio = Path(__file__).resolve().parent / 'artifacts/audio'
    audio.mkdir(parents=True, exist_ok=True)
    start, stop = audio / 'start.wav', audio / 'stop.wav'
    make_wave(start, [(660, .3), (880, .3), (1100, .5)])
    make_wave(stop, [(880, .3), (660, .3), (440, .6)])
    started = time.monotonic_ns()
    print(f'=== START: HOLD VOLUME DOWN NOW ({args.variant.upper()}) ===', flush=True)
    winsound.PlaySound(str(start), winsound.SND_FILENAME | winsound.SND_ASYNC)
    time.sleep(args.seconds)
    stopped = time.monotonic_ns()
    print('=== STOP: RELEASE VOLUME DOWN NOW ===', flush=True)
    winsound.PlaySound(str(stop), winsound.SND_FILENAME)
    args.out.write_text(json.dumps({'variant': args.variant, 'intendedHoldSeconds': args.seconds,
        'startHostMonotonicNs': started, 'stopHostMonotonicNs': stopped,
        'limits': 'Audible cue only. Actual DOWN times, count and hold length come from the native probe.'}, indent=2))


if __name__ == '__main__':
    main()
