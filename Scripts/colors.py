#!/usr/bin/env python3
"""The color table in Colors/: the color codes Apple's two image CDNs know for each iPhone, iPad, iPod touch,
HomePod and Apple Watch, matched to the colors' names.

    python3 Scripts/colors.py add URL [NAME] ...   add the codes in image addresses copied from an account's device list
    python3 Scripts/colors.py issue                the same for the GitHub issue in $ISSUE_BODY (used by the workflow)
    python3 Scripts/colors.py report               rewrite Colors/README.md from Colors/colors.json
    python3 Scripts/colors.py scan [PRODUCT ...]   rescan products from AppleDB and both CDNs (slow)

Needs Pillow and NumPy (pip install pillow numpy).

How codes are confirmed: on recent models, the account CDN's image under `27.0` is byte for byte Find My's image of
the same color, so an account code is matched to Find My's numeric code by comparing the two images' hashes. Color
values are shared across models (the same blue is `47ade5` on every iPhone that has code 9), so each new value is
tried on every product.
"""
import hashlib, html, io, itertools, json, os, re, sys, urllib.error, urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "Colors", "colors.json")
PAGE = os.path.join(ROOT, "Colors", "README.md")
FINDMY = "https://statici.icloud.com/fmipmobile/deviceImages-9.0"
ACCOUNT = "https://appleid.cdn-apple.com/static/deviceImages-27.0"
FILE = "online-infobox__3x.png"
# The account CDN answers 403 to clients it doesn't know, curl's and Python's default User-Agents among them.
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
URL_RE = re.compile(r"https://appleid\.cdn-apple\.com/static/deviceImages-\d+\.\d+/([A-Za-z]+)/"
                    r"([A-Za-z]+\d+,\d+)-([0-9A-Za-z-]+)/online-[a-z]+(?:__[23]x)?\.png")


# Fetching

class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None  # Find My redirects missing images to apple.com

_opener = urllib.request.build_opener(_NoRedirect)

def fetch(url):
    """The image at url, or None."""
    for _ in range(3):
        try:
            with _opener.open(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=30) as r:
                return r.read() if r.headers.get("Content-Type", "").startswith("image/") else None
        except urllib.error.HTTPError:
            return None
        except Exception:
            continue
    return None

def digest(data):
    return hashlib.sha1(data).hexdigest()[:10] if data else None

def findmy_url(p, code):
    return f"{FINDMY}/{p['class']}/{p['rep']}-{code}-0/{FILE}"

def account_url(p, code):
    return f"{ACCOUNT}/{p['class']}/{p['rep']}-{code}/{FILE}"

