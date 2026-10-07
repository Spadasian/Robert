#!/usr/bin/env python3
"""Generates the placeholder sound effects, music loops and ambience for Kurotsuki: Endless Night.

Run it from the project folder:   python3 tools/audio/generate_audio.py
It needs numpy and scipy, and ffmpeg (only for the .ogg music/ambience; without ffmpeg they stay .wav).
Output: audio/sfx/*.wav, audio/music/*.ogg, audio/ambience/*.ogg

The game (AudioManager.gd) loads sounds by file name, so a real sound can replace a placeholder by dropping a file
with the same name next to it (an .ogg wins over a .wav). Everything here is synthesized, nothing is sampled.
"""
import os
import shutil
import subprocess
import wave

import numpy as np
from scipy import signal

SR = 22050
rng = np.random.default_rng(7)
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
AMBIENCE_DIR = os.path.join(ROOT, "audio", "ambience")


# ------------------------------------------------------------------ building blocks

def tt(duration):
    return np.arange(int(SR * duration)) / SR


def noise(duration):
    return rng.standard_normal(int(SR * duration))


def env(duration, attack=0.002, decay=0.1):
    t = tt(duration)
    return np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-t / max(decay, 1e-4))


def sine(freq, duration):
    return np.sin(2 * np.pi * freq * tt(duration))


def sweep(f0, f1, duration):
    n = int(SR * duration)
    freq = np.geomspace(f0, f1, n)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def bandpass(x, lo, hi):
    sos = signal.butter(2, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, f):
    return signal.sosfilt(signal.butter(2, f, btype="low", fs=SR, output="sos"), x)


def highpass(x, f):
    return signal.sosfilt(signal.butter(2, f, btype="high", fs=SR, output="sos"), x)


def whoosh(duration, f0, f1, peak_at=0.4):
    """Noise whose pitch glides from f0 to f1 (a swish)."""
    t = tt(duration)
    out = np.zeros_like(t)
    centers = np.geomspace(f0, f1, 8)
    for i, c in enumerate(centers):
        band = bandpass(noise(duration), c * 0.6, min(c * 1.6, SR / 2 - 100))
        tp = duration * (0.15 + 0.7 * i / (len(centers) - 1))
        out += band * np.exp(-(((t - tp) / (duration * 0.16)) ** 2))
    shape = np.minimum(t / (duration * peak_at * 0.5), 1.0) * np.minimum((duration - t) / (duration * 0.4), 1.0)
    return out * np.clip(shape, 0, 1)


def pluck(freq, duration, decay=0.994):
    """Karplus-Strong plucked string (koto / shamisen-like)."""
    n = int(SR * duration)
    period = int(round(SR / freq))
    excitation = np.zeros(n)
    burst = lowpass(rng.uniform(-1, 1, period), 6000)
    excitation[:period] = burst
    a = np.zeros(period + 2)
    a[0] = 1.0
    a[period] = -0.5 * decay
    a[period + 1] = -0.5 * decay
    return signal.lfilter([1.0], a, excitation)


def reverb(x, seconds=1.2, wet=0.25):
    n = int(SR * seconds)
    ir = noise(seconds) * np.exp(-np.arange(n) / (SR * seconds / 4.0))
    ir = lowpass(ir, 4000)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet_signal = signal.fftconvolve(x, ir)[: len(x)]
    return x * (1 - wet) + wet_signal * wet * 2.0


def mix_into(dest, src, start_seconds, gain=1.0):
    start = int(start_seconds * SR)
    end = min(start + len(src), len(dest))
    if start < len(dest):
        dest[start:end] += src[: end - start] * gain


def normalize(x, peak=0.8):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def fade_edges(x, ms=4):
    n = int(SR * ms / 1000)
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())


def save_sfx(name, x, peak=0.8):
    write_wav(os.path.join(SFX_DIR, name + ".wav"), fade_edges(normalize(x, peak)))


def save_loop(folder, name, x, peak=0.7):
    """Writes an .ogg (or a .wav when ffmpeg is missing)."""
    wav_path = os.path.join(folder, name + ".wav")
    write_wav(wav_path, normalize(x, peak))
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "4",
                        os.path.join(folder, name + ".ogg")], check=True)
        os.remove(wav_path)


def make_loop(x, length, fade=0.6):
    """x is `length + fade` long. The tail is cross-faded onto the start so the loop has no click."""
    n, f = int(SR * length), int(SR * fade)
    out = x[:n].copy()
    u = np.linspace(0, 1, f)
    out[:f] = out[:f] * np.sin(u * np.pi / 2) + x[n:n + f] * np.cos(u * np.pi / 2)
    return out


