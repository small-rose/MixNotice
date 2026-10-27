"""在 Wikimedia Commons 检索音源候选（含授权信息），输出 JSON 供筛选。
用法：python tools/find_commons_audio.py > candidates.json
"""
import json
import sys
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "MixNoticeApp/1.0 (audio asset research; contact: dev@mixnotice.local)"}

# 音源 ID -> 检索关键词（英文更易命中）
QUERIES = {
    "rain-light": "rain sound",
    "rain-heavy": "heavy rain audio",
    "thunder": "thunder audio",
    "wind": "wind sound",
    "stream": "stream creek sound",
    "waves": "ocean waves sound",
    "birds": "birdsong audio",
    "campfire": "campfire sound",
    "forest": "forest ambience audio",
    "night-crickets": "crickets night audio",
    "cafe": "coffee shop ambience",
    "keyboard": "keyboard typing sound",
    "chimes": "wind chimes audio",
}

ALLOWED = ("cc0", "public domain", "cc by", "cc-by")


def get(url, retries=4):
    import time
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1.5 * (i + 1))
    raise last


def search(term, limit=12):
    q = urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search",
        "gsrsearch": f"filetype:audio {term}", "gsrnamespace": 6, "gsrlimit": limit,
        "prop": "imageinfo", "iiprop": "url|size|extmetadata|mediatype",
    })
    data = get(f"{API}?{q}")
    pages = (data.get("query") or {}).get("pages") or {}
    out = []
    for p in pages.values():
        info = (p.get("imageinfo") or [{}])[0]
        meta = info.get("extmetadata") or {}
        lic = (meta.get("LicenseShortName") or {}).get("value", "")
        if not any(k in lic.lower() for k in ALLOWED):
            continue
        out.append({
            "title": p.get("title"),
            "url": info.get("url"),
            "size": info.get("size"),
            "duration": (meta.get("Length") or {}).get("value"),
            "license": lic,
            "artist": (meta.get("Artist") or {}).get("value", "")[:120],
            "desc": (meta.get("ImageDescription") or {}).get("value", "")[:150],
            "page": f"https://commons.wikimedia.org/wiki/{urllib.parse.quote((p.get('title') or '').replace(' ', '_'))}",
        })
    return out


def main():
    import time
    fallback = {
        "rain-light": ["rain audio", "rainfall sound"],
        "rain-heavy": ["storm rain sound", "downpour audio"],
        "thunder": ["thunderstorm sound", "thunder rumble"],
        "wind": ["wind ambience", "wind blowing audio"],
        "stream": ["creek sound", "river flowing audio", "brook audio"],
        "waves": ["sea waves audio", "surf sound", "beach waves"],
        "birds": ["bird song recording", "birds chirping audio"],
        "campfire": ["fire crackling audio", "bonfire sound"],
        "forest": ["forest soundscape", "woodland ambience"],
        "night-crickets": ["cricket chirping audio", "insects night sound"],
        "cafe": ["restaurant ambience audio", "crowd murmur audio", "coffeehouse sound"],
        "keyboard": ["typing sound", "computer keyboard audio"],
        "chimes": ["wind chime sound", "bells wind audio"],
    }
    result = {}
    for sid, term in QUERIES.items():
        found = []
        for t in [term] + fallback.get(sid, []):
            try:
                found = search(t)
            except Exception as e:  # noqa: BLE001
                print(f"[{sid}] '{t}' 失败: {e}", file=sys.stderr)
                continue
            if found:
                break
            time.sleep(0.8)
        result[sid] = found
        print(f"[{sid}] {len(found)} 个合规候选", file=sys.stderr)
        time.sleep(0.6)
    json.dump(result, sys.stdout, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
