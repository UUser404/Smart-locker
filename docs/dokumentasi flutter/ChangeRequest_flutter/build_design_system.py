#!/usr/bin/env python3
"""Generate every platform artifact from tokens/tokens.json.

Outputs
  tokens/tokens.css          CSS variables (plain HTML / Flutter Web host page / customer web)
  tokens/tokens.figma.json   Tokens Studio format (import via the Tokens Studio plugin in Figma)
  flutter/app_tokens.dart    Dart constants (used by flutter/app_theme.dart)
  screens/admin-*.svg        Admin web (1440x800) and admin mobile (360x800) mockups

Run:  python3 build_design_system.py
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
T = json.loads((ROOT / "tokens" / "tokens.json").read_text())
(ROOT / "screens").mkdir(exist_ok=True)
(ROOT / "flutter").mkdir(exist_ok=True)


# ------------------------------------------------------------------ helpers
def kebab(s):
    return re.sub(r"([A-Z])", lambda m: "-" + m.group(1).lower(), s)


def cap(s):
    return s[0].upper() + s[1:]


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


# ------------------------------------------------------------------ CSS
def build_css():
    L = ["/* GENERATED from tokens/tokens.json by build_design_system.py - do not edit by hand. */", ":root {"]
    for g, items in T["color"].items():
        for k, v in items.items():
            L.append(f"  --color-{kebab(g)}-{kebab(k)}: {v};")
    for k, v in T["space"].items():
        L.append(f"  --space-{k}: {v}px;")
    for k, v in T["radius"].items():
        L.append(f"  --radius-{kebab(k)}: {v}px;")
    for k, v in T["size"].items():
        L.append(f"  --size-{kebab(k)}: {v}px;")
    for k, v in T["motion"].items():
        L.append(f"  --motion-{kebab(k)}: {v}ms;")
    for k, v in T["opacity"].items():
        L.append(f"  --opacity-{kebab(k)}: {v};")
    for k, v in T["shadow"].items():
        L.append(f"  --shadow-{kebab(k)}: {v};")
    L.append(f"  --font-family: {T['font']['family']};")
    for k, v in T["type"].items():
        n = kebab(k)
        L.append(f"  --type-{n}-size: {v['size']}px;")
        L.append(f"  --type-{n}-weight: {v['weight']};")
        L.append(f"  --type-{n}-line: {v['line']}px;")
        if "letterSpacing" in v:
            L.append(f"  --type-{n}-spacing: {v['letterSpacing']}px;")
    for state, kind in T["semantic"]["state"].items():
        for part in ("main", "container", "tint", "border", "text", "strong"):
            L.append(f"  --state-{state}-{part}: var(--color-{kind}-{part});")
    L.append("}")
    L.append("")
    L.append("/* breakpoints (use in @media): medium >= 600px, expanded >= 1024px */")
    (ROOT / "tokens" / "tokens.css").write_text("\n".join(L) + "\n")


# ------------------------------------------------------------------ Tokens Studio (Figma)
def build_figma():
    def leaf(v, t):
        return {"value": str(v), "type": t}

    g = {"color": {}, "space": {}, "radius": {}, "size": {}, "motion": {}, "font": {}, "type": {}}
    for grp, items in T["color"].items():
        g["color"][grp] = {k: leaf(v, "color") for k, v in items.items()}
    g["space"] = {k: leaf(v, "spacing") for k, v in T["space"].items()}
    g["radius"] = {k: leaf(v, "borderRadius") for k, v in T["radius"].items()}
    g["size"] = {k: leaf(v, "sizing") for k, v in T["size"].items()}
    g["motion"] = {k: leaf(v, "other") for k, v in T["motion"].items()}
    g["font"]["family"] = leaf(T["font"]["family"].split(",")[0], "fontFamilies")
    for k, v in T["type"].items():
        g["type"][k] = {
            "value": {
                "fontFamily": T["font"]["family"].split(",")[0],
                "fontWeight": str(v["weight"]),
                "fontSize": str(v["size"]),
                "lineHeight": str(v["line"]),
                "letterSpacing": str(v.get("letterSpacing", 0)),
            },
            "type": "typography",
        }
    out = {"global": g, "$themes": [], "$metadata": {"tokenSetOrder": ["global"]}}
    (ROOT / "tokens" / "tokens.figma.json").write_text(json.dumps(out, indent=2) + "\n")


# ------------------------------------------------------------------ Dart
def build_dart():
    def hexc(h):
        return "0xFF" + h[1:].upper()

    L = [
        "// GENERATED from tokens/tokens.json by build_design_system.py - do not edit by hand.",
        "import 'package:flutter/painting.dart';",
        "",
        "abstract final class AppColors {",
    ]
    for g, items in T["color"].items():
        for k, v in items.items():
            L.append(f"  static const Color {g}{cap(k)} = Color({hexc(v)});")
    L += ["}", "", "abstract final class AppSpace {"]
    for k, v in T["space"].items():
        L.append(f"  static const double s{k} = {v};")
    L += ["}", "", "abstract final class AppRadius {"]
    for k, v in T["radius"].items():
        L.append(f"  static const double {k} = {v};")
    L += ["}", "", "abstract final class AppSize {"]
    for k, v in T["size"].items():
        L.append(f"  static const double {k} = {v};")
    L += ["}", "", "abstract final class AppMotion {"]
    for k, v in T["motion"].items():
        L.append(f"  static const Duration {k} = Duration(milliseconds: {v});")
    L += ["}", "", "abstract final class AppOpacity {"]
    for k, v in T["opacity"].items():
        L.append(f"  static const double {k} = {v};")
    L += ["}", "", "abstract final class AppType {"]
    for k, v in T["type"].items():
        ls = f", letterSpacing: {v['letterSpacing']}" if "letterSpacing" in v else ""
        L.append(
            f"  static const TextStyle {k} = TextStyle(fontFamily: 'Inter', fontFamilyFallback: ['Roboto'], "
            f"fontSize: {v['size']}, fontWeight: FontWeight.w{v['weight']}, height: {round(v['line'] / v['size'], 3)}{ls});"
        )
    L += ["}", ""]
    (ROOT / "flutter" / "app_tokens.dart").write_text("\n".join(L))


# ------------------------------------------------------------------ SVG toolkit
C = T["color"]
N = C["neutral"]
R = T["radius"]
FONT = T["font"]["family"]
INK, BODY, MUTED, DIS = N["ink"], N["textBody"], N["textMuted"], N["textDisabled"]
BG, SURF, SURF2, FILL = N["bg"], N["surface"], N["surfaceMuted"], N["fillMuted"]
BORDER, BORDER2, INV, INV2 = N["border"], N["borderStrong"], N["inverse"], N["inverseRaised"]
WHITE, INVMUTED = N["onInverse"], N["onInverseMuted"]
PRI, PRIC = C["brand"]["primary"], C["brand"]["primaryContainer"]
K = {
    "success": C["success"],
    "info": C["info"],
    "warning": C["warning"],
    "danger": C["danger"],
    "neutral": {"main": MUTED, "container": FILL, "tint": SURF2, "border": BORDER, "text": BODY, "strong": INK},
}


class Doc:
    def __init__(self, w, h, name):
        self.w, self.h, self.name, self.p = w, h, name, []

    def add(self, s):
        self.p.append(s)

    def g(self, name):
        self.add(f'<g id="{esc(name)}">')

    def end(self):
        self.add("</g>")

    def rect(self, x, y, w, h, r=0, fill="none", stroke=None, sw=1):
        st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        rr = f' rx="{r}"' if r else ""
        self.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}"{rr} fill="{fill}"{st}/>')

    def card(self, x, y, w, h, r=None, fill=None, stroke=None, sw=1):
        r = R["card"] if r is None else r
        self.rect(x + sw / 2, y + sw / 2, w - sw, h - sw, r, fill or SURF, stroke or BORDER, sw)

    def top_round(self, x, y, w, h, r, fill):
        self.add(f'<path d="M{x} {y + r}Q{x} {y} {x + r} {y}H{x + w - r}Q{x + w} {y} {x + w} {y + r}V{y + h}H{x}Z" fill="{fill}"/>')

    def circle(self, cx, cy, r, fill="none", stroke=None, sw=1):
        st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        self.add(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"{st}/>')

    def line(self, x1, y1, x2, y2, stroke=None, sw=1):
        self.add(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke or BORDER}" stroke-width="{sw}"/>')

    def path(self, dd, stroke, sw=2, fill="none"):
        self.add(f'<path d="{dd}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>')

    def text(self, x, y, t, size=13, weight=400, fill=None, anchor="start", ls=None, raw=False):
        t = t if raw else esc(t)
        a = f' text-anchor="{anchor}"' if anchor != "start" else ""
        l = f' letter-spacing="{ls}"' if ls else ""
        self.add(f'<text x="{x}" y="{y}"{a}{l} font-family="{FONT}" font-size="{size}" font-weight="{weight}" fill="{fill or INK}">{t}</text>')

    def badge(self, x, y, label, kind, h=22, size=10, align="left", weight=800):
        k = K[kind]
        w = int(len(label) * size * 0.66 + 22)
        if align == "right":
            x = x - w
        self.rect(x, y, w, h, h / 2, fill=k["container"])
        self.text(x + w / 2, y + h / 2 + size * 0.36, label, size, weight, k["text"], "middle")
        return w

    def button(self, x, y, w, h, label, fill, tc, stroke=None, size=13, r=None, weight=800):
        self.rect(x, y, w, h, R["button"] if r is None else r, fill=fill, stroke=stroke)
        self.text(x + w / 2, y + h / 2 + size * 0.36, label, size, weight, tc, "middle")

    def chevron(self, x, y, color=None):
        self.path(f"M{x - 3} {y - 6}L{x + 3} {y}L{x - 3} {y + 6}", color or DIS, 2)

    def esp(self, x, y, name, ago, online=True, size=11):
        k = K["success" if online else "danger"]
        self.circle(x + 4, y - 4, 4, fill=k["main"])
        st = "Online" if online else "Offline"
        self.text(x + 14, y, f'{name} · <tspan font-weight="700" fill="{k["main"]}">{st}</tspan> · {ago}', size, 400, BODY, raw=True)

    def save(self, path):
        body = "\n".join(self.p)
        Path(path).write_text(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}" fill="none">\n'
            f'<g id="{esc(self.name)}">\n{body}\n</g>\n</svg>\n'
        )


def glyph(d, name, cx, cy, color, sw=1.8):
    G = {
        "grid": "".join(f'<rect x="{dx}" y="{dy}" width="6" height="6" rx="1.5"/>' for dx, dy in [(-8, -8), (2, -8), (-8, 2), (2, 2)]),
        "lock": '<rect x="-6" y="-1" width="12" height="9" rx="2"/><path d="M-3 -1V-4a3 3 0 0 1 6 0V-1"/>',
        "clock": '<circle r="8"/><path d="M0 -4V0L3 2"/>',
        "shield": '<path d="M0 -9L8 -6V0C8 5 4 8 0 10C-4 8 -8 5 -8 0V-6Z"/>',
        "users": '<circle cx="0" cy="-4" r="3.5"/><path d="M-7 8C-7 2 7 2 7 8"/>',
        "gear": '<circle r="2.5"/><circle r="7" stroke-dasharray="3 2.2"/>',
        "menu": '<path d="M-8 -5H8M-8 0H8M-8 5H8"/>',
        "download": '<path d="M0 -8V4M-5 0L0 5L5 0M-8 8H8"/>',
        "search": '<circle cx="-1.5" cy="-1.5" r="6"/><path d="M3 3L8 8"/>',
        "door": '<rect x="-5" y="-8" width="10" height="16" rx="2"/>',
        "x": '<path d="M-6 -6L6 6M6 -6L-6 6"/>',
        "bell": '<path d="M-6 4H6C4 3 4 0 4 -3A4 4 0 0 0 -4 -3C-4 0 -4 3 -6 4Z"/><path d="M-2 7H2"/>',
    }
    d.add(
        f'<g transform="translate({cx} {cy})" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" fill="none">{G[name]}</g>'
    )


# ------------------------------------------------------------------ shared mock data
SESSIONS = [
    ("#S-8492", "01", "Budi Santoso", "0812****7890", "10:00", "sekarang", "00:11:24", "Berjalan", "info"),
    ("#S-8491", "02", "Sinta Rahma", "0857****2201", "08:30", "09:12", "00:42:07", "Selesai", "success"),
    ("#S-8490", "01", "Rafi Pratama", "0813****5518", "08:02", "08:49", "00:47:12", "Selesai", "success"),
    ("#S-8489", "02", "Dewi Lestari", "0821****9034", "07:44", "08:15", "00:31:40", "Selesai", "success"),
    ("#S-8488", "01", "Ahmad Fauzi", "0896****1177", "07:10", "07:58", "00:48:03", "Selesai", "success"),
    ("#S-8487", "02", "Nadia Putri", "0812****6620", "23 Nov 16:20", "23 Nov 17:05", "00:45:11", "Selesai", "success"),
    ("#S-8486", "01", "Hasan Maulana", "0852****3345", "23 Nov 15:02", "23 Nov 16:30", "01:28:40", "Buka darurat", "danger"),
    ("#S-8485", "02", "Laila Zahra", "0813****7712", "23 Nov 14:10", "23 Nov 14:52", "00:42:30", "Resolve petugas", "warning"),
]

LOG = [
    ("10:05:12", "Sistem", "Pintu terbuka > 2 menit", "warning", "Locker 02", "Perhatian", "warning"),
    ("10:03:40", "Petugas A", "Buka darurat", "danger", "Locker 01", "Berhasil", "success"),
    ("10:00:02", "Sistem", "Sesi dimulai #S-8492", "info", "Locker 01", "Tercatat", "neutral"),
    ("09:58:15", "Admin (Anda)", "Lihat nomor telepon penuh", "neutral", "Locker 01", "Tercatat", "neutral"),
    ("09:41:30", "Petugas A", "Buka darurat", "danger", "Locker 02", "Gagal", "danger"),
    ("09:12:09", "Petugas B", "Resolve & kosongkan", "warning", "Locker 02", "Berhasil", "success"),
    ("08:55:44", "Sistem", "Perangkat offline 2 menit", "danger", "Locker 01", "Pulih", "success"),
    ("08:30:10", "Sistem", "Sesi dimulai #S-8491", "info", "Locker 02", "Tercatat", "neutral"),
]

EVENTS = [
    ("warning", "Locker 02 pintu terbuka > 2 menit", "10:05 · Sistem"),
    ("danger", "Buka darurat Locker 01", "10:03 · Petugas A · Lupa kode"),
    ("info", "Locker 01 disewa · Budi Santoso", "10:00 · Sesi #S-8492"),
    ("danger", "Buka darurat Locker 02 gagal", "09:41 · ESP32-02 tidak merespons"),
    ("success", "Locker 02 diselesaikan · Petugas B", "09:12 · Resolve & kosongkan"),
    ("danger", "ESP32-01 offline 2 menit", "08:55 · Sistem · sudah pulih"),
]


# ------------------------------------------------------------------ shells
NAV = [("Ringkasan", "grid"), ("Locker & Perangkat", "lock"), ("Riwayat Sewa", "clock"), ("Log Audit", "shield"), ("Petugas", "users"), ("Pengaturan", "gear")]


def web_shell(d, active):
    d.rect(0, 0, d.w, d.h, fill=BG)
    d.g("Sidebar")
    d.rect(0, 0, 240, d.h, fill=INV)
    d.rect(24, 22, 36, 36, 10, fill=PRI)
    glyph(d, "lock", 42, 40, WHITE)
    d.text(72, 38, "Smart Locker", 16, 800, WHITE)
    d.text(72, 54, "Admin Console", 11, 400, INVMUTED)
    y = 96
    for lab, gl in NAV:
        if lab == active:
            d.rect(12, y, 216, 44, 12, fill=PRI)
            c, w = WHITE, 800
        else:
            c, w = INVMUTED, 600
        glyph(d, gl, 38, y + 22, c)
        d.text(62, y + 27, lab, 14, w, c)
        y += 48
    d.line(16, 716, 224, 716, INV2)
    d.circle(40, 752, 18, fill=INV2)
    d.text(40, 757, "A", 14, 800, WHITE, "middle")
    d.text(68, 748, "Admin", 13, 700, WHITE)
    d.text(68, 764, "Administrator", 11, 400, INVMUTED)
    d.end()

    d.g("Topbar")
    d.rect(240, 0, d.w - 240, 64, fill=SURF)
    d.line(240, 64.5, d.w, 64.5, BORDER)
    d.text(272, 40, active, 20, 800)
    d.rect(1040, 16, 136, 32, 16, fill=FILL)
    d.text(1056, 36, "Unit STTI-01", 13, 600, BODY)
    d.path("M1156 30L1160 34L1164 30", MUTED, 1.8)
    s = K["success"]
    d.rect(1188, 18, 104, 28, 14, fill=s["container"])
    d.circle(1204, 32, 4, fill=s["main"])
    d.text(1214, 36.5, "2/2 Online", 12, 600, s["text"])
    d.circle(1330, 32, 18, fill=FILL)
    glyph(d, "bell", 1330, 32, BODY, 1.6)
    d.circle(1340, 22, 4, fill=K["danger"]["main"])
    d.circle(1380, 32, 18, fill=PRI)
    d.text(1380, 37, "A", 14, 800, WHITE, "middle")
    d.end()


def status_bar(d):
    d.text(20, 19, "10:11", 12, 600)
    d.rect(322, 11, 18, 9, 2, stroke=INK)
    d.rect(324, 13, 12, 5, 1, fill=INK)


def mobile_nav(d, active):
    items = [("Ringkasan", "grid"), ("Riwayat", "clock"), ("Log", "shield"), ("Menu", "menu")]
    d.g("Bottom Navigation")
    d.rect(0, 720, 360, 80, fill=SURF)
    d.line(0, 720.5, 360, 720.5, BORDER)
    step = 360 / len(items)
    for i, (lab, gl) in enumerate(items):
        cx = step * i + step / 2
        on = lab == active
        if on:
            d.rect(cx - 20, 728, 40, 30, 15, fill=PRIC)
        c = PRI if on else MUTED
        glyph(d, gl, cx, 743, c, 1.8)
        d.text(cx, 775, lab, 11, 700 if on else 600, c, "middle")
    d.end()


def online_pill(d, right, y):
    s = K["success"]
    w = 100
    d.rect(right - w, y, w, 28, 14, fill=s["container"])
    d.circle(right - w + 16, y + 14, 4, fill=s["main"])
    d.text(right - w + 26, y + 18.5, "2/2 Online", 12, 600, s["text"])


def m_section(d, y, title):
    d.text(16, y, title, 14, 800)


# ------------------------------------------------------------------ admin web screens
def w_ringkasan():
    d = Doc(1440, 800, "Admin Web - 01 Ringkasan")
    web_shell(d, "Ringkasan")
    wn, ws = K["warning"], K["danger"]

    d.g("Banner Perhatian")
    d.card(272, 88, 1136, 56, fill=wn["tint"], stroke=wn["border"])
    d.circle(304, 116, 16, fill=wn["container"])
    glyph(d, "door", 304, 116, wn["main"], 1.8)
    d.text(332, 112, "Locker 02 · pintu terbuka 06:12", 14, 800)
    d.text(332, 130, "Terbuka sejak 10:05 WIB · ESP32-02 online · petugas sudah diberi notifikasi", 12, 400, MUTED)
    d.button(1272, 100, 120, 32, "Lihat detail", wn["main"], WHITE, r=R["field"])
    d.end()

    d.g("KPI Cards")
    kpis = [
        ("Sewa hari ini", "5", "+2 dibanding kemarin", K["success"]["text"], INK, SURF, BORDER),
        ("Rata-rata durasi", "42 mnt", "dari 4 sesi selesai", MUTED, INK, SURF, BORDER),
        ("Kejadian perhatian", "2", "1 sedang berlangsung", wn["text"], wn["main"], wn["tint"], wn["border"]),
        ("Buka darurat", "2", "1 gagal · ESP32-02", ws["text"], ws["main"], SURF, BORDER),
    ]
    for i, (lab, val, sub, sc, vc, bg, bd) in enumerate(kpis):
        x = 272 + i * 288
        d.card(x, 160, 272, 96, fill=bg, stroke=bd)
        d.text(x + 20, 190, lab, 12, 600, MUTED)
        d.text(x + 20, 226, val, 30, 800, vc)
        d.text(x + 20, 244, sub, 11, 400, sc)
    d.end()

    d.g("Status Locker")
    d.text(272, 292, "Status locker", 15, 800)
    cards = [
        (272, "info", "01", "Budi Santoso · 0812****7890", "DISEWA", "00:11:24", K["info"]["main"], "durasi sewa", "ESP32-01", "1 dtk lalu", SURF, BORDER),
        (632, "warning", "02", "Tidak ada penyewa aktif", "PERHATIAN", "06:12", ws["main"], "pintu terbuka", "ESP32-02", "2 dtk lalu", wn["tint"], wn["border"]),
    ]
    for x, kind, num, sub, bl, big, bc, cap_, esp, ago, bg, bd in cards:
        k = K[kind]
        d.card(x, 304, 344, 176, fill=bg, stroke=bd)
        d.circle(x + 36, 340, 18, fill=k["container"])
        d.text(x + 36, 345, num, 13, 800, k["main"], "middle")
        d.text(x + 66, 337, f"Locker {num}", 15, 800)
        d.text(x + 66, 355, sub, 12, 400, MUTED)
        d.badge(x + 328, 326, bl, kind, align="right")
        d.text(x + 20, 410, big, 30, 800, bc)
        d.text(x + 20, 430, cap_, 12, 400, MUTED)
        d.line(x + 20, 444.5, x + 324, 444.5, BORDER)
        d.esp(x + 20, 468, esp, ago)
        d.button(x + 256, 452, 68, 28, "Detail", FILL, BODY, size=12, r=R["field"], weight=700)
    d.end()

    d.g("Kejadian Terbaru")
    d.card(992, 288, 416, 436)
    d.text(1016, 322, "Kejadian terbaru", 15, 800)
    d.text(1384, 322, "Lihat semua", 12, 700, PRI, "end")
    y = 340
    for i, (kind, title, sub) in enumerate(EVENTS):
        d.circle(1024, y + 28, 5, fill=K[kind]["main"])
        d.text(1044, y + 26, title, 13, 700)
        d.text(1044, y + 44, sub, 11, 400, MUTED)
        if i < len(EVENTS) - 1:
            d.line(1016, y + 56.5, 1384, y + 56.5, FILL)
        y += 56
    d.end()

    d.g("Chart Pemakaian per Jam")
    d.card(272, 504, 704, 220)
    d.text(296, 538, "Pemakaian per jam", 15, 800)
    d.text(952, 538, "7 hari terakhir", 12, 400, MUTED, "end")
    base = 692
    for gy in (base, base - 50, base - 100):
        d.line(296, gy + 0.5, 952, gy + 0.5, FILL)
    data = [1, 2, 3, 5, 3, 2, 4, 5, 2, 1]
    mx = max(data)
    for i, v in enumerate(data):
        x = 316 + i * 64
        h = v * 20
        d.rect(x, base - h, 32, h, R["tag"], fill=K["info"]["main"] if v == mx else K["info"]["border"])
        d.text(x + 16, base + 18, f"{7 + i:02d}", 11, 400, MUTED, "middle")
    d.end()
    d.save(ROOT / "screens" / "admin-web-01-ringkasan.svg")


def w_riwayat():
    d = Doc(1440, 800, "Admin Web - 02 Riwayat Sewa")
    web_shell(d, "Riwayat Sewa")

    d.g("Filter Bar")
    d.card(272, 88, 360, 44, R["field"])
    glyph(d, "search", 296, 110, DIS, 1.8)
    d.text(316, 115, "Cari nama, nomor, atau ID sesi", 13, 400, DIS)
    for x, w, lab in [(644, 124, "Hari ini"), (780, 144, "Semua locker"), (936, 140, "Semua status")]:
        d.card(x, 88, w, 44, R["field"])
        d.text(x + 16, 115, lab, 13, 600, BODY)
        d.path(f"M{x + w - 24} 107L{x + w - 20} 111L{x + w - 16} 107", MUTED, 1.8)
    d.button(1268, 88, 140, 44, "Ekspor CSV", PRI, WHITE, size=13)
    glyph(d, "download", 1296, 110, WHITE, 1.8)
    d.end()

    d.g("Tabel Riwayat")
    d.card(272, 148, 1136, 516)
    d.top_round(273, 149, 1134, 44, R["card"] - 1, SURF2)
    cols = [(296, "ID Sesi"), (392, "Locker"), (472, "Penyewa"), (668, "Telepon"), (812, "Mulai"), (940, "Selesai"), (1068, "Durasi"), (1160, "Status")]
    for x, lab in cols:
        d.text(x, 176, lab, 11, 700, MUTED, ls=0.6)
    y = 192
    for i, (sid, lk, nm, ph, st, en, du, status, kind) in enumerate(SESSIONS):
        d.text(296, y + 31, sid, 13, 700, PRI)
        d.text(392, y + 31, f"Locker {lk}", 13, 400, BODY)
        d.text(472, y + 31, nm, 13, 700)
        d.text(668, y + 31, ph, 13, 400, MUTED)
        d.text(812, y + 31, st, 13, 400, BODY)
        d.text(940, y + 31, en, 13, 400, BODY)
        d.text(1068, y + 31, du, 13, 700, K["info"]["main"] if status == "Berjalan" else INK)
        d.badge(1160, y + 15, status, kind)
        d.line(273, y + 52.5, 1407, y + 52.5, FILL)
        y += 52
    d.text(296, 642, "Menampilkan 1-8 dari 124 sesi", 13, 400, MUTED)
    for x, lab, on in [(1212, "‹", False), (1252, "1", True), (1292, "2", False), (1332, "3", False), (1372, "›", False)]:
        d.rect(x, 622, 32, 32, R["field"], fill=PRI if on else SURF, stroke=None if on else BORDER)
        d.text(x + 16, 643, lab, 13, 700, WHITE if on else BODY, "middle")
    d.end()
    d.save(ROOT / "screens" / "admin-web-02-riwayat-sewa.svg")


def w_log():
    d = Doc(1440, 800, "Admin Web - 03 Log Audit")
    web_shell(d, "Log Audit")
    dg = K["danger"]

    d.g("Filter Chips")
    x = 272
    for lab, on in [("Semua", True), ("Buka darurat", False), ("Resolve", False), ("Pengaturan", False), ("Perangkat", False), ("Akses data", False)]:
        w = int(len(lab) * 7.4 + 32)
        d.rect(x, 88, w, 36, 18, fill=INK if on else FILL)
        d.text(x + w / 2, 111, lab, 13, 700 if on else 600, WHITE if on else BODY, "middle")
        x += w + 8
    d.button(1268, 84, 140, 44, "Ekspor CSV", SURF, BODY, stroke=BORDER2, size=13)
    d.end()

    d.g("Tabel Log")
    d.card(272, 140, 700, 492)
    d.top_round(273, 141, 698, 44, R["card"] - 1, SURF2)
    for x, lab in [(296, "WAKTU"), (392, "PELAKU"), (516, "AKSI"), (736, "LOCKER"), (846, "HASIL")]:
        d.text(x, 168, lab, 11, 700, MUTED, ls=0.6)
    y = 184
    for i, (tm, who, act, kind, lk, res, rk) in enumerate(LOG):
        sel = i == 1
        if sel:
            d.rect(273, y, 698, 56, 0, fill=dg["tint"])
            d.rect(273, y, 4, 56, 0, fill=dg["main"])
        d.text(296, y + 33, tm, 13, 400, BODY)
        d.text(392, y + 33, who, 13, 600)
        d.circle(528, y + 28, 4, fill=K[kind]["main"])
        d.text(540, y + 33, act, 13, 700 if kind == "danger" else 600)
        d.text(736, y + 33, lk, 13, 400, BODY)
        d.badge(846, y + 17, res, rk)
        d.line(273, y + 56.5, 971, y + 56.5, FILL)
        y += 56
    d.end()

    d.g("Drawer Detail Log")
    d.card(992, 140, 416, 492)
    d.text(1016, 174, "Detail log", 15, 800)
    glyph(d, "x", 1384, 168, MUTED, 1.8)
    d.badge(1016, 188, "BUKA DARURAT", "danger")
    fields = [
        ("Waktu", "24 Nov 2026 · 10:03:40 WIB"),
        ("Pelaku", "Petugas A · Security"),
        ("Locker & perangkat", "Locker 01 · ESP32-01"),
        ("Alasan", "Lupa kode"),
        ("Sesi sewa", "#S-8492 · tetap berjalan"),
        ("Hasil", "Solenoid terbuka 5 dtk · dikonfirmasi ESP32-01"),
    ]
    y = 238
    for lab, val in fields:
        d.text(1016, y, lab, 11, 600, MUTED)
        d.text(1016, y + 20, val, 13, 700)
        y += 48
    d.rect(1016, 542, 368, 64, R["field"], fill=SURF2)
    d.text(1032, 568, "Catatan ini permanen dan tidak bisa diubah.", 12, 700, BODY)
    d.text(1032, 586, "Hanya Admin yang dapat melihat dan mengekspor log.", 12, 400, MUTED)
    d.end()
    d.save(ROOT / "screens" / "admin-web-03-log-audit.svg")


# ------------------------------------------------------------------ admin mobile screens
def m_ringkasan():
    d = Doc(360, 800, "Admin Mobile - 01 Ringkasan")
    d.rect(0, 0, 360, 800, fill=BG)
    status_bar(d)
    wn, ws = K["warning"], K["danger"]
    d.g("App Bar")
    d.text(16, 62, "Ringkasan", 22, 800)
    d.text(16, 81, "Admin · Unit STTI-01", 12, 400, MUTED)
    online_pill(d, 344, 46)
    d.end()

    d.g("Banner Perhatian")
    d.card(16, 100, 328, 64, fill=wn["tint"], stroke=wn["border"])
    d.circle(46, 132, 16, fill=wn["container"])
    glyph(d, "door", 46, 132, wn["main"], 1.8)
    d.text(72, 128, "Locker 02 · pintu terbuka 06:12", 13, 800)
    d.text(72, 146, "Sejak 10:05 WIB · ESP32-02 online", 11, 400, MUTED)
    d.chevron(326, 132)
    d.end()

    d.g("KPI Cards")
    kpis = [
        ("Sewa hari ini", "5", "+2 vs kemarin", K["success"]["text"], INK, SURF, BORDER),
        ("Rata-rata durasi", "42 mnt", "4 sesi selesai", MUTED, INK, SURF, BORDER),
        ("Perhatian", "2", "1 berlangsung", wn["text"], wn["main"], wn["tint"], wn["border"]),
        ("Buka darurat", "2", "1 gagal", ws["text"], ws["main"], SURF, BORDER),
    ]
    for i, (lab, val, sub, sc, vc, bg, bd) in enumerate(kpis):
        x = 16 + (i % 2) * 168
        y = 180 + (i // 2) * 96
        d.card(x, y, 160, 88, fill=bg, stroke=bd)
        d.text(x + 16, y + 26, lab, 12, 600, MUTED)
        d.text(x + 16, y + 58, val, 26, 800, vc)
        d.text(x + 16, y + 76, sub, 11, 400, sc)
    d.end()

    d.g("Status Locker")
    m_section(d, 392, "Status locker")
    rows = [
        (404, "info", "01", "Disewa · 00:11:24", BODY, "ESP32-01", SURF, BORDER),
        (480, "warning", "02", "Pintu terbuka · 06:12", wn["text"], "ESP32-02", wn["tint"], wn["border"]),
    ]
    for y, kind, num, sub, sc, esp, bg, bd in rows:
        k = K[kind]
        d.card(16, y, 328, 68, fill=bg, stroke=bd)
        d.circle(46, y + 34, 18, fill=k["container"])
        d.text(46, y + 39, num, 13, 800, k["main"], "middle")
        d.text(76, y + 30, f"Locker {num}", 14, 800)
        d.text(76, y + 48, sub, 12, 600 if kind == "warning" else 400, sc)
        d.text(328 - 16, y + 30, esp, 11, 600, BODY, "end")
        d.circle(280, y + 44, 4, fill=K["success"]["main"])
        d.text(312, y + 48, "Online", 11, 700, K["success"]["main"], "end")
    d.end()

    d.g("Kejadian Terbaru")
    m_section(d, 576, "Kejadian terbaru")
    d.card(16, 588, 328, 120)
    y = 588
    for i, (kind, title, sub) in enumerate(EVENTS[:3]):
        short = {"warning": "Locker 02 pintu terbuka", "danger": "Buka darurat Locker 01", "info": "Locker 01 disewa"}[kind]
        tm = sub.split(" · ")[0]
        d.circle(36, y + 20, 4, fill=K[kind]["main"])
        d.text(50, y + 24, short, 12, 700)
        d.text(328 - 16, y + 24, tm, 11, 400, MUTED, "end")
        if i < 2:
            d.line(32, y + 40.5, 328, y + 40.5, FILL)
        y += 40
    d.end()
    mobile_nav(d, "Ringkasan")
    d.save(ROOT / "screens" / "admin-mobile-01-ringkasan.svg")


def m_riwayat():
    d = Doc(360, 800, "Admin Mobile - 02 Riwayat Sewa")
    d.rect(0, 0, 360, 800, fill=BG)
    status_bar(d)
    d.g("App Bar")
    d.text(16, 62, "Riwayat Sewa", 22, 800)
    d.text(16, 81, "124 sesi · 5 hari ini", 12, 400, MUTED)
    d.circle(322, 56, 18, fill=FILL)
    glyph(d, "download", 322, 56, INK, 1.8)
    d.end()

    d.g("Search")
    d.card(16, 100, 328, 44, R["field"])
    glyph(d, "search", 40, 122, DIS, 1.8)
    d.text(60, 127, "Cari nama, nomor, atau sesi", 13, 400, DIS)
    d.end()

    d.g("Filter Chips")
    for x, w, lab, on in [(16, 84, "Hari ini", True), (108, 92, "Locker", False), (208, 92, "Status", False)]:
        d.rect(x, 156, w, 32, 16, fill=INK if on else FILL)
        d.text(x + 16, 176, lab, 12, 700 if on else 600, WHITE if on else BODY)
        c = WHITE if on else MUTED
        d.path(f"M{x + w - 22} 170L{x + w - 18} 174L{x + w - 14} 170", c, 1.8)
    d.end()

    d.g("Daftar Sesi")
    y = 200
    for sid, lk, nm, ph, st, en, du, status, kind in SESSIONS[:5]:
        d.card(16, y, 328, 94)
        d.text(32, y + 28, f'{sid}<tspan font-weight="400" fill="{MUTED}"> · Locker {lk}</tspan>', 13, 800, PRI, raw=True)
        d.badge(328, y + 12, status, kind, align="right")
        d.text(32, y + 54, f'{esc(nm)}<tspan font-weight="400" fill="{MUTED}" font-size="12"> · {ph}</tspan>', 13, 700, raw=True)
        d.text(32, y + 76, f"{st} – {en} · {du}", 12, 400, MUTED)
        y += 102
    d.end()
    mobile_nav(d, "Riwayat")
    d.save(ROOT / "screens" / "admin-mobile-02-riwayat-sewa.svg")


def m_log():
    d = Doc(360, 800, "Admin Mobile - 03 Log Audit")
    d.rect(0, 0, 360, 800, fill=BG)
    status_bar(d)
    dg = K["danger"]
    d.g("App Bar")
    d.text(16, 62, "Log Audit", 22, 800)
    d.text(16, 81, "Semua tindakan tercatat permanen", 12, 400, MUTED)
    d.end()

    d.g("Filter Chips")
    for x, w, lab, on in [(16, 64, "Semua", True), (88, 80, "Darurat", False), (176, 80, "Resolve", False), (264, 72, "Sistem", False)]:
        d.rect(x, 100, w, 32, 16, fill=INK if on else FILL)
        d.text(x + w / 2, 120, lab, 12, 700 if on else 600, WHITE if on else BODY, "middle")
    d.end()

    d.g("Log - Buka Darurat (expanded)")
    d.card(16, 148, 328, 168, fill=dg["tint"], stroke=dg["border"])
    d.circle(46, 180, 18, fill=dg["container"])
    glyph(d, "lock", 46, 180, dg["main"], 1.8)
    d.text(76, 176, "Buka darurat · Locker 01", 14, 800)
    d.text(76, 196, "10:03 · Petugas A", 12, 400, MUTED)
    d.badge(328, 182, "Berhasil", "success", align="right")
    d.line(32, 212.5, 328, 212.5, dg["border"])
    for yy, lab, val in [(236, "Alasan", "Lupa kode"), (262, "Sesi sewa", "#S-8492 · tetap berjalan"), (288, "Hasil", "Solenoid terbuka 5 dtk")]:
        d.text(32, yy, lab, 12, 400, MUTED)
        d.text(328, yy, val, 12, 700, INK, "end")
    d.end()

    d.g("Log - Daftar")
    items = [
        ("warning", "Pintu terbuka > 2 menit", "Locker 02 · Sistem", "10:05"),
        ("info", "Sesi dimulai #S-8492", "Locker 01 · Sistem", "10:00"),
        ("neutral", "Lihat nomor telepon penuh", "Locker 01 · Admin (Anda)", "09:58"),
        ("danger", "Buka darurat gagal", "Locker 02 · ESP32-02 tidak merespons", "09:41"),
        ("warning", "Resolve & kosongkan", "Locker 02 · Petugas B", "09:12"),
    ]
    y = 324
    for kind, title, sub, tm in items:
        d.card(16, y, 328, 60)
        d.circle(44, y + 30, 14, fill=K[kind]["container"])
        d.circle(44, y + 30, 5, fill=K[kind]["main"])
        d.text(70, y + 26, title, 13, 700)
        d.text(70, y + 44, sub, 11, 400, MUTED)
        d.text(328, y + 26, tm, 11, 400, MUTED, "end")
        y += 68
    d.end()
    mobile_nav(d, "Log")
    d.save(ROOT / "screens" / "admin-mobile-03-log-audit.svg")


if __name__ == "__main__":
    build_css()
    build_figma()
    build_dart()
    for fn in (w_ringkasan, w_riwayat, w_log, m_ringkasan, m_riwayat, m_log):
        fn()
    print("OK")