def edge_color(data):
    """The median color of the pixels just inside the image's outline: the device's frame."""
    import numpy as np
    from PIL import Image
    px = np.asarray(Image.open(io.BytesIO(data)).convert("RGBA")).astype(np.int64)
    big = 1 << 30
    depth = np.where(px[:, :, 3] > 200, big, 0)
    for d in range(1, 5):
        low = depth < d
        near = np.zeros_like(low)
        near[1:-1, 1:-1] = low[1:-1, :-2] | low[1:-1, 2:] | low[:-2, 1:-1] | low[2:, 1:-1]
        depth = np.where((depth == big) & near, d, depth)
    rim = px[(depth == 2) | (depth == 3)]
    if not len(rim):
        return None
    return "".join("%02x" % int(np.sort(rim[:, i])[len(rim) // 2]) for i in range(3))


# Data

def load():
    with open(DATA) as f:
        return json.load(f)

def save(data):
    with open(DATA, "w") as f:
        json.dump(data, f, indent=1, sort_keys=True, ensure_ascii=False)
        f.write("\n")

def code_key(code):
    return [int(x) for x in code.split("-")]

def watch_names(data):
    """Account color names to try on watches: materials and colors in Apple's abbreviations, and names seen."""
    materials = ["Alm", "Alu", "Al", "Stl", "Steel", "SS", "StSt", "Ttm", "Ttn", "Ti", "Titanium", "Ceramic", "Cer", "Gld", ""]
    colors = ["SpGry", "Gld", "RsGld", "Slvr", "SpBlk", "Blk", "Wht", "Grph", "Mdnt", "Strlt", "Ntrl", "JtBlk", "Gry",
              "Silver", "Gold", "Black", "White", "Blue", "Green", "Red", "Pink", "Midnight", "Starlight", "Graphite",
              "Natural", "Yellow", "Orange", "Purple", "SpaceBlack", "SpaceGray", "JetBlack", "RoseGold", "Rose", "Slate",
              "Sky", "SkyBlue", "Clover", "Product", "ProductRed", "Bronze", "Brown", "Grey", "Gray"]
    return sorted({m + c for m in materials for c in colors} | set(data["palette"]["watch"]))

def glasses(data, p):
    """The cover glass colors to try with a product's housings: those of its Find My fronts (1 dark, 2 light)."""
    fronts = sorted({c.split("-")[0] for c in p["findmy"]}) or ["1", "2"]
    return sorted({g for f in fronts for g in data["palette"]["glass"].get(f, data["palette"]["glass"]["1"])})

def product_for(data, model):
    return next((p for p in data["products"].values() if model in p["ids"]), None)

def probe_account(data, p, codes, pool):
    """Fetches the product's account images for codes; records the ones that exist. Returns the codes added."""
    known = {d: c for c, d in p["findmy"].items()}
    fetched = pool.map(lambda c: (c, fetch(account_url(p, c))), [c for c in codes if c not in p["account"]])
    added = []
    for code, image in fetched:
        if image is None:
            continue
        match = known.get(digest(image))
        p["account"][code] = match
        if match is None:
            p["edge"][code] = edge_color(image)
        added.append(code)
    return added

def account_codes(data, p, housings=None, names=None):
    if p["family"] == "Apple Watch":
        return names if names is not None else watch_names(data)
    housings = housings if housings is not None else data["palette"]["housing"]
    # HomePod mini's colored models have the same value on both sides (`47ade5-47ade5`).
    return [f"{g}-{h}" for g in glasses(data, p) for h in housings] + [f"{h}-{h}" for h in housings]


# Adding contributed codes

def clean_name(text):
    """A color name from free text: letters, digits and a few separators, at most 40 characters."""
    return re.sub(r"[^\w ()&+'./-]", "", text, flags=re.UNICODE).strip(" -:")[:40] or None

def add(data, entries, source=None):
    """Adds (url, name) entries. Returns a Markdown report of what each one showed."""
    lines = []
    with ThreadPoolExecutor(16) as pool:
        for url, name in entries:
            m = URL_RE.search(url)
            if not m:
                lines.append(f"- `{url[:120]}`: not an image address from an Apple Account's device list")
                continue
            family, model, code = m.groups()
            if family != "Watch":
                code = code.lower()
            p = product_for(data, model)
            if p is None:
                lines.append(f"- `{model}` `{code}`: this model isn't in the table yet; a maintainer will add it")
                continue
            new = code not in p["account"]
            if new:
                if p["family"] == "Apple Watch":
                    if code not in watch_names(data):
                        data["palette"]["watch"].append(code)
                else:
                    glass, housing = code.split("-")
                    if housing not in data["palette"]["housing"]:
                        data["palette"]["housing"].append(housing)
                    front = "2" if glass in data["palette"]["glass"]["2"] else "1"
                    if glass not in data["palette"]["glass"][front]:
                        data["palette"]["glass"][front].append(glass)
                probe_account(data, p, [code], pool)
            if code not in p["account"]:
                lines.append(f"- {p['name']} `{code}`: Apple's server has no image for it under `27.0`")
                continue
            # The new value may be the same color on other models.
            spread = []
            if new:
                for q in data["products"].values():
                    if q is p or (q["family"] == "Apple Watch") != (p["family"] == "Apple Watch"):
                        continue
                    codes = [code] if p["family"] == "Apple Watch" else account_codes(data, q, housings=[code.split("-")[1]])
                    if probe_account(data, q, codes, pool):
                        spread.append(q["name"])
            sample = {"model": model, "code": code}
            if name:
                sample["name"] = name
            if source:
                sample["source"] = source
            old = next((s for s in data["samples"] if s["model"] == model and s["code"] == code), None)
            if old:
                old.update(sample)
            else:
                data["samples"].append(sample)
            fm = p["account"][code]
            line = f"- {p['name']} `{code}`" + (f" ({name})" if name else "")
            line += f": the same image as Find My's `{fm}`" if fm else ": an image Find My doesn't have"
            line += "; new to the table" if new else "; already in the table, now confirmed on a device"
            if spread:
                line += f". The same value also works on {len(spread)} other products: {', '.join(spread)}"
            lines.append(line)
    data["samples"].sort(key=lambda s: (s["model"], s["code"]))
    return "\n".join(lines)

def parse_entries(text):
    """(url, name) pairs from lines that hold an image address, optionally followed by the color's name."""
    entries = []
    for line in text.splitlines():
        m = re.search(r"https://\S+", line)
        if m:
            rest = (line[:m.start()] + " " + line[m.end():]).strip(" `<>-:")
            entries.append((m.group().strip("`<>()"), clean_name(rest) if rest else None))
    return entries


# Scanning

APPLEDB = "https://raw.githubusercontent.com/littlebyteorg/appledb/main"
FAMILIES = {"iPhone": "iPhone", "iPad": "iPad", "iPod touch": "iPod", "HomePod": "HomePod", "Apple Watch": "Watch"}

def product_name(name, family):
    if family == "Apple Watch":
        name = re.sub(r"\s*\((GPS[^)]*|\d+mm[^)]*)\)", "", name)
        return re.sub(r",\s*GPS[^)]*\)", ")", name).strip()
    name = re.sub(r"\s*\((GPS[^)]*|\d+mm|China[^)]*|CDMA|GSM|Global|Wi-Fi[^)]*|Cellular)\)", "", name)
    name = re.sub(r",\s*GPS[^)]*\)", ")", name)
    return re.sub(r"\s+(Wi-Fi \+ Cellular|Wi-Fi|Cellular)(\s*\([^)]*\))?$", "", name).strip()

def appledb_products():
    req = urllib.request.Request("https://api.github.com/repos/littlebyteorg/appledb/git/trees/main?recursive=1",
                                 headers={"User-Agent": UA})
    tree = json.load(urllib.request.urlopen(req, timeout=60))["tree"]
    paths = [t["path"] for t in tree if t["path"].endswith(".json")
             and t["path"].split("/")[:2][-1] in FAMILIES and t["path"].startswith("deviceFiles/")]
    def get(path):
        req = urllib.request.Request(f"{APPLEDB}/{urllib.request.quote(path)}", headers={"User-Agent": UA})
        return path, json.load(urllib.request.urlopen(req, timeout=60))
    products = {}
    with ThreadPoolExecutor(16) as pool:
        for path, r in pool.map(get, paths):
            family = path.split("/")[1]
            released = r.get("released"); released = released[0] if isinstance(released, list) else released
            year = int(str(released)[:4]) if released else 0
            if year < 2013 or not r.get("colors"):
                continue
            ids = r.get("identifier"); ids = ids if isinstance(ids, list) else [ids]
            key = product_name(r["name"], family)
            p = products.setdefault(key, {"name": key, "family": family, "year": year, "ids": [], "colors": {}})
            p["ids"] += [i for i in ids if i and i not in p["ids"]]
            for c in r["colors"]:
                h = c.get("hex"); h = h[0] if isinstance(h, list) else h
                p["colors"].setdefault(c["name"], h)
    for p in products.values():
        p["ids"].sort(key=lambda i: [int(x) for x in re.findall(r"\d+", i)])
    return products

def scan(data, only):
    products = appledb_products()
    todo = [p for p in products.values() if not only or p["name"] in only]
    with ThreadPoolExecutor(24) as pool:
        for p in sorted(todo, key=lambda p: (p["family"], p["year"], p["name"])):
            p["rep"] = p["ids"][0]
            p["class"] = "HomePod" if p["rep"].startswith("AudioAccessory") else FAMILIES[p["family"]]
            ranges = [(1, 45), (2, 45)] if p["family"] == "Apple Watch" else [(1, 41), (2, 41), (3, 41)]
            # HomePod mini numbers its colors on both sides (`9-9`), past the usual 1 to 3.
            codes = [f"{f}-{n}" for f, top in ranges for n in range(top)] + [f"{n}-{n}" for n in range(4, 41)]
            images = dict(pool.map(lambda c: (c, fetch(findmy_url(p, c))), codes))
            p["findmy"], p["account"], p["edge"] = {}, {}, {}
            for c in codes:
                if images[c] and digest(images[c]) not in p["findmy"].values():
                    p["findmy"][c] = digest(images[c])
                    p["edge"][c] = edge_color(images[c])
            probe_account(data, p, account_codes(data, p), pool)
            old = data["products"].get(p["name"])
            if old:  # keep codes added by hand or from samples that the palette doesn't cover
                for code, fm in old["account"].items():
                    p["account"].setdefault(code, fm)
                    if code in old["edge"]:
                        p["edge"].setdefault(code, old["edge"][code])
            data["products"][p["name"]] = p
            save(data)
            print(f"{p['name']:<45} {p['rep']:<12} {len(p['findmy'])} Find My, {len(p['account'])} account", flush=True)


# The page

def lab(h):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(int(h[i:i + 2], 16)) for i in (0, 2, 4))
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    return 116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))

