"""下载指定 Commons 音源 → 处理为 60s 无缝循环 AAC（128kbps, 44.1kHz 立体声）
处理链：裁切 → 响度归一(loudnorm I=-18) → 首尾 1s 交叉淡化 → AAC
授权信息同步写入 docs/音频素材授权清单.csv
用法：python tools/fetch_audio_assets.py
"""
import csv
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "MixNoticeApp/1.0 (audio asset pipeline)"}
SRC = "assets_src"
OUT = "assets/audio"
FFMPEG = r"E:/Apps/ffmpeg-n4.3.1-20-win64/bin/ffmpeg"
FFPROBE = r"E:/Apps/ffmpeg-n4.3.1-20-win64/bin/ffprobe"

# 音源 ID -> (中文名, Commons 文件名)
PICKS = {
    "rain-light": ("小雨", "File:Rain drops (Gravity Sound).wav"),
    "rain-heavy": ("大雨", "File:Rain delay (Gravity Sound).wav"),
    "thunder": ("雷声", "File:Rhumphries - rbh-thunder-storm.ogg"),
    "wind": ("风", "File:Leaves in the wind (Gravity Sound).wav"),
    "stream": ("溪流", "File:433589 jackthemurray stream-river-water-up-close.wav"),
    "waves": ("海浪", "File:Sea waves.wav"),
    "birds": ("鸟鸣", "File:20210321 0900 Birdsong Bourne Lincolnshire.mp3"),
    "campfire": ("篝火", "File:Campfire sound ambience.ogg"),
    "forest": ("森林", "File:Forest ambience (Gravity Sound).wav"),
    "night-crickets": ("夜晚虫鸣", "File:Night original format.wav"),
    "cafe": ("咖啡馆", "File:Restaurant ambience.ogg"),
    "keyboard": ("键盘敲击", "File:Computer keyboard.ogg"),
    "chimes": ("风铃", "File:Windglockenspiel.Koshi.ogg"),
}

NOISE = {  # 白/粉/棕噪音：ffmpeg 合成，无版权问题
    "noise-white": ("白噪音", "0.28"),
    "noise-pink": ("粉噪音", "0.32"),
    "noise-brown": ("棕噪音", "0.45"),
}


def http_json(url, retries=5):
    import time
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1.5 * (i + 1))
    raise last


def file_info(title):
    q = urllib.parse.urlencode({
        "action": "query", "format": "json", "titles": title,
        "prop": "imageinfo", "iiprop": "url|size|extmetadata",
    })
    data = http_json(f"{API}?{q}")
    page = next(iter((data.get("query") or {}).get("pages", {}).values()), {})
    info = (page.get("imageinfo") or [{}])[0]
    meta = info.get("extmetadata") or {}
    return {
        "url": info.get("url"),
        "license": (meta.get("LicenseShortName") or {}).get("value", ""),
        "artist": (meta.get("Artist") or {}).get("value", "").replace("<", " ‹"),
        "page": f"https://commons.wikimedia.org/wiki/{urllib.parse.quote(title.replace(' ', '_'))}",
    }


def download(url, dest, retries=6):
    """Python urllib 下载 + 重试（本机 curl 会被代理卡住 TLS 握手）。"""
    import time
    if os.path.exists(dest) and os.path.getsize(dest) > 10000:
        return
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=120) as r, open(dest, "wb") as f:
                while True:
                    chunk = r.read(1 << 20)
                    if not chunk:
                        break
                    f.write(chunk)
            if os.path.getsize(dest) > 1000:
                return
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(2 + i)
    raise RuntimeError(f"下载失败: {last}")


def duration(path):
    out = subprocess.run(
        [FFPROBE, "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", path],
        capture_output=True, text=True).stdout.strip()
    try:
        return float(out)
    except ValueError:
        return 0.0


def process(src, out_path, dur):
    """裁切 60s（短素材用全长）→ 响度归一 → 首尾 1s 交叉淡化 → AAC 128k"""
    xf = 1.0
    if dur <= 0:
        raise RuntimeError(f"无法读取时长: {src}")
    if dur < 62:
        start = 0.0
        target = max(5.0, dur - xf)  # 短素材：全长做循环
    else:
        start = min(3.0, dur * 0.05)
        target = 60.0
    chain = (
        f"[0:a]atrim={start}:{start + target + xf},asetpts=PTS-STARTPTS,"
        f"loudnorm=I=-18:TP=-2:LRA=11,aresample=44100,"
        f"aformat=channel_layouts=stereo[src];"
        f"[src]asplit[main][head];"
        f"[head]atrim=0:{xf},asetpts=PTS-STARTPTS[h];"
        f"[main]atrim={xf}:{target + xf},asetpts=PTS-STARTPTS[m];"
        f"[m][h]acrossfade=d={xf}:c1=tri:c2=tri[out]"
    )
    cmd = [FFMPEG, "-y", "-v", "error", "-i", src, "-filter_complex", chain,
           "-map", "[out]", "-c:a", "aac", "-b:a", "128k", "-ar", "44100", "-ac", "2", out_path]
    subprocess.run(cmd, check=True)
    return target


def gen_noise(color, amp, out_path):
    cmd = [FFMPEG, "-y", "-v", "error", "-f", "lavfi",
           "-i", f"anoisesrc=color={color}:amplitude={amp}:sample_rate=44100:duration=60",
           "-af", "aformat=channel_layouts=stereo,volume=1.0",
           "-c:a", "aac", "-b:a", "128k", "-ar", "44100", "-ac", "2", out_path]
    subprocess.run(cmd, check=True)


def main():
    os.makedirs(SRC, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    rows = []

    for sid, (cn, title) in PICKS.items():
        try:
            info = file_info(title)
            if not info["url"]:
                print(f"[跳过] {sid}: 未取到文件地址")
                continue
            ext = os.path.splitext(urllib.parse.urlparse(info["url"]).path)[1] or ".bin"
            src = os.path.join(SRC, sid + ext)
            print(f"[下载] {sid} ← {title} ({info['license']})")
            download(info["url"], src)
            dur = duration(src)
            out = os.path.join(OUT, sid + ".m4a")
            length = process(src, out, dur)
            size = os.path.getsize(out) // 1024
            print(f"[处理] {sid}.m4a  {dur:.1f}s → {length:.1f}s loop, {size}KB")
            rows.append([sid, cn, f"{sid}.m4a", info["page"], info["artist"][:80],
                         info["license"], f"裁切 {length:.0f}s + 响度归一 + 首尾 1s 交叉淡化"])
        except Exception as e:  # noqa: BLE001
            print(f"[失败] {sid}: {e}", file=sys.stderr)

    for sid, (cn, amp) in NOISE.items():
        out = os.path.join(OUT, sid + ".m4a")
        try:
            gen_noise(sid.replace("noise-", ""), amp, out)
            print(f"[生成] {sid}.m4a (ffmpeg anoisesrc 合成)")
            rows.append([sid, cn, f"{sid}.m4a", "本机合成（ffmpeg anoisesrc）",
                         "MixNoticeApp", "无需授权（算法生成）", "算法合成 60s"])
        except Exception as e:  # noqa: BLE001
            print(f"[失败] {sid}: {e}", file=sys.stderr)

    os.makedirs("../docs", exist_ok=True)
    with open("../docs/音频素材授权清单.csv", "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["音源ID", "音源名", "文件", "来源页面", "作者", "授权", "处理说明"])
        w.writerows(rows)
    print(f"\n完成 {len(rows)}/16，授权清单 → docs/音频素材授权清单.csv")


if __name__ == "__main__":
    main()