def midi(note):
    return 440.0 * 2 ** ((note - 69) / 12)


# ------------------------------------------------------------------ sound effects

def build_sfx():
    save_sfx("slash", whoosh(0.2, 3800, 800))
    save_sfx("slash_enemy", whoosh(0.22, 2500, 500) + 0.3 * sweep(200, 90, 0.22) * env(0.22, 0.003, 0.08))
    save_sfx("hit", sweep(240, 60, 0.14) * env(0.14, 0.001, 0.05)
             + 0.7 * highpass(noise(0.14), 900) * env(0.14, 0.0005, 0.02))
    save_sfx("hurt", np.tanh(2.5 * (sweep(170, 45, 0.3) * env(0.3, 0.002, 0.1)
                                     + 0.5 * bandpass(noise(0.3), 300, 2200) * env(0.3, 0.002, 0.07))))
    save_sfx("enemy_death", sweep(320, 70, 0.5) * env(0.5, 0.002, 0.16)
             + 0.5 * lowpass(noise(0.5), 900) * env(0.5, 0.01, 0.2))
    save_sfx("dash", whoosh(0.28, 500, 2600, 0.5))
    n = 0.38
    rise = sweep(300, 1500, n) * np.linspace(0.1, 1, int(SR * n)) ** 2
    shimmer = sweep(600, 3000, n) * np.linspace(0, 1, int(SR * n)) ** 3 * 0.4
    save_sfx("iaijutsu_charge", rise + shimmer)
    ring = sum(sine(f, 0.4) * env(0.4, 0.001, 0.12) * a for f, a in [(2200, 0.5), (3300, 0.3), (4400, 0.2)])
    save_sfx("iaijutsu_strike", highpass(noise(0.4), 2200) * env(0.4, 0.001, 0.05) + ring
             + 0.6 * sweep(900, 200, 0.4) * env(0.4, 0.001, 0.06))
    save_sfx("kaeshi_stance", sine(220, 0.25) * env(0.25, 0.01, 0.07) + 0.4 * sine(440, 0.25) * env(0.25, 0.01, 0.05), 0.6)
    clang = sum(sine(800 * r, 0.7) * env(0.7, 0.001, d) * a
                for r, d, a in [(1.0, 0.25, 1.0), (2.76, 0.18, 0.6), (5.4, 0.12, 0.4), (8.93, 0.08, 0.3)])
    save_sfx("kaeshi_counter", clang + 0.6 * highpass(noise(0.7), 1500) * env(0.7, 0.0005, 0.03))
    d = 1.1
    rumble = lowpass(noise(d), 140) * np.linspace(0.2, 1, int(SR * d)) * 3
    rise = sweep(70, 520, d) * np.linspace(0, 1, int(SR * d)) ** 2
    hit = np.zeros(int(SR * d))
    mix_into(hit, sweep(180, 40, 0.5) * env(0.5, 0.001, 0.15) * 1.5, d - 0.5)
    save_sfx("ultimate_start", rumble + 0.6 * rise + hit)
    save_sfx("ultimate_tick", whoosh(0.13, 3000, 1000), 0.5)

    def tone(freq, dur, decay=0.08):
        return (sine(freq, dur) + 0.3 * sine(freq * 2, dur)) * env(dur, 0.002, decay)

    gold = np.zeros(int(SR * 0.3))
    mix_into(gold, tone(988, 0.15, 0.04), 0.0)
    mix_into(gold, tone(1319, 0.2, 0.07), 0.07)
    save_sfx("gold", gold, 0.6)
    buy = gold.copy()
    mix_into(buy, sweep(300, 120, 0.1) * env(0.1, 0.001, 0.03), 0.0, 0.7)
    save_sfx("buy", buy, 0.7)
    relic = np.zeros(int(SR * 1.1))
    for i, f in enumerate([880, 1047, 1319, 1760]):
        mix_into(relic, tone(f, 0.6, 0.18), 0.1 * i)
    mix_into(relic, highpass(noise(0.8), 5000) * env(0.8, 0.2, 0.2), 0.2, 0.1)
    save_sfx("relic", relic, 0.7)
    up = np.zeros(int(SR * 0.7))
    for i, f in enumerate([659, 784, 988]):
        mix_into(up, tone(f, 0.4, 0.12), 0.08 * i)
    save_sfx("upgrade", up, 0.7)
    clear = np.zeros(int(SR * 1.2))
    mix_into(clear, tone(587, 0.9, 0.3), 0.0)
    mix_into(clear, tone(880, 1.0, 0.35), 0.18)
    save_sfx("room_clear", clear, 0.6)
    save_sfx("door", sweep(140, 55, 0.4) * env(0.4, 0.003, 0.12) + 0.5 * lowpass(noise(0.4), 500) * env(0.4, 0.05, 0.12), 0.7)
    save_sfx("arrow", whoosh(0.2, 2800, 1600) + 0.4 * sine(540, 0.2) * env(0.2, 0.001, 0.03), 0.6)
    save_sfx("shuriken", whoosh(0.13, 4500, 2500), 0.55)
    blink = sweep(1400, 250, 0.18) * env(0.18, 0.002, 0.07) + 0.4 * highpass(noise(0.18), 3000) * env(0.18, 0.001, 0.05)
    save_sfx("blink", blink, 0.6)
    save_sfx("boss_slash", whoosh(0.32, 1800, 300) + 0.7 * sweep(160, 50, 0.32) * env(0.32, 0.003, 0.1))
    boom = sweep(95, 32, 0.9) * env(0.9, 0.002, 0.3) * 1.4 + 0.6 * lowpass(noise(0.9), 320) * env(0.9, 0.002, 0.22)
    save_sfx("boom", np.tanh(boom * 1.5))
    d = 1.5
    t = tt(d)
    growl = signal.sawtooth(2 * np.pi * np.cumsum(70 * (1 + 0.25 * np.sin(2 * np.pi * 9 * t)) / SR))
    growl = lowpass(growl, 700) + 0.6 * lowpass(noise(d), 600)
    save_sfx("roar", np.tanh(1.6 * growl) * np.minimum(t / 0.25, 1) * np.minimum((d - t) / 0.5, 1))
    save_sfx("boss_death", np.concatenate([np.tanh(boom * 1.2)[: int(SR * 0.7)], lowpass(noise(1.0), 400) * env(1.0, 0.01, 0.4)]))
    save_sfx("ui_click", sine(1500, 0.05) * env(0.05, 0.001, 0.012) + 0.3 * highpass(noise(0.05), 3000) * env(0.05, 0.0005, 0.006), 0.5)
    win = np.zeros(int(SR * 2.2))
    for i, f in enumerate([440, 554, 659, 880, 1109]):
        mix_into(win, pluck(f, 1.4, 0.997), 0.16 * i)
    save_sfx("victory", reverb(win, 1.2, 0.3), 0.8)
    lose = np.zeros(int(SR * 2.6))
    for i, f in enumerate([330, 294, 262, 220]):
        mix_into(lose, pluck(f, 1.6, 0.997), 0.4 * i)
    save_sfx("defeat", reverb(lose, 1.5, 0.35), 0.8)


