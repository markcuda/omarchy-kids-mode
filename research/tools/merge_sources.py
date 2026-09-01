"""Regenerate research/sources.md (+ .csv) by merging the Sources sections of research/reports/*.md.

Run from anywhere: python3 research/tools/merge_sources.py
Parses both table rows (| S1 | ... |) and bullet lists (- [S1] ... URL ... STATUS ...).
De-duplicates by URL across reports; keys stay per-report (R01-S14)."""
import re, glob, os, csv
from collections import OrderedDict
import os
ROOT=os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),"..",".."))
LAYER_HINT={"01":"L11, L5","02":"L1, L9, all","03":"L1, L2, L4","04":"L3","05":"L7, L8","06":"community","07":"L5, L6, L10"}
STATUS_RE=re.compile(r'\b(VERIFIED|SEARCH-ONLY|SEARCH ONLY|DEAD/UNVERIFIABLE|DEAD-UNVERIFIABLE|DEAD/WRONG|UNVERIFIABLE|UNVERIFIED|DEAD|PARTIAL|WRONG)\b',re.I)
URL_RE=re.compile(r'https?://(?:[^\s<>()\]|"]|\([^\s()]*\))+')
def norm_status(s):
    s=s.upper().replace(" ","-")
    if s.startswith("VERIFIED"): return "verified"
    if s.startswith("SEARCH"): return "search-only"
    if "DEAD" in s or "UNVERIF" in s or s=="WRONG": return "dead/unverifiable"
    if s=="PARTIAL": return "partial"
    return s.lower()
rows=[]
for path in sorted(glob.glob(f"{ROOT}/research/reports/*.md")):
    rid=os.path.basename(path)[:2]
    text=open(path,encoding="utf-8").read()
    m=re.search(r'^## Sources.*$',text,re.M)
    if not m: print("no Sources section:",path); continue
    body=text[m.end():]
    for line in body.splitlines():
        l=line.strip()
        km=re.match(r'^(?:\|\s*|[-*]\s+)?\**\[?S(\d+)\]?\**[\s|.:—-]',l)
        if not km: continue
        urls=URL_RE.findall(l)
        if not urls: continue
        url=urls[0].rstrip('.,;')
        sm=STATUS_RE.search(l)
        status=norm_status(sm.group(1)) if sm else "unknown"
        # title: first cell after key in table rows, else text before url
        if l.startswith("|"):
            cells=[c.strip() for c in l.strip("|").split("|")]
            title=cells[1] if len(cells)>1 else ""
            rest=[c for c in cells[3:] if not STATUS_RE.fullmatch(c.strip("* ")) and not re.fullmatch(r'\d{4}-\d{2}-\d{2}',c.strip())]
            note=rest[-1] if rest else ""
        else:
            pre=l[:l.find(url)]
            title=re.sub(r'^\W*S\d+\]?','',pre).strip(" -—:[](*.")
            note=l[l.find(url)+len(url):]
            if sm: note=note.replace(sm.group(0),"")
            note=note.strip(" -—|*")
        title=re.sub(r'\[(.*?)\]\(.*?\)',r'\1',title).replace("**","").strip()
        note=re.sub(r'\[(.*?)\]\(.*?\)',r'\1',note).replace("**","").strip()
        rows.append({"key":f"R{rid}-S{km.group(1)}","report":rid,"title":title,"url":url,"status":status,"note":note})
# dedupe by URL (keep first, collect keys)
by_url=OrderedDict()
for r in rows:
    u=r["url"].rstrip("/")
    if u in by_url:
        by_url[u]["keys"].append(r["key"]); 
        if r["status"]=="verified": by_url[u]["status"]="verified"
        by_url[u]["layers"].add(LAYER_HINT.get(r["report"],""))
    else:
        r["keys"]=[r["key"]]; r["layers"]={LAYER_HINT.get(r["report"],"")}; by_url[u]=r
