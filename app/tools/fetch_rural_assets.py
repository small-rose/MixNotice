"""fix6 音频更新：
1) wind 重制：换成「Wind sounds 2020-05-10 1625.mp3」（CC BY-SA 4.0），
   自动挑选高频占比最低的 60s 窗口（= 叶噪最少的纯风段），并低通 2.4kHz 去掉枝叶沙沙声；
2) 新增田园组：dog-bark 狗叫 / chicken 鸡叫 / goose 鹅叫 / pond 池塘；
3) 新增鸟种：bird-cuckoo 杜鹃 / bird-sparrow 麻雀 / bird-nightingale 夜莺(CC0)。
授权信息合并进 docs/音频素材授权清单.csv（按音源 ID 更新，不动其他行）。
用法：python tools/fetch_rural_assets.py [--only id1,id2]
"""
import csv
import importlib.util
import os
import re
import subprocess
import sys
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("fa", os.path.join(HERE, "fetch_audio_assets.py"))
fa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fa)  # 复用 file_info/download/duration/process 与常量

SRC = fa.SRC
OUT = fa.OUT
FFMPEG = fa.FFMPEG

# id -> (中文名, Commons 文件名, 额外滤镜)
PICKS = {
    "wind": ("风", "File:Wind sounds 2020-05-10 1625.mp3", "lowpass=f=2400"),
    "dog-bark": ("狗叫", "File:Barking dog in Rome.ogg", ""),
    "chicken": ("鸡叫", "File:Chickens demanding food.ogg", ""),
    "goose": ("鹅叫", "File:Canada Geese (Branta canadensis) (W1CDR0001421 BD11).ogg", ""),
    "pond": ("池塘", "File:Ambient sound small pond with ducks in Berlin 2026-05-17.oga", ""),
    "bird-cuckoo": ("杜鹃", "File:Common Cuckoo (Cuculus canorus) (W1CDR0001463 BD1).ogg", ""),
    "bird-sparrow": ("麻雀", "File:House Sparrows chirping.ogg", ""),
    "bird-nightingale": ("夜莺", "File:Common Nightingale's song 2.ogg", ""),
}


def window_rms(src, start, dur, highpass):
    """返回 [start, start+dur] 窗口的 RMS level dB（highpass=True 时只统计 >3kHz）"""
    af = ("highpass=f=3000," if highpass else "lowpass=f=3000,") + "astats=metadata=1:reset=0"
    p = subprocess.run(
        [FFMPEG, "-v", "info", "-ss", str(start), "-t", str(dur), "-i", src, "-af", af, "-f", "null", "-"],
        capture_output=True, text=True)
    m = re.findall(r"RMS level dB:\s*(-?[\d.]+)", p.stderr)
    return float(m[-1]) if m else -120.0


def pick_steady_window(src, dur, win=60.0):
    """扫描前 5 分钟，返回高频占比最低（叶噪最少）且有足够能量的窗口起点"""
    best, best_score = 0.0, None
    limit = min(dur - win - 1, 600.0)
    starts = [s for s in range(0, int(limit) + 1, 30)] or [0]
    for s in starts:
        low = window_rms(src, s, win, highpass=False)
        high = window_rms(src, s, win, highpass=True)
        if low < -50:  # 几乎静音的窗口跳过
            continue
        score = high - low  # 越小 = 高频叶噪占比越低
        print(f"  窗口 {s:>4}s  low {low:6.1f}dB  high {high:6.1f}dB  score {score:6.1f}")
        if best_score is None or score < best_score:
            best, best_score = float(s), score
    print(f"  → 选用窗口起点 {best:.0f}s（score {best_score}）")
    return best


def process_ex(src, out_path, dur, extra="", start=None):
    """裁切 → (可选滤镜) → 响度归一 → 首尾 1s 交叉淡化 → AAC 128k 44.1k 立体声"""
    xf = 1.0
    if dur <= 0:
        raise RuntimeError(f"无法读取时长: {src}")
    if start is None:
        if dur < 62:
            start, target = 0.0, max(5.0, dur - xf)
        else:
            start, target = min(3.0, dur * 0.05), 60.0
    else:
        target = min(60.0, dur - start - xf)
    head = f"{extra}," if extra else ""
    chain = (
        f"[0:a]atrim={start}:{start + target + xf},asetpts=PTS-STARTPTS,"
        f"{head}loudnorm=I=-18:TP=-2:LRA=11,aresample=44100,"
        f"aformat=channel_layouts=stereo[src];"
        f"[src]asplit[main][head];"
        f"[head]atrim=0:{xf},asetpts=PTS-STARTPTS[h];"
        f"[main]atrim={xf}:{target + xf},asetpts=PTS-STARTPTS[m];"
        f"[m][h]acrossfade=d={xf}:c1=tri:c2=tri[out]"
    )
    subprocess.run([FFMPEG, "-y", "-v", "error", "-i", src, "-filter_complex", chain,
                    "-map", "[out]", "-c:a", "aac", "-b:a", "128k", "-ar", "44100", "-ac", "2",
                    out_path], check=True)
    return target


def merge_csv(rows_new):
    """按音源 ID 合并授权清单：替换同 ID 行，其余行原样保留"""
    path = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "音频素材授权清单.csv"))
    existing = []
    if os.path.exists(path):
        with open(path, encoding="utf-8-sig", newline="") as f:
            existing = list(csv.reader(f))
    header, body = existing[0], existing[1:]
    by_id = {r[0]: r for r in body if r}
    for r in rows_new:
        by_id[r[0]] = r
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(by_id.values())
    print(f"授权清单已更新：{path}（共 {len(by_id)} 项）")


def main():
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))

    os.makedirs(SRC, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    rows = []
    for sid, (cn, title, extra) in PICKS.items():
        if only and sid not in only:
            continue
        try:
            info = fa.file_info(title)
            if not info["url"]:
                print(f"[跳过] {sid}: 未取到文件地址")
                continue
            ext = os.path.splitext(urllib.parse.urlparse(info["url"]).path)[1] or ".bin"
            src = os.path.join(SRC, sid + ext)
            if not os.path.exists(src):
                print(f"[下载] {sid} ← {title} ({info['license']})")
                fa.download(info["url"], src)
            dur = fa.duration(src)
            out = os.path.join(OUT, sid + ".m4a")
            start = pick_steady_window(src, dur) if sid == "wind" else None
            length = process_ex(src, out, dur, extra=extra, start=start)
            size = os.path.getsize(out) // 1024
            print(f"[处理] {sid}.m4a  {dur:.1f}s → {length:.1f}s loop, {size}KB")
            note = f"裁切 {length:.0f}s + 响度归一 + 首尾 1s 交叉淡化"
            if extra:
                note += f" + {extra}"
            rows.append([sid, cn, f"{sid}.m4a", info["page"], re.sub("<[^>]+>", "", info["artist"])[:80],
                         info["license"], note])
        except Exception as e:  # noqa: BLE001
            print(f"[失败] {sid}: {e}", file=sys.stderr)
    if rows:
        merge_csv(rows)


if __name__ == "__main__":
    main()
