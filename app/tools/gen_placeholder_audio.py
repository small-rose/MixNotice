"""开发期占位音频合成：16 个无缝循环 WAV（约 8s，44.1kHz 单声道 16-bit）。
正式素材采购到位后直接覆盖 assets/audio/ 下同名文件即可。
用法：python tools/gen_placeholder_audio.py <输出目录>
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

SR = 44100
DUR = 8.0
N = int(SR * DUR)

def write_wav(path, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.72 / peak if peak > 0.72 else 1.0
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))

def lowpass(xs, alpha):
    out, y = [], 0.0
    for x in xs:
        y += alpha * (x - y)
        out.append(y)
    return out

def loop_safe(xs, fade=0.25):
    """首尾交叉淡化保证无缝循环：尾部 fade 秒与头部叠加。"""
    nf = int(SR * fade)
    head = xs[:nf]
    for i in range(nf):
        w = i / nf
        xs[-nf + i] = xs[-nf + i] * (1 - w) + head[i] * w
    return xs

rng = random.Random(42)

def zeros():
    return [0.0] * N

def noise():
    return [rng.uniform(-1, 1) for _ in range(N)]

def sine(freq, amp_fn=lambda t: 1.0):
    return [amp_fn(i / SR) * math.sin(2 * math.pi * freq * i / SR) for i in range(N)]

def env_swell(period_s, base=0.55, depth=0.45):
    """慢波动包络（海浪/风）"""
    return [base + depth * (0.5 + 0.5 * math.sin(2 * math.pi * t / period_s - math.pi / 2))
            for t in [i / SR for i in range(N)]]

def mul(a, b):
    return [x * y for x, y in zip(a, b)]

def mix(*layers):
    n = len(layers[0])
    return [sum(l[i] for l in layers) for i in range(n)]

def gen():
    out = {}
    wn = noise()

    rain = mul(lowpass(wn, 0.18), env_swell(5, 0.7, 0.2))
    drops = zeros()
    for _ in range(60):
        t0 = rng.randint(0, N - 200)
        for j in range(200):
            drops[t0 + j] += 0.12 * math.exp(-j / 40) * math.sin(2 * math.pi * (900 + rng.randint(-200, 200)) * j / SR)
    out["rain-light"] = mix(rain, drops)

    out["rain-heavy"] = mix(mul(lowpass(wn, 0.35), env_swell(4, 0.8, 0.2)), drops)

    thunder = zeros()
    for start in (int(1.2 * SR), int(5.0 * SR)):
        ln = int(1.8 * SR)
        for j in range(ln):
            if start + j < N:
                env = math.exp(-j / (0.35 * SR)) * (0.5 + 0.5 * math.sin(2 * math.pi * 7 * j / SR))
                thunder[start + j] += 0.9 * env * math.sin(2 * math.pi * (55 + 20 * math.sin(j / 800)) * j / SR)
    out["thunder"] = mix(lowpass(noise(), 0.04), [x * 0.15 for x in thunder], thunder)

    wind = mul(lowpass(noise(), 0.06), env_swell(6, 0.5, 0.5))
    out["wind"] = wind

    babble = mul(lowpass(noise(), 0.5), env_swell(2.5, 0.6, 0.3))
    bubbles = zeros()
    for _ in range(80):
        t0 = rng.randint(0, N - 600)
        f = rng.uniform(500, 1400)
        for j in range(600):
            if t0 + j < N:
                bubbles[t0 + j] += 0.1 * math.exp(-j / 120) * math.sin(2 * math.pi * f * (1 + j / 3000) * j / SR)
    out["stream"] = mix(babble, bubbles)

    waves = mul(lowpass(noise(), 0.25), env_swell(4.0, 0.15, 0.85))
    out["waves"] = waves

    bird_bg = [x * 0.12 for x in lowpass(noise(), 0.08)]
    chirps = zeros()
    for _ in range(14):
        t0 = rng.randint(0, N - 4000)
        f0 = rng.uniform(2200, 3800)
        for j in range(4000):
            if t0 + j < N:
                sweep = f0 * (1 + 0.25 * math.sin(2 * math.pi * 9 * j / SR))
                chirps[t0 + j] += 0.16 * math.exp(-j / 900) * math.sin(2 * math.pi * sweep * j / SR)
    out["birds"] = mix(bird_bg, chirps)

    fire = [x * 0.5 for x in lowpass(noise(), 0.03)]
    crackles = zeros()
    for _ in range(90):
        t0 = rng.randint(0, N - 800)
        for j in range(800):
            if t0 + j < N:
                crackles[t0 + j] += rng.uniform(-0.5, 0.5) * math.exp(-j / 60)
    out["campfire"] = mix(fire, [x * 0.5 for x in crackles])

    out["forest"] = mix([x * 0.8 for x in wind], [x * 0.5 for x in chirps], [x * 0.3 for x in bird_bg])

    trill = zeros()
    for k in range(0, N, int(0.9 * SR)):
        for j in range(int(0.45 * SR)):
            if k + j < N:
                f = 900 + 60 * math.sin(2 * math.pi * 28 * j / SR)
                trill[k + j] += 0.12 * math.exp(-j / (0.4 * SR)) * math.sin(2 * math.pi * f * j / SR)
    out["night-crickets"] = mix([x * 0.1 for x in lowpass(noise(), 0.05)], trill)

    out["noise-white"] = [x * 0.6 for x in noise()]
    out["noise-pink"] = [x * 1.6 for x in lowpass(noise(), 0.25)]
    out["noise-brown"] = [x * 2.2 for x in lowpass(noise(), 0.05)]

    murmur = mul(lowpass(noise(), 0.12), env_swell(3, 0.6, 0.25))
    clinks = zeros()
    for _ in range(6):
        t0 = rng.randint(0, N - 3000)
        f = rng.choice([2100, 2600, 3300])
        for j in range(3000):
            if t0 + j < N:
                clinks[t0 + j] += 0.08 * math.exp(-j / 500) * math.sin(2 * math.pi * f * j / SR)
    out["cafe"] = mix(murmur, clinks)

    kb = zeros()
    for _ in range(26):
        t0 = rng.randint(0, N - 900)
        for j in range(900):
            if t0 + j < N:
                kb[t0 + j] += rng.uniform(-0.4, 0.4) * math.exp(-j / 45)
    out["keyboard"] = mix([x * 0.08 for x in lowpass(noise(), 0.1)], [x * 0.7 for x in kb])

    chime = zeros()
    notes = [523.25, 587.33, 659.25, 783.99, 880.0]
    for k, f in enumerate(notes * 3):
        t0 = int(k * 1.1 * SR)
        if t0 >= N:
            break
        for j in range(int(2.2 * SR)):
            if t0 + j < N:
                chime[t0 + j] += 0.14 * math.exp(-j / (0.7 * SR)) * (
                    math.sin(2 * math.pi * f * j / SR) + 0.4 * math.sin(2 * math.pi * f * 2.76 * j / SR))
    out["chimes"] = mix([x * 0.06 for x in lowpass(noise(), 0.2)], chime)

    return out

def main():
    dest = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/audio")
    dest.mkdir(parents=True, exist_ok=True)
    for sid, samples in gen().items():
        write_wav(dest / f"{sid}.wav", loop_safe(samples))
        print(f"  {sid}.wav")

if __name__ == "__main__":
    main()