def distance(a, b):
    return sum((p - q) ** 2 for p, q in zip(lab(a), lab(b))) ** 0.5

# Words a color's name likely contains, by Find My's color number and by the account's housing hex.
NUMBER_WORDS = {1: "black graphite gray grey midnight", 2: "white silver starlight", 3: "gold",
                4: "pink rose gold natural", 5: "jet natural desert", 6: "red burgundy", 7: "yellow", 8: "coral orange",
                9: "blue ultramarine glacier sierra pacific sky", 11: "purple green", 12: "green purple",
                13: "gold", 14: "black", 17: "purple lavender", 18: "green teal sage mint", 26: "blue", 31: "pink",
                32: "starlight silver"}
HEX_WORDS = {"302f34": "black graphite gray grey midnight", "dcdede": "white silver starlight", "d6c8b9": "gold",
             "e5bdb5": "pink rose gold natural desert", "47ade5": "blue ultramarine glacier sierra pacific sky",
             "ccc7d7": "purple lavender", "a2d7c2": "green teal sage mint", "d7d9d8": "silver white",
             "dadcdb": "silver white", "e1ccb5": "gold", "e1ccb7": "gold", "d4c5b3": "gold", "e4c1b9": "rose pink",
             "99989b": "gray grey black", "b4b5b9": "gray grey black", "b9b7ba": "gray grey black",
             "aeb1b8": "gray grey black", "c6353f": "red"}
