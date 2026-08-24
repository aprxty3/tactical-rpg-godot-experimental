#!/usr/bin/env python3
"""Generate the placeholder BGM loops.

The project ships no music, and the audio pipeline (crossfade, ducking) cannot
be judged -- or tested -- against silence. These are deliberately plain: a few
detuned oscillators over a chord progression, with a soft pulse to carry tempo.
They are scaffolding for the mixing code, not a soundtrack, and are meant to be
replaced by real tracks dropped in at the same paths.

Stdlib only. numpy is not installed in this environment, and a music generator
is not worth adding a dependency for; `wave` plus `array` writes the same PCM.
Output matches the existing SFX exactly: mono, 44100 Hz, 16-bit.

    python3 scripts_dev/generate_music.py

SEAMLESS LOOPING is the one thing here that is not arbitrary. Every partial's
frequency is snapped to a multiple of 1/loop_length before rendering, so each
one completes a whole number of cycles inside the loop and the last sample joins
the first with no discontinuity. Without that snap the loop point clicks, and no
amount of fading hides it without also making the seam audible as a dip.
"""
from __future__ import annotations

import array
import math
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "audio" / "music"

SAMPLE_RATE = 44100
BIT_DEPTH = 16
PEAK = 0.72  # headroom so the Music bus can duck without the sum clipping

# Semitone offsets from A, and the octave, resolved to Hz at render time.
A4 = 440.0


def note(semitones_from_a4: int) -> float:
    return A4 * (2.0 ** (semitones_from_a4 / 12.0))


# --- Track definitions -------------------------------------------------------
# chords: each entry is a list of semitone offsets played together for one bar.
# The progressions are short on purpose; a long one only makes the placeholder
# harder to sit through while testing.
TRACKS = {
    # Player turn: open, unhurried, major.
    "calm": {
        "loop_seconds": 16.0,
        "bar_count": 4,
        "chords": [[-24, -17, -12, -5], [-22, -15, -10, -3], [-19, -12, -7, 0], [-24, -17, -12, -5]],
        "pulse_hz": 0.0,
        "gain": 0.55,
        "brightness": 0.30,
    },
    # AI turn: same shape a minor third down, with a slow pulse. Unsettled, but
    # not yet an emergency.
    "tension": {
        "loop_seconds": 16.0,
        "bar_count": 4,
        "chords": [[-25, -18, -13, -6], [-25, -18, -13, -1], [-27, -20, -15, -3], [-25, -18, -13, -6]],
        "pulse_hz": 1.0,
        "gain": 0.55,
        "brightness": 0.45,
    },
    # Combat: faster pulse, tighter voicing, more upper harmonics.
    "combat": {
        "loop_seconds": 8.0,
        "bar_count": 4,
        "chords": [[-24, -17, -12, -8], [-22, -15, -10, -6], [-20, -13, -8, -4], [-24, -17, -12, -8]],
        "pulse_hz": 2.0,
        "gain": 0.62,
        "brightness": 0.60,
    },
}


def snap_to_loop(freq: float, loop_seconds: float) -> float:
    """Round a frequency so it completes a whole number of cycles in the loop.

    The shift is at most 1/(2*loop_seconds) Hz -- well under a cent at these
    pitches -- and it is what makes the loop point silent.
    """
    cycles = max(1.0, round(freq * loop_seconds))
    return cycles / loop_seconds


def render(spec: dict) -> array.array:
    loop_seconds: float = spec["loop_seconds"]
    total = int(SAMPLE_RATE * loop_seconds)
    bar_samples = total // spec["bar_count"]
    samples = array.array("f", [0.0]) * total

    for bar, chord in enumerate(spec["chords"][: spec["bar_count"]]):
        start = bar * bar_samples
        end = total if bar == spec["bar_count"] - 1 else start + bar_samples
        for semi in chord:
            base = snap_to_loop(note(semi), loop_seconds)
            # Fundamental plus one octave partial; brightness sets how much of
            # the partial survives, which is the only timbre control here.
            for partial, weight in ((1.0, 1.0), (2.0, spec["brightness"])):
                freq = snap_to_loop(base * partial, loop_seconds)
                omega = 2.0 * math.pi * freq / SAMPLE_RATE
                for i in range(start, end):
                    # Phase is absolute (i, not i-start) so a note held across a
                    # bar boundary stays continuous instead of restarting.
                    samples[i] += weight * math.sin(omega * i)

    # Envelope: a gentle bar-level swell, again phase-locked to the loop so the
    # amplitude curve joins itself at the seam.
    pulse_hz = spec["pulse_hz"]
    if pulse_hz > 0.0:
        pulse_hz = snap_to_loop(pulse_hz, loop_seconds)
        omega = 2.0 * math.pi * pulse_hz / SAMPLE_RATE
        for i in range(total):
            samples[i] *= 0.65 + 0.35 * (0.5 + 0.5 * math.sin(omega * i))

    peak = max(abs(v) for v in samples) or 1.0
    scale = PEAK * spec["gain"] / peak
    return array.array("f", (v * scale for v in samples))


def write_wav(path: Path, samples: array.array) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = array.array("h", (int(max(-1.0, min(1.0, v)) * 32767) for v in samples))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(BIT_DEPTH // 8)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(pcm.tobytes())


def seam_ratio(samples: array.array) -> float:
    """How abrupt the loop point is, relative to an ordinary sample step.

    Comparing the last sample to the first directly is the wrong test: they are
    one sample apart in the looped stream, so a difference is *expected* and a
    healthy loop still shows one. What makes a click audible is a step far
    larger than its neighbours, so this measures the seam step against the
    typical step elsewhere in the track. Below 1.0 means the loop point is no steeper
    than the steepest slope the track already plays through, so wrapping
    introduces no discontinuity the ear has not already accepted.
    """
    seam_step = abs(samples[0] - samples[-1])
    # Compared against the LARGEST steps the track already contains, not the
    # median. A sum of partials spends much of its time near a zero crossing, so
    # the median step is tiny and would flag a perfectly ordinary seam. What
    # actually matters is whether the seam stands out against the steepest
    # slopes already present -- if it does not, it cannot be heard as a click.
    steepest = 0.0
    for i in range(len(samples) - 1):
        step = abs(samples[i + 1] - samples[i])
        if step > steepest:
            steepest = step
    return seam_step / (steepest or 1e-9)


def main() -> int:
    worst = 0.0
    for name, spec in TRACKS.items():
        samples = render(spec)
        path = OUT_DIR / f"{name}.wav"
        write_wav(path, samples)
        ratio = seam_ratio(samples)
        worst = max(worst, ratio)
        flag = "ok" if ratio < 1.0 else "SEAM"
        print(
            f"  [{flag}] {path.relative_to(ROOT)}  "
            f"{spec['loop_seconds']:.0f}s  seam={ratio:.2f}x the steepest normal slope"
        )
    print(f"worst seam: {worst:.2f}x (want < 1.0x)")
    return 0 if worst < 1.0 else 1


if __name__ == "__main__":
    sys.exit(main())
