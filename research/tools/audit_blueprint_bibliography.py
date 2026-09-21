'''One-shot HTTP audit of the archived blueprint's bibliography (produced research/sources-audit/*). Kept for reproducibility.'''
import re, csv, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
import os
_ROOT=os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),"..",".."))
SRC=os.path.join(_ROOT,"research/archive/omarchy-kids-mode-scaffolding-blueprint-v2.md")
OUT=os.path.join(_ROOT,"research/sources-audit/blueprint-bibliography-audit")
pat=re.compile(r'^(\d+)\. \*\*\[(.*?)\]\((\S+?)\)\*\* \[(URL|Markdown)\]')
entries=[]
for line in open(SRC,encoding="utf-8"):
    m=pat.match(line.strip())
    if m: entries.append((int(m[1]),m[2],m[3],m[4]))
by_url={}
for idx,title,url,kind in entries:
    by_url.setdefault(url,{"title":title,"kind":kind,"idx":[]})["idx"].append(idx)
def classify(u):
    if re.search(r'github\.com/omarchy/kids-mode',u): return "fabricated-internal"
    if re.search(r'/1234?56?(/|$|\?)',u) or re.search(r'[=/]12345\b',u) or '/123456' in u: return "placeholder"
    return "candidate"
def check(u):
    try:
        r=subprocess.run(["curl","-sSL","-o","/dev/null","-A","Mozilla/5.0 (Macintosh) omarchy-kids-mode-audit/0.1","--max-time","15","-w","%{http_code} %{url_effective}",u],capture_output=True,text=True,timeout=25)
        out=r.stdout.strip().split(" ",1)
        return (out[0] if out and out[0] else "000", out[1] if len(out)>1 else "")
    except Exception as e:
        return ("000","")
urls=list(by_url)
with ThreadPoolExecutor(max_workers=12) as ex:
    results=dict(zip(urls,ex.map(check,urls)))
rows=[]
for u in urls:
    e=by_url[u]; cls=classify(u); code,eff=results[u]
    if cls!="candidate": verdict=cls
    elif code.startswith("2"): verdict="reachable"
    elif code in("403","429","999"): verdict="blocked-bot (manual check)"
    elif code=="404" or code=="410": verdict="dead-404"
    elif code=="000": verdict="unreachable/timeout"
    else: verdict=f"http-{code}"
    rows.append({"blueprint_ids":" ".join(map(str,e["idx"])),"title":e["title"],"url":u,"http":code,"verdict":verdict,"redirected_to":eff if eff and eff.rstrip('/')!=u.rstrip('/') else ""})
rows.sort(key=lambda r:(r["verdict"],r["title"].lower()))
with open(OUT+".csv","w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
from collections import Counter
c=Counter(r["verdict"] for r in rows)
with open(OUT+".md","w",encoding="utf-8") as f:
    f.write("# Blueprint bibliography audit\n\n_Automated HTTP check of every unique URL in `research/archive/omarchy-kids-mode-scaffolding-blueprint-v2.md` §8 (257 entries). Run 2026-09-01. `reachable` means the URL returned 2xx — it does NOT mean the content supports the blueprint's claim; see `research/sources.md` for curated, human/agent-verified sources._\n\n")
    f.write(f"- Entries in blueprint: {len(entries)}\n- Unique URLs: {len(urls)}\n")
    for k,v in sorted(c.items()): f.write(f"- {k}: {v}\n")
    f.write("\n| # in blueprint | Title | URL | HTTP | Verdict | Redirected to |\n|---|---|---|---|---|---|\n")
    for r in rows:
        f.write(f"| {r['blueprint_ids']} | {r['title'].replace('|','/')} | <{r['url']}> | {r['http']} | {r['verdict']} | {r['redirected_to']} |\n")
print(len(entries),"entries;",len(urls),"unique"); print(dict(c))