WATCH_MATERIAL = [("Titanium", "titanium"), ("Ceramic", "ceramic"), ("Stl", "stainless"), ("Steel", "stainless"),
                  ("Alm", ""), ("Alu", "")]
WATCH_COLOR = {"JetBlack": "jet black", "RsGld": "rose gold", "RoseGold": "rose gold", "SpGry": "space gray",
               "SpBlk": "space black", "SpaceBlack": "space black", "Gld": "gold", "Gold": "gold",
               "Natural": "natural", "Ntrl": "natural", "Slvr": "silver", "Silver": "silver", "Gray": "space gray",
               "Pink": "pink", "Red": "red", "Blue": "blue", "Green": "green", "White": "white", "Black": "black",
               "Midnight": "midnight", "Starlight": "starlight", "Slate": "slate"}

def words(v, watch):
    """The housing hex names the color. When several account codes show one image, some are the model's fallback
    image; Find My's number then picks the right one (numbers mean the same color on most iPhones, not on iPads)."""
    by_hex = set()
    for a in v["account"]:
        by_hex |= set(HEX_WORDS.get(a.split("-")[-1], "").split())
    by_number = set(NUMBER_WORDS.get(code_key(v["findmy"])[1], "").split()) if v["findmy"] and not watch else set()
    if len(v["account"]) > 1 and by_hex & by_number:
        return by_hex & by_number
    return by_hex or by_number or None

def watch_fit(code, name):
    """Whether a watch's account code such as TitaniumGold names a color such as "Titanium - Gold"; None if unsure."""
    n = name.lower()
    prefix = next((k for k, _ in WATCH_MATERIAL if code.startswith(k)), None)
    if prefix is None or code[len(prefix):] not in WATCH_COLOR:
        return None
    material, color = dict(WATCH_MATERIAL)[prefix], WATCH_COLOR[code[len(prefix):]]
    if material and material not in n:
        return False
    if not material and any(m in n for m in ("titanium", "ceramic", "stainless")):
        return False
    # Newer aluminum watches call space gray midnight.
    return color in n or (color == "space gray" and ("gray" in n or "midnight" in n))

