"""Procedural audio asset generator for TETHERFALL.

All music and SFX in the game are synthesized here with numpy, so the project
has no third-party audio dependencies. Run from the project root:

    python tools/generate_audio.py
"""
import os
import wave
import numpy as np
from scipy.signal import lfilter

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def write_wav(name, data, sr=SR):
    data = np.asarray(data, dtype=np.float64)
    if data.ndim == 1:
        data = np.stack([data, data], axis=1)
    peak = np.max(np.abs(data))
    if peak > 0:
        data = data / peak * 0.82
    pcm = (np.clip(data, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(os.path.join(OUT, name), "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(sr)
        f.writeframes(pcm.tobytes())
    print(f"  {name:20s} {len(data) / sr:6.2f}s")


def env(n, attack, decay, curve=2.0):
    a = min(max(1, int(attack * SR)), n)
    d = min(max(1, int(decay * SR)), n - a)
    e = np.zeros(n)
    e[:a] = np.linspace(0.0, 1.0, a) ** 0.6
    if d > 0:
        e[a:a + d] = np.linspace(1.0, 0.0, d) ** curve
    return e


def sine(freq, n, phase=0.0):
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * freq * t + phase)


def noise(n):
    return rng.uniform(-1.0, 1.0, n)


def lowpass(x, cutoff):
    # one-pole low pass
    a = np.exp(-2 * np.pi * cutoff / SR)
    return lfilter([1 - a], [1, -a], x)


def hp(x, cutoff):
    return x - lowpass(x, cutoff)


def reverb(x, delays=(0.08, 0.155, 0.23, 0.34), gains=(0.35, 0.25, 0.18, 0.12)):
    out = x.copy()
    for d, g in zip(delays, gains):
        s = int(d * SR)
        buf = np.zeros_like(x)
        buf[s:] = x[:-s] * g
        out += lowpass(buf, 3200)
    return out


def pad_chord(freqs, n, detune=0.004, cutoff=1200):
    sig = np.zeros(n)
    for f in freqs:
        for dt in (-detune, 0.0, detune):
            sig += sine(f * (1 + dt), n, rng.uniform(0, 6.28))
    sig /= max(1, len(freqs) * 3)
    sig = lowpass(sig, cutoff)
    return sig


def note(freq, dur, kind="sine", amp=0.3):
    n = int(dur * SR)
    if kind == "sine":
        s = sine(freq, n)
    elif kind == "tri":
        s = 2 / np.pi * np.arcsin(np.sin(2 * np.pi * freq * np.arange(n) / SR))
    elif kind == "saw":
        s = (2 * ((freq * np.arange(n) / SR) % 1.0)) - 1
    else:
        s = sine(freq, n)
    return s * env(n, 0.005, dur, 2.0) * amp


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def make_menu_music(duration=32.0):
    n = int(duration * SR)
    outl = np.zeros(n)
    outr = np.zeros(n)
    # Slow Am - F - C - G progression (4 bars of 8s, 60 bpm feel)
    roots = [57, 53, 48, 55]  # A3 F3 C3 G3
    chords = [[57, 60, 64, 67], [53, 57, 60, 65], [48, 52, 55, 59], [55, 59, 62, 64]]
    bar = duration / 4
    for b, chord in enumerate(chords):
        start = int(b * bar * SR)
        seg_n = int(bar * SR) + int(0.35 * SR)
        sig = pad_chord([midi(m - 12) for m in chord], seg_n, detune=0.005, cutoff=800)
        # slow swell
        e = np.ones(seg_n) * 0.30
        fade = int(1.8 * SR)
        e[:fade] = np.linspace(0, 1, fade) ** 0.8
        e[-fade:] = np.linspace(1, 0, fade) ** 0.8
        sig *= e
        end = min(n, start + seg_n)
        outl[start:end] += sig[:end - start]
        outr[start:end] += np.roll(sig, 300)[:end - start]
        # warm sub
        sub = sine(midi(roots[b] - 24), seg_n) * e * 0.16
        outl[start:end] += sub[:end - start]
        outr[start:end] += sub[:end - start]
    # sparse bells
    bell_times = [2.0, 6.2, 11.5, 14.8, 19.2, 24.5, 27.5, 30.0]
    bell_notes = [72, 67, 76, 72, 69, 74, 71, 67]
    for t, m in zip(bell_times, bell_notes):
        start = int(t * SR)
        dur = 3.0
        seg = note(midi(m), dur, "sine", 0.10)
        seg += note(midi(m) * 2.01, dur, "sine", 0.035)
        seg = reverb(seg)
        end = min(n, start + len(seg))
        pan = rng.uniform(-0.4, 0.4)
        outl[start:end] += seg[:end - start] * (1 - pan)
        outr[start:end] += seg[:end - start] * (1 + pan)
    # distant radio ticks
    for t in np.arange(1.0, duration, 4.0):
        start = int(t * SR)
        seg = lowpass(noise(int(0.05 * SR)), 2200) * env(int(0.05 * SR), 0.002, 0.05) * 0.05
        outl[start:start + len(seg)] += seg
    outl = reverb(outl, gains=(0.28, 0.20, 0.12, 0.07))
    outr = reverb(outr, gains=(0.28, 0.20, 0.12, 0.07))
    # fade the loop boundary gently (kept a little level so it doesn't feel empty)
    return np.stack([outl, outr], axis=1) * 0.75


def make_game_music(duration=32.0):
    n = int(duration * SR)
    outl = np.zeros(n)
    outr = np.zeros(n)
    bpm = 96.0
    beat = 60.0 / bpm
    # A minor to F, 8 bars each 2s => 4 chords over 8s? Use 4 x 8s = 32s.
    chords = [[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 55, 59]]
    bar = duration / 4
    for b, chord in enumerate(chords):
        start = int(b * bar * SR)
        seg_n = int(bar * SR) + int(0.3 * SR)
        pad = pad_chord([midi(m - 12) for m in chord], seg_n, cutoff=650)
        pad *= np.ones(seg_n) * 0.11
        fade = int(0.8 * SR)
        pad[:fade] *= np.linspace(0, 1, fade)
        pad[-fade:] *= np.linspace(1, 0, fade)
        end = min(n, start + seg_n)
        outl[start:end] += pad[:end - start]
        outr[start:end] += np.roll(pad, 220)[:end - start]
        # bass pulse on eighth notes
        for i in range(16):
            t = b * bar + i * (bar / 16)
            if t >= duration:
                continue
            s = int(t * SR)
            bn = int(0.20 * SR)
            amp = 0.22 if i % 4 == 0 else 0.12
            f = midi(chord[0] - 24)
            bass = sine(f, bn) * env(bn, 0.004, 0.19, 2.5) * amp
            bass += sine(f * 2, bn) * env(bn, 0.004, 0.12, 3.0) * amp * 0.25
            e = min(n, s + bn)
            outl[s:e] += bass[:e - s]
            outr[s:e] += bass[:e - s]
        # arpeggio, 16th notes sparse
        for i in range(8):
            t = b * bar + i * (bar / 8) + bar / 32
            if t >= duration:
                continue
            s = int(t * SR)
            m = chord[(i + b) % len(chord)] + 12
            dur = bar / 8
            seg = note(midi(m), dur, "tri", 0.055)
            seg = lowpass(seg, 2600)
            e = min(n, s + len(seg))
            pan = 0.25 * np.sin(i * 1.3)
            outl[s:e] += seg[:e - s] * (1 - pan)
            outr[s:e] += seg[:e - s] * (1 + pan)
    # pulse kick and tick
    total_beats = int(duration / beat)
    for i in range(total_beats):
        t = i * beat
        s = int(t * SR)
        kn = int(0.30 * SR)
        k = sine(55, kn) * env(kn, 0.002, 0.28, 3.0) * (0.18 if i % 2 == 0 else 0.08)
        e = min(n, s + kn)
        outl[s:e] += k[:e - s]
        outr[s:e] += k[:e - s]
        # hat
        hs = int((t + beat * 0.5) * SR)
        hn = int(0.05 * SR)
        if hs + hn < n:
            h = hp(noise(hn), 5000) * env(hn, 0.001, 0.045) * 0.035
            outl[hs:hs + hn] += h
            outr[hs:hs + hn] += h * 0.8
    outl = reverb(outl, gains=(0.22, 0.14, 0.09, 0.05))
    outr = reverb(outr, gains=(0.22, 0.14, 0.09, 0.05))
    return np.stack([outl, outr], axis=1) * 0.8


def sweep(f0, f1, dur, amp=0.3, kind="sine"):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = np.linspace(f0, f1, n)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * env(n, 0.01, dur, 1.6) * amp


def sfx_tether_fire():
    n = int(0.45 * SR)
    s = hp(noise(n), 900) * env(n, 0.005, 0.42) * 0.35
    s += sweep(900, 180, 0.45, 0.20)
    return lowpass(s, 6000)


def sfx_tether_attach():
    n = int(0.7 * SR)
    s = hp(noise(int(0.12 * SR)), 1800) * env(int(0.12 * SR), 0.001, 0.12) * 0.6
    out = np.zeros(n)
    out[:len(s)] += s
    out += sine(180, n) * env(n, 0.001, 0.5, 3.5) * 0.30
    out += sine(1200, n) * env(n, 0.001, 0.45, 4.0) * 0.12
    out += sine(1810, n) * env(n, 0.001, 0.3, 5.0) * 0.06
    return reverb(out)


def sfx_tether_release():
    n = int(0.28 * SR)
    return hp(noise(n), 1200) * env(n, 0.002, 0.26) * 0.18


def sfx_pickup():
    out = np.zeros(int(0.8 * SR))
    for i, m in enumerate((79, 84, 88)):
        seg = note(midi(m), 0.42, "sine", 0.30)
        start = int(i * 0.055 * SR)
        out[start:start + len(seg)] += seg[:len(out) - start]
    return reverb(out, gains=(0.25, 0.15, 0.08, 0.04))


def sfx_deposit():
    n = int(2.2 * SR)
    out = np.zeros(n)
    for m in (48, 55, 60, 64, 67, 72):
        seg = note(midi(m), 1.8, "sine", 0.16)
        out[:len(seg)] += seg
    sw = sweep(300, 1600, 0.5, 0.12)
    out[:len(sw)] += sw
    for i in range(6):
        start = int((0.35 + i * 0.09) * SR)
        seg = note(midi(84 + i * 2), 0.35, "sine", 0.06)
        e = min(n, start + len(seg))
        out[start:e] += seg[:e - start]
    return reverb(out, gains=(0.3, 0.2, 0.12, 0.08))


def sfx_boost():
    n = int(0.9 * SR)
    s = lowpass(noise(n), 1400) * env(n, 0.05, 0.85, 1.5) * 0.22
    s += sweep(120, 420, 0.9, 0.15, "saw")
    return s


def sfx_hit():
    n = int(1.1 * SR)
    out = sine(70, n) * env(n, 0.001, 0.9, 3.0) * 0.6
    out += sine(110, n) * env(n, 0.001, 0.5, 3.0) * 0.25
    crunch = lowpass(noise(n), 900) * env(n, 0.001, 0.35, 2.5) * 0.35
    return out + crunch


def sfx_flare():
    n = int(3.2 * SR)
    s = sweep(45, 90, 3.2, 0.45)
    s += lowpass(noise(n), 500) * env(n, 0.4, 2.8, 1.4) * 0.30
    s += sweep(200, 60, 3.2, 0.12, "saw")
    return reverb(s, gains=(0.4, 0.3, 0.2, 0.12))


def sfx_warning():
    out = np.zeros(int(0.85 * SR))
    for i in range(2):
        start = int(i * 0.42 * SR)
        seg = sine(880, int(0.16 * SR)) * env(int(0.16 * SR), 0.005, 0.15, 2.0) * 0.25
        out[start:start + len(seg)] += seg
        seg2 = sine(660, int(0.16 * SR)) * env(int(0.16 * SR), 0.005, 0.15, 2.0) * 0.15
        out[start + int(0.18 * SR):start + int(0.18 * SR) + len(seg2)] += seg2
    return out


def sfx_game_over():
    n = int(3.0 * SR)
    out = np.zeros(n)
    for i, m in enumerate((62, 58, 55, 50)):
        dur = 1.0
        seg = note(midi(m), dur, "tri", 0.18)
        start = int(i * 0.55 * SR)
        out[start:start + len(seg)] += seg[:n - start]
    out += lowpass(noise(n), 400) * env(n, 0.2, 2.6, 1.5) * 0.08
    return reverb(out)


def sfx_new_best():
    n = int(2.0 * SR)
    out = np.zeros(n)
    for i, m in enumerate((67, 71, 74, 79, 83)):
        start = int(i * 0.12 * SR)
        seg = note(midi(m), 1.2, "sine", 0.17)
        out[start:start + len(seg)] += seg[:n - start]
    return reverb(out)


def sfx_ui():
    out = np.zeros(int(0.9 * SR))
    seg = note(520, 0.7, "sine", 0.12)
    out[:len(seg)] += seg
    seg = note(1040, 0.5, "sine", 0.05)
    out[:len(seg)] += seg
    return reverb(out)


def sfx_hover():
    n = int(0.08 * SR)
    return sine(1200, n) * env(n, 0.002, 0.075) * 0.05


def main():
    print("Synthesizing audio assets...")
    write_wav("music_menu.wav", make_menu_music())
    write_wav("music_game.wav", make_game_music())
    for name, fn in [
        ("sfx_tether_fire", sfx_tether_fire),
        ("sfx_tether_attach", sfx_tether_attach),
        ("sfx_tether_release", sfx_tether_release),
        ("sfx_pickup", sfx_pickup),
        ("sfx_deposit", sfx_deposit),
        ("sfx_boost", sfx_boost),
        ("sfx_hit", sfx_hit),
        ("sfx_flare", sfx_flare),
        ("sfx_warning", sfx_warning),
        ("sfx_game_over", sfx_game_over),
        ("sfx_new_best", sfx_new_best),
        ("ui_click", sfx_ui),
        ("ui_hover", sfx_hover),
    ]:
        write_wav(name + ".wav", fn())
    print("Done.")


if __name__ == "__main__":
    main()