def domain(u): return re.sub(r'^https?://(www\.)?','',u).split('/')[0]
groups=OrderedDict([
 ("Omarchy — official (repo, manual, releases, site)",lambda u:any(d in u for d in ["omarchy.org","omacom/omarchy","github.com/omacom","learn.omacom.io","omarchy-iso","plugins.omarchy","basecamp/omarchy"])),
 ("Omarchy — community & ecosystem",lambda u:"omarchy" in u.lower() or "omacom" in u.lower()),
 ("Arch Linux (packages, AUR, ArchWiki)",lambda u:"archlinux.org" in u),
 ("Hyprland / Wayland / Quickshell",lambda u:any(d in u for d in ["hyprland","hyprwm","quickshell","wayland","cage-kiosk","hyprtile"])),
 ("Sandboxing, hardening & privilege (bubblewrap, polkit, Flatpak, fapolicyd, Limine, systemd)",lambda u:any(d in u for d in ["bubblewrap","flatpak","polkit","fapolicyd","firejail","limine","systemd","freedesktop","apparmor","opensuse","openwall","redhat","docs.oracle"])),
 ("DNS, network & browser policy",lambda u:any(d in u for d in ["cloudflare","nextdns","quad9","opendns","adguard","pi-hole","dnscrypt","chromium.org","chromeenterprise","support.google.com/chrome","mozilla","policy-templates","ublock","leechblock","nftables","e2guardian","squid"])),
 ("Parental-control tools (Linux)",lambda u:any(d in u for d in ["malcontent","timekpr","little_brother","LiFE-Parental","veyon","activitywatch","aw-watcher","gnome","kde","linuxmint","elementary"])),
 ("Kids / educational distributions & prior art",lambda u:any(d in u for d in ["endless","sugarlabs","sugar","doudou","primtux","edubuntu","ubuntu","zorin","ubermix","debian","fedora","distrowatch","distroscout","kano"])),
 ("Mainstream parental-control benchmarks (Apple, Google, Microsoft, Nintendo, Amazon)",lambda u:any(d in u for d in ["apple.com","google.com","families.google","microsoft.com","nintendo","amazon"])),
 ("Apps, games, learning content & themes",lambda u:any(d in u for d in ["gcompris","tuxpaint","scratch","kde.org/applications","flathub","kiwix","kolibri","minetest","luanti","supertux","pico-8","tic80","godot","itch.io","libreoffice","anki"])),
 ("Pedagogy, child development, AI & policy",lambda u:any(d in u for d in ["aap.org","commonsense","ftc.gov","ico.org","unicef","5rights","raspberrypi","acm.org","nih.gov","eur-lex","europa.eu","gov.uk","ofcom","esafety","oecd","naeyc","pediatrics","idc"])),
 ("OSS governance, process & repo practice",lambda u:any(d in u for d in ["docs.github.com","opensource.guide","adr.github.io","contributor-covenant","choosealicense","rust-lang/rfcs","reactjs/rfcs","emberjs/rfcs","python/peps","kubernetes/enhancements","tc39","withastro","home-assistant","developercertificate","spdx","creativecommons","markdownlint","lychee","allcontributors","curl.se","gentoo","qemu"])),
])
def group_of(u):
    for name,fn in groups.items():
        if fn(u): return name
    return "Other / secondary coverage"
grouped=OrderedDict((g,[]) for g in list(groups)+["Other / secondary coverage"])
for r in by_url.values(): grouped[group_of(r["url"])].append(r)
counts={}
for r in by_url.values(): counts[r["status"]]=counts.get(r["status"],0)+1
out=[]
out.append("# Sources — the master registry\n")
out.append("_status: living · updated 2026-09-01 · **Cite as `[R01-S14]`** (report 01, its source S14). Only rows marked `verified` may be cited from `docs/`; see ADR-0003._\n")
out.append("How to read: every research report keeps its own `Sources` table with per-report keys. This page merges them all, de-duplicated by URL, grouped by subject. **`verified`** = a research agent fetched the page on 2026-09-01 and the content matched the claim it is cited for; **`search-only`** = surfaced in search results but not opened; **`dead/unverifiable`** = 404, blocked, or could not be confirmed. The original blueprint's bibliography is audited separately in `sources-audit/` and is **not** citable.\n")
out.append(f"**Totals:** {len(by_url)} unique sources from {len(rows)} citations · " + " · ".join(f"{k}: {v}" for k,v in sorted(counts.items())) + "\n")
out.append("## Add a source\n\nOpen a **📚 Add a source** issue, or PR a row into the right group below **and** into the report/note that cites it. Include the date you opened it. Don't paste a link you haven't opened.\n")
out.append("## Contents\n")
for g,items in grouped.items():
    if items: out.append(f"- [{g}](#{re.sub(r'[^a-z0-9 -]','',g.lower()).replace(' ','-')}) ({len(items)})")
out.append("")
for g,items in grouped.items():
    if not items: continue
    out.append(f"## {g}\n")
    out.append("| Key(s) | Title | URL | Status | Layers | Note |\n|---|---|---|---|---|---|")
    for r in sorted(items,key=lambda r:(r['status']!='verified',r['title'].lower())):
        keys=", ".join(r["keys"]); layers=", ".join(sorted(x for x in r["layers"] if x))
        out.append(f"| {keys} | {r['title'].replace('|','/')} | <{r['url']}> | {r['status']} | {layers} | {r['note'].replace('|','/')} |")
    out.append("")
open(f"{ROOT}/research/sources.md","w",encoding="utf-8").write("\n".join(out))
with open(f"{ROOT}/research/sources.csv","w",newline="",encoding="utf-8") as f:
    w=csv.writer(f); w.writerow(["keys","title","url","status","layers","note","group"])
    for g,items in grouped.items():
        for r in items: w.writerow([";".join(r["keys"]),r["title"],r["url"],r["status"],", ".join(sorted(x for x in r["layers"] if x)),r["note"],g])
print(len(rows),"citations;",len(by_url),"unique;",counts)