def cost(name, v, p, samples):
    watch = p["family"] == "Apple Watch"
    for a in v["account"]:
        if (p["name"], a) in samples and samples[(p["name"], a)]:
            return -1000 if samples[(p["name"], a)].lower() == name.lower() else 1000
    if watch and v["account"]:
        fits = [watch_fit(a, name) for a in v["account"]]
        if True in fits:
            return v["d"][name] * 0.1
        if False in fits:
            return v["d"][name] + 100
    w = words(v, watch)
    fits = w is None or any(x in name.lower() for x in w)
    return v["d"][name] + (0 if fits else 60) - (8 if fits and v["account"] else 0)

def assign(names, variants):
    """The cheapest one-to-one match of color names to variants: exhaustive when small, greedy otherwise."""
    idx = range(len(variants))
    if len(variants) <= 8:
        if len(names) > len(variants):
            options = ((sub, idx) for sub in itertools.permutations(names, len(variants)))
        else:
            options = ((names, perm) for perm in itertools.permutations(idx, len(names)))
        best = min(options, key=lambda o: sum(variants[j]["c"][n] for n, j in zip(*o)), default=None)
        return dict(zip(*best)) if best else {}
    out = {}
    for _, n, j in sorted((variants[j]["c"][n], n, j) for n in names for j in idx):
        if n not in out and j not in out.values():
            out[n] = j
    return out

def cell(v):
    """A variant's Find My and account cells."""
    return "%s | %s" % ("`%s`" % v["findmy"] if v["findmy"] else "", ", ".join("`%s`" % a for a in v["account"]))