# ------------------------------------------------------------------ music and ambience

IN_SCALE = [0, 1, 5, 7, 8]  # "In" scale: root, b2, 4, 5, b6


def scale_note(root_midi, degree, octave=0):
    return root_midi + IN_SCALE[degree % 5] + 12 * (degree // 5 + octave)


def pad(freqs, duration, cutoff=600, lfo=0.1):
    t = tt(duration)
    out = np.zeros_like(t)
    for f in freqs:
        for detune in (0.997, 1.003):
            out += signal.sawtooth(2 * np.pi * f * detune * t)
    out = lowpass(out, cutoff)
    return out * (0.7 + 0.3 * np.sin(2 * np.pi * lfo * t))


def taiko(strength=1.0, pitch=110):
    return (sweep(pitch * 1.6, pitch * 0.5, 0.5) * env(0.5, 0.001, 0.14) * strength
            + 0.35 * lowpass(noise(0.5), 400) * env(0.5, 0.001, 0.05) * strength)


def build_music():
    # --- menu: slow and sparse
    bpm, bars, beat = 60, 8, 1.0
    length = bars * 4 * beat
    fade = 0.8
    track = np.zeros(int(SR * (length + fade + 2)))
    chords = [[110, 165, 220], [87.3, 130.8, 174.6]]
    for b in range(bars):
        mix_into(track, pad(chords[(b // 4) % 2], 4 * beat + 1.0, 500, 0.1) * np.hanning(int(SR * (4 * beat + 1.0))) ** 0.5, b * 4 * beat, 0.18)
    plucks = np.zeros_like(track)
    for b in range(bars):
        for k in range(int(rng.integers(2, 4))):
            note = scale_note(57, int(rng.integers(0, 8)))
            mix_into(plucks, pluck(midi(note), 2.4, 0.996), b * 4 * beat + k * 1.5 + float(rng.uniform(0, 0.4)), 0.7)
    track += reverb(plucks, 1.6, 0.4) * 0.5
    for b in range(0, bars, 2):
        mix_into(track, taiko(0.7, 80), b * 4 * beat, 0.45)
    save_loop(MUSIC_DIR, "music_menu", make_loop(track, length, fade))

    # --- run: steady, a riff on plucks and soft drums
    bpm, bars = 100, 12
    beat = 60.0 / bpm
    length = bars * 4 * beat
    track = np.zeros(int(SR * (length + fade + 2)))
    for b in range(bars):
        mix_into(track, pad([110, 165] if (b // 4) % 2 == 0 else [98, 147], 4 * beat + 0.5, 450, 0.15)
                 * np.hanning(int(SR * (4 * beat + 0.5))) ** 0.5, b * 4 * beat, 0.16)
    plucks = np.zeros_like(track)
    riff = [0, None, 2, None, 3, 2, None, 0]
    for b in range(bars):
        shift = 0 if (b // 2) % 2 == 0 else 1
        for step, degree in enumerate(riff):
            if degree is None:
                continue
            note = scale_note(57, degree + shift)
            mix_into(plucks, pluck(midi(note), 0.9, 0.993), (b * 4 + step * 0.5) * beat, 0.55)
    track += reverb(plucks, 1.0, 0.25)
    for b in range(bars):
        for pos, strength in [(0, 1.0), (1.5, 0.5), (2, 0.8), (3.5, 0.4)]:
            mix_into(track, taiko(strength, 90), (b * 4 + pos) * beat, 0.4)
        for step in range(8):
            mix_into(track, highpass(noise(0.05), 6000) * env(0.05, 0.001, 0.012), (b * 4 + step * 0.5) * beat, 0.08)
    save_loop(MUSIC_DIR, "music_run", make_loop(track, length, fade))

    # --- boss: fast, heavy drums and sharp stabs, root D
    bpm, bars = 140, 16
    beat = 60.0 / bpm
    length = bars * 4 * beat
    track = np.zeros(int(SR * (length + fade + 2)))
    for b in range(bars):
        mix_into(track, np.tanh(2 * pad([73.4, 110], 4 * beat + 0.4, 700, 0.2))
                 * np.hanning(int(SR * (4 * beat + 0.4))) ** 0.5, b * 4 * beat, 0.2)
    plucks = np.zeros_like(track)
    for b in range(bars):
        for step in range(16):
            if (step % 4 == 0) or (b >= 8 and step % 2 == 0):
                degree = [0, 0, 3, 2, 0, 1, 3, 4][(step + b) % 8]
                mix_into(plucks, pluck(midi(scale_note(50, degree)), 0.5, 0.99), (b * 4 + step * 0.25) * beat, 0.6)
        if b % 2 == 0:
            for degree in (0, 1, 3):  # dissonant stab: root, b2, 5th
                mix_into(plucks, pluck(midi(scale_note(62, degree)), 1.2, 0.995), b * 4 * beat, 0.5)
    track += reverb(plucks, 0.9, 0.2)
    for b in range(bars):
        for step in range(16):
            strength = 1.0 if step % 4 == 0 else (0.55 if step % 2 == 0 else 0.0)
            if b % 4 == 3 and step >= 12:
                strength = 0.7  # a roll at the end of every fourth bar
            if strength > 0:
                mix_into(track, taiko(strength, 75 if step % 4 == 0 else 100), (b * 4 + step * 0.25) * beat, 0.45)
    save_loop(MUSIC_DIR, "music_boss", make_loop(track, length, fade))


def build_ambience():
    length, fade = 24.0, 1.0
    n = int(SR * (length + fade))
    t = np.arange(n) / SR
    wind = bandpass(rng.standard_normal(n), 150, 900)
    wind *= 0.5 + 0.5 * (0.6 * np.sin(2 * np.pi * 0.07 * t) + 0.4 * np.sin(2 * np.pi * 0.13 * t + 1.0))
    hum = lowpass(rng.standard_normal(n), 90) * 2.0
    crickets = np.zeros(n)
    pos = 0.5
    while pos < length + fade - 1.0:
        burst = int(SR * rng.uniform(0.4, 0.9))
        tb = np.arange(burst) / SR
        chirp = np.sin(2 * np.pi * 4300 * tb) * (np.sin(2 * np.pi * 22 * tb) > 0.2) * np.hanning(burst)
        crickets[int(pos * SR): int(pos * SR) + burst] += chirp[: n - int(pos * SR)] * 0.05
        pos += rng.uniform(1.2, 3.0)
    save_loop(AMBIENCE_DIR, "ambience_night", make_loop(wind * 0.7 + hum * 0.4 + crickets, length, fade), 0.6)


if __name__ == "__main__":
    print("Sound effects...")
    build_sfx()
    print("Music...")
    build_music()
    print("Ambience...")
    build_ambience()
    print("Done. Files are in", os.path.join(ROOT, "audio"))