def report(data):
    samples = {}
    for s in data["samples"]:
        p = product_for(data, s["model"])
        if p:
            samples[(p["name"], s["code"])] = s.get("name")
    order = ["iPhone", "iPad", "iPod touch", "HomePod", "Apple Watch"]
    totals = {"✅": 0, "🟡": 0, "❌": 0}
    sections, gaps = [], {}

    def want(p, name, findmy, renders_differ):
        # iPhones share Find My's numbers across models, so one code names one color; other lines go by model.
        line = ("iPhone" if p["family"] == "iPhone" else "other") + (" differ" if renders_differ else "")
        key, label = (findmy or "", f"{p['name']} {name}") if p["family"] == "iPhone" else (p["name"], name)
        gaps.setdefault(line, {}).setdefault(key, []).append(label)
    for p in sorted(data["products"].values(), key=lambda p: (order.index(p["family"]), p["year"], p["name"])):
        watch = p["family"] == "Apple Watch"
        byfm = {}
        for a, fm in p["account"].items():
            if fm:
                byfm.setdefault(fm, []).append(a)
        vs = [{"findmy": fm, "account": sorted(byfm.get(fm, [])), "url": findmy_url(p, fm), "edge": p["edge"].get(fm)}
              for fm in sorted(p["findmy"], key=code_key)]
        vs += [{"findmy": None, "account": [a], "url": account_url(p, a), "edge": p["edge"].get(a)}
               for a, fm in sorted(p["account"].items()) if fm is None]
        for v in vs:
            v["d"] = {n: distance(v["edge"], h) if v["edge"] and h else 50 for n, h in p["colors"].items()}
            v["c"] = {n: cost(n, v, p, samples) for n in p["colors"]}
        # Names go to Find My's colors; account codes with no Find My match are aliases, unless there are none.
        pool = [j for j, v in enumerate(vs) if v["findmy"]] or list(range(len(vs)))
        match = {n: pool[j] for n, j in assign(list(p["colors"]), [vs[j] for j in pool]).items()}
        renders_differ = any(v["findmy"] is None for v in vs) and any(v["findmy"] for v in vs)
        rows = [f"\n### {html.escape(p['name'])}\n\n`{'`, `'.join(p['ids'])}`\n",
                "| Color | Find My | Account | | Image |", "|---|---|---|---|---|"]
        for name in p["colors"]:
            j = match.get(name)
            if j is None:
                totals["❌"] += 1
                want(p, name, None, False)
                rows.append(f"| {name} | | | ❌ | |")
                continue
            v = vs[j]
            if v["account"]:
                mark = "✅📱" if any((p["name"], a) in samples for a in v["account"]) else "✅"
                url = account_url(p, v["account"][0])
                totals["✅"] += 1
            else:
                mark, url = "🟡", v["url"]
                totals["🟡"] += 1
                want(p, name, v["findmy"], renders_differ)
            rows.append(f"| {name} | {cell(v)} | {mark} | <img src=\"{url}\" height=\"60\"> |")
        for j, v in enumerate(vs):
            if j not in match.values():
                rows.append(f"| *other* | {cell(v)} | | <img src=\"{v['url']}\" height=\"60\"> |")
        sections.append("\n".join(rows))

    def gap_table(line, header):
        entries = gaps.get(line, {})
        keys = sorted(entries, key=lambda k: (not k, -len(entries[k]), k))
        out = [f"| {header} | Colors |", "|---|---|"]
        out += ["| %s | %s |" % (("`%s`" % k if header == "Find My code" else k) if k else "none found",
                                 ", ".join(entries[k])) for k in keys]
        return "\n".join(out)

    page = f"""# Colors

Every color of every iPhone, iPad, iPod touch, HomePod and Apple Watch since 2013, with the codes Apple's image servers know it by. `AppleDevice(model, color:)` takes either code.

- **Find My**: the `DeviceColor-DeviceEnclosureColor` numbers. Find My's images show no wallpaper.
- **Account**: what Apple Account device lists use, and the only way to get the OS's wallpaper: cover glass and housing hex for iPhone, iPad, iPod touch and HomePod, a material and color name for Apple Watch.

✅ both codes known · ✅📱 confirmed on a real device · 🟡 the account code is missing · ❌ neither server has the color

**{totals['✅']}** ✅ · **{totals['🟡']}** 🟡 · **{totals['❌']}** ❌

Color names come from [AppleDB](https://github.com/littlebyteorg/appledb) and are matched to codes by the color of the device's frame in the image, so check them against the pictures. Codes on real devices settle it.

## Wanted

Own one of these? [Send its image address](../CONTRIBUTING.md#add-a-color); it takes a minute. An iPhone color usually fills in every model with the same Find My code.

**iPhone**, by Find My code:

{gap_table("iPhone", "Find My code")}

**iPad, iPod touch, HomePod, Apple Watch**:

{gap_table("other", "Model")}

<details>
<summary>Older models whose two servers draw the color differently, so the codes can't be matched by image</summary>

{gap_table("iPhone differ", "Find My code")}

{gap_table("other differ", "Model")}

</details>

## Products
{"".join(sections)}

---

Generated by `python3 Scripts/colors.py report` from [`colors.json`](colors.json).
"""
    with open(PAGE, "w") as f:
        f.write(page)
    return totals


def main():
    args = sys.argv[1:]
    command = args.pop(0) if args else "help"
    if command == "report":
        print(report(load()))
    elif command == "add":
        entries = []
        for a in args:
            if a.startswith("https://"):
                entries.append((a, None))
            elif entries:
                entries[-1] = (entries[-1][0], clean_name(a))
        data = load()
        print(add(data, entries))
        save(data)
        report(data)
    elif command == "issue":
        # Run by .github/workflows/color.yml. The issue's text arrives in the environment, never in a shell command.
        data = load()
        entries = parse_entries(os.environ.get("ISSUE_BODY", ""))
        number = os.environ.get("ISSUE_NUMBER")
        result = add(data, entries[:20], source=f"#{number}" if number else None) if entries else \
            "No image address found. Copy it from account.apple.com [like this](https://github.com/%s/blob/main/CONTRIBUTING.md#add-a-color)." \
            % os.environ.get("GITHUB_REPOSITORY", "Eirperuier/AppleDeviceImages")
        save(data)
        report(data)
        out = os.environ.get("SUMMARY")
        if out:
            with open(out, "w") as f:
                f.write(result + "\n")
        print(result)
    elif command == "scan":
        data = load()
        scan(data, set(args))
        report(data)
    else:
        print(__doc__)

if __name__ == "__main__":
    main()
