#!/usr/bin/env python3
# Generate CPTC_Playbook_Wiki.html from the phase markdown files.
# Key upgrade: full-text + tool-aware client-side search that indexes every
# heading, command block and prose block, so any tool/technique resolves to
# every place it appears (jump + highlight).
import os, re, html, json, glob

# Portable: build from the phase .md files sitting next to this script.
SRC = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(SRC, "CPTC_Playbook_Wiki.html")

def slug(s):
    s = re.sub(r'<[^>]+>', '', s)
    s = s.lower()
    s = re.sub(r'[^a-z0-9]+', '-', s).strip('-')
    return s or 'x'

def esc(s):
    return html.escape(s, quote=True)

# --- inline markdown -> html ---
def inline(t):
    # protect code spans first
    spans = []
    def stash(m):
        spans.append(m.group(1))
        return f"\x00{len(spans)-1}\x00"
    t = re.sub(r'`([^`]+)`', stash, t)
    t = esc(t)
    t = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', t)
    t = re.sub(r'(?<!\w)_([^_]+)_(?!\w)', r'<em>\1</em>', t)
    t = re.sub(r'\[([^\]]+)\]\((https?://[^)]+)\)',
               lambda m: f'<a href="{esc(m.group(2))}" target="_blank" rel="noopener">{esc(m.group(1))}</a>', t)
    def unstash(m):
        return f'<code>{esc(spans[int(m.group(1))])}</code>'
    t = re.sub(r'\x00(\d+)\x00', unstash, t)
    return t

def render_file(path, phase_num):
    """Return (html_sections, nav_items, index_entries)."""
    with open(path, encoding='utf-8') as f:
        lines = f.read().split('\n')
    out = []          # html chunks for the <section>
    nav = []          # (level, text, anchor)
    idx = []          # search index entries
    sid_prefix = f"s{phase_num}"
    phase_title = None
    cur_head_anchor = sid_prefix
    cur_head_text = ""
    blk = [0]
    def new_block_id():
        blk[0]+=1
        return f"b-{sid_prefix}-{blk[0]}"

    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        # fenced code
        m = re.match(r'^```(\w+)?\s*$', line)
        if m:
            j = i+1; code=[]
            while j < n and not re.match(r'^```\s*$', lines[j]):
                code.append(lines[j]); j+=1
            raw = '\n'.join(code)
            bid = new_block_id()
            out.append(f'<pre id="{bid}"><code>{esc(raw)}</code></pre>')
            idx.append({"p":phase_num,"pt":phase_title or "","h":cur_head_text,
                        "a":bid,"k":"cmd","t":raw})
            i = j+1
            continue
        # headings
        m = re.match(r'^(#{1,3})\s+(.*)$', line)
        if m:
            lvl = len(m.group(1)); txt = m.group(2).strip()
            if lvl == 1:
                phase_title = txt
                anchor = sid_prefix
                out.append(f'<h1 id="{anchor}">{inline(txt)}</h1>')
                cur_head_anchor = anchor; cur_head_text = txt
                nav.append((1, txt, anchor))
                idx.append({"p":phase_num,"pt":phase_title,"h":txt,"a":anchor,"k":"head","t":txt})
            else:
                anchor = f"{sid_prefix}-{slug(txt)}"
                tag = 'h2' if lvl==2 else 'h3'
                out.append(f'<{tag} id="{anchor}">{inline(txt)}</{tag}>')
                cur_head_anchor = anchor; cur_head_text = txt
                nav.append((lvl, txt, anchor))
                idx.append({"p":phase_num,"pt":phase_title or "","h":txt,"a":anchor,"k":"head","t":txt})
            i+=1; continue
        # table (GFM)
        if '|' in line and i+1 < n and re.match(r'^\s*\|?[\s:|-]+\|[\s:|-]+', lines[i+1]):
            tbl=[line]; j=i+1
            while j < n and '|' in lines[j]:
                tbl.append(lines[j]); j+=1
            rows=[r.strip().strip('|').split('|') for r in tbl]
            header=[c.strip() for c in rows[0]]
            body=rows[2:]
            bid=new_block_id()
            h='<div class="tblwrap" id="'+bid+'"><table><thead><tr>'+''.join(f'<th>{inline(c)}</th>' for c in header)+'</tr></thead><tbody>'
            for r in body:
                cells=[c.strip() for c in r]
                h+='<tr>'+''.join(f'<td>{inline(c)}</td>' for c in cells)+'</tr>'
            h+='</tbody></table></div>'
            out.append(h)
            idx.append({"p":phase_num,"pt":phase_title or "","h":cur_head_text,"a":bid,"k":"text",
                        "t":' '.join(header)+' '+' '.join(' '.join(r) for r in body)})
            i=j; continue
        # blockquote
        if re.match(r'^>\s?', line):
            q=[];
            while i<n and re.match(r'^>\s?', lines[i]):
                q.append(re.sub(r'^>\s?','',lines[i])); i+=1
            txt=' '.join(q)
            bid=new_block_id()
            out.append(f'<blockquote id="{bid}"><p>{inline(txt)}</p></blockquote>')
            idx.append({"p":phase_num,"pt":phase_title or "","h":cur_head_text,"a":bid,"k":"text","t":txt})
            continue
        # unordered list
        if re.match(r'^\s*[-*]\s+', line):
            items=[]
            while i<n and re.match(r'^\s*[-*]\s+', lines[i]):
                items.append(re.sub(r'^\s*[-*]\s+','',lines[i])); i+=1
            bid=new_block_id()
            out.append(f'<ul id="{bid}">'+''.join(f'<li>{inline(x)}</li>' for x in items)+'</ul>')
            idx.append({"p":phase_num,"pt":phase_title or "","h":cur_head_text,"a":bid,"k":"text","t":' '.join(items)})
            continue
        # ordered list
        if re.match(r'^\s*\d+\.\s+', line):
            items=[]
            while i<n and re.match(r'^\s*\d+\.\s+', lines[i]):
                items.append(re.sub(r'^\s*\d+\.\s+','',lines[i])); i+=1
            bid=new_block_id()
            out.append(f'<ol id="{bid}">'+''.join(f'<li>{inline(x)}</li>' for x in items)+'</ol>')
            idx.append({"p":phase_num,"pt":phase_title or "","h":cur_head_text,"a":bid,"k":"text","t":' '.join(items)})
            continue
        # hr
        if re.match(r'^---+\s*$', line):
            out.append('<hr/>'); i+=1; continue
        # blank
        if line.strip()=='':
            i+=1; continue
        # paragraph (gather until blank/structural)
        para=[line]; i+=1
        while i<n and lines[i].strip()!='' and not re.match(r'^(#{1,3}\s|```|>\s?|\s*[-*]\s|\s*\d+\.\s|---+\s*$)', lines[i]) and not ('|' in lines[i] and i+1<n and re.match(r'^\s*\|?[\s:|-]+\|',lines[i+1] if i+1<n else '')):
            para.append(lines[i]); i+=1
        txt=' '.join(para)
        bid=new_block_id()
        out.append(f'<p id="{bid}">{inline(txt)}</p>')
        idx.append({"p":phase_num,"pt":phase_title or "","h":cur_head_text,"a":bid,"k":"text","t":txt})

    return '\n'.join(out), nav, idx, phase_title

# collect files
files=[]
for p in sorted(glob.glob(os.path.join(SRC,'*.md'))):
    b=os.path.basename(p)
    m=re.match(r'^(\d{2})_',b)
    if not m: continue
    files.append((m.group(1),p,b))

sections_html=[]
nav_html=[]
index=[]
phase_meta=[]  # (num, title, anchor)
for num,path,b in files:
    sec, nav, idx, ptitle = render_file(path, num)
    anchor=f"s{num}"
    phase_meta.append((num, ptitle or b, anchor))
    sections_html.append(f'<section class="doc" id="wrap-{anchor}">\n{sec}\n</section>')
    index.extend(idx)
    # build nav
    subs=[x for x in nav if x[0]>1]
    nav_html.append(f'<li class="nav-sec"><a href="#{anchor}" class="nav-top" data-target="{anchor}"><span class="num">{num}</span>{esc(ptitle or b)}</a>')
    if subs:
        nav_html.append('<ul class="nav-sub">')
        for lvl,txt,anc in subs:
            nav_html.append(f'<li><a href="#{anc}" data-target="{anc}">{esc(txt)}</a></li>')
        nav_html.append('</ul>')
    nav_html.append('</li>')

INDEX_JSON=json.dumps(index, separators=(',',':'), ensure_ascii=False)
PHASES_JSON=json.dumps([{"n":n,"t":t,"a":a} for n,t,a in phase_meta], ensure_ascii=False)
# Prevent an embedded literal </script> (e.g. an XSS payload string) from closing the tag.
INDEX_JSON=INDEX_JSON.replace('</','<\\/')
PHASES_JSON=PHASES_JSON.replace('</','<\\/')

TEMPLATE = r'''<!doctype html>
<html lang="en" data-theme="dark">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>The Larpers — CPTC Attack Playbook</title>
<style>
:root{--blue:#0065BD;--lblue:#3DB7E4;--bg:#0d1117;--panel:#111823;--panel2:#0a0f16;--border:#1e2a3a;--text:#d7e0ea;--muted:#8b9bb0;--code-bg:#0a0f16;--code-text:#e6edf3;--sidebar:320px;--hl:#20304a;--flash:#1f3b2e;}
:root[data-theme="light"]{--bg:#f5f7fa;--panel:#ffffff;--panel2:#eef2f7;--border:#d7dee7;--text:#1a2330;--muted:#5a6673;--code-bg:#0d1117;--code-text:#e6edf3;--hl:#dbeafe;--flash:#d8f3e3;}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;font:15px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;background:var(--bg);color:var(--text);}
a{color:var(--lblue);text-decoration:none}
a:hover{text-decoration:underline}
#sidebar{position:fixed;top:0;left:0;width:var(--sidebar);height:100vh;overflow-y:auto;background:var(--panel2);border-right:1px solid var(--border);padding:0 0 40px;}
.brand{padding:18px 20px 14px;border-bottom:1px solid var(--border);position:sticky;top:0;background:var(--panel2);z-index:5}
.brand h1{margin:0;font-size:16px;letter-spacing:.3px}
.brand .sub{color:var(--muted);font-size:11.5px;margin-top:3px}
.brand .accent{color:var(--lblue)}
.searchwrap{padding:12px 14px;position:sticky;top:60px;background:var(--panel2);z-index:4}
#search{width:100%;padding:9px 11px;border-radius:8px;border:1px solid var(--border);background:var(--bg);color:var(--text);font-size:13px;outline:none}
#search:focus{border-color:var(--blue)}
.searchmeta{font-size:11px;color:var(--muted);margin-top:6px;min-height:14px}
.nav{list-style:none;margin:0;padding:4px 8px}
.nav-sub{list-style:none;margin:2px 0 8px;padding:0 0 0 30px}
.nav-top{display:flex;align-items:center;gap:8px;padding:7px 10px;border-radius:7px;color:var(--text);font-weight:600;font-size:13.5px}
.nav-top:hover{background:var(--hl);text-decoration:none}
.nav-top .num{color:var(--blue);font-variant-numeric:tabular-nums;font-size:12px;min-width:20px}
.nav-sub a{display:block;padding:4px 10px;border-radius:6px;color:var(--muted);font-size:12.5px}
.nav-sub a:hover{background:var(--hl);color:var(--text);text-decoration:none}
a.active{background:var(--blue)!important;color:#fff!important}
.hidden{display:none!important}
/* search results */
#results{padding:6px 10px 20px;display:none}
#results.show{display:block}
.res-group{margin:10px 6px 4px;font-size:11px;text-transform:uppercase;letter-spacing:.4px;color:var(--blue);font-weight:700}
.res{display:block;padding:7px 10px;border-radius:7px;border:1px solid transparent;margin:2px 0}
.res:hover{background:var(--hl);text-decoration:none;border-color:var(--border)}
.res .rh{font-size:12.5px;color:var(--text);font-weight:600}
.res .rs{font-size:11.5px;color:var(--muted);font-family:"JetBrains Mono",ui-monospace,Menlo,Consolas,monospace;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;margin-top:2px}
.res .tag{font-size:10px;padding:1px 6px;border-radius:4px;background:var(--panel);border:1px solid var(--border);color:var(--muted);margin-left:6px}
.res mark, main mark{background:#f2c94c;color:#111;border-radius:3px;padding:0 2px}
.nores{padding:14px 12px;color:var(--muted);font-size:12.5px}
main{margin-left:var(--sidebar);padding:34px 46px 120px;max-width:980px}
.topbar{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}
.topbar .meta{color:var(--muted);font-size:12px}
#themetoggle{cursor:pointer;border:1px solid var(--border);background:var(--panel);color:var(--text);padding:6px 12px;border-radius:7px;font-size:12px}
.doc{border-bottom:1px solid var(--border);padding-bottom:26px;margin-bottom:26px}
.doc:last-child{border-bottom:none}
h1{font-size:26px;margin:.2em 0 .5em;padding-bottom:.2em}
.doc>h1{border-bottom:2px solid var(--blue);color:var(--text)}
h2{font-size:19px;margin:1.4em 0 .5em;color:var(--lblue)}
h3{font-size:15.5px;margin:1.1em 0 .4em;color:var(--text)}
h1,h2,h3{scroll-margin-top:18px}
code{font-family:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:12.8px}
p code,li code,td code{background:var(--panel);border:1px solid var(--border);border-radius:5px;padding:1px 5px;color:var(--lblue)}
pre{background:var(--code-bg);border:1px solid var(--border);border-radius:10px;padding:14px 16px;overflow:auto;position:relative;scroll-margin-top:60px}
pre code{color:var(--code-text);background:none;border:none;padding:0;white-space:pre}
.copybtn{position:absolute;top:8px;right:8px;background:var(--blue);color:#fff;border:none;border-radius:6px;padding:4px 10px;font-size:11px;cursor:pointer;opacity:0;transition:opacity .15s}
pre:hover .copybtn{opacity:1}
.copybtn.done{background:#1f9d55}
blockquote{border-left:3px solid var(--blue);margin:1em 0;padding:.4em 14px;background:var(--panel);border-radius:0 8px 8px 0;color:var(--text);scroll-margin-top:60px}
blockquote p{margin:.3em 0}
.tblwrap{overflow-x:auto;scroll-margin-top:60px}
table{border-collapse:collapse;width:100%;margin:1em 0;font-size:13px}
th,td{border:1px solid var(--border);padding:7px 10px;text-align:left}
th{background:var(--panel);color:var(--lblue)}
tr:nth-child(even) td{background:var(--panel2)}
ul,ol{padding-left:22px;scroll-margin-top:60px}
li{margin:.2em 0}
p{scroll-margin-top:60px}
hr{border:none;border-top:1px solid var(--border);margin:1.5em 0}
.backtop{position:fixed;bottom:22px;right:26px;background:var(--blue);color:#fff;border:none;border-radius:50%;width:42px;height:42px;font-size:18px;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,.4);display:none}
.hb{background:var(--panel);border:1px solid var(--border);border-radius:10px;padding:10px 14px;margin:0 0 18px;font-size:12.5px;color:var(--muted)}
.hb b{color:var(--lblue)}
@keyframes flashbg{0%{background:var(--flash)}100%{background:transparent}}
.flash{animation:flashbg 2s ease-out}
pre.flash,blockquote.flash,.tblwrap.flash{animation:flashbg 2s ease-out}
@media(max-width:820px){#sidebar{transform:translateX(-100%);transition:transform .2s;z-index:50;box-shadow:0 0 30px rgba(0,0,0,.6)}#sidebar.open{transform:none}main{margin-left:0;padding:20px 18px 100px}#menubtn{display:inline-block!important}}
#menubtn{display:none;position:fixed;top:12px;left:12px;z-index:60;background:var(--blue);color:#fff;border:none;border-radius:8px;padding:8px 12px;font-size:14px;cursor:pointer}
</style>
</head>
<body>
<button id="menubtn">&#9776;</button>
<nav id="sidebar">
  <div class="brand">
    <h1>The Larpers <span class="accent">&#9656;</span></h1>
    <div class="sub">CPTC Attack Playbook &middot; CSUSB CPTC</div>
  </div>
  <div class="searchwrap">
    <input id="search" type="search" placeholder="Search tool / technique / port (e.g. evil-winrm)" autocomplete="off">
    <div class="searchmeta" id="searchmeta"></div>
  </div>
  <div id="results"></div>
  <ul class="nav" id="nav">
__NAV__
  </ul>
</nav>
<main>
  <div class="topbar">
    <div class="meta">Offline field reference &middot; full-text search &middot; updated __DATE__</div>
    <button id="themetoggle">&#9681; Light</button>
  </div>
  <div class="hb">Every command uses <b>&lt;PLACEHOLDERS&gt;</b> — swap in your live targets before running. Scope &amp; ROE first; at competition, identify only by region + team number (no team name or CSUSB branding in deliverables). <b>Search</b> indexes every command and tool across all phases — try <b>evil-winrm</b>, <b>kerberoast</b>, <b>esc1</b>, or <b>1433</b>.</div>
__SECTIONS__
</main>
<button class="backtop" title="Back to top">&#8679;</button>
<script>
var INDEX=__INDEX__;
var PHASES=__PHASES__;

// copy buttons
document.querySelectorAll('pre').forEach(function(pre){
  var code=pre.querySelector('code'); if(!code)return;
  var b=document.createElement('button'); b.className='copybtn'; b.textContent='Copy';
  b.addEventListener('click',function(){navigator.clipboard.writeText(code.innerText).then(function(){b.textContent='Copied';b.classList.add('done');setTimeout(function(){b.textContent='Copy';b.classList.remove('done');},1200);});});
  pre.appendChild(b);
});

function esc(s){return s.replace(/[&<>"]/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c];});}
function snippet(text,q){
  var lt=text.toLowerCase(), i=lt.indexOf(q);
  if(i<0){ // multi-term: find first term
    var terms=q.split(/\s+/).filter(Boolean);
    for(var k=0;k<terms.length;k++){var j=lt.indexOf(terms[k]);if(j>=0){i=j;q=terms[k];break;}}
  }
  if(i<0)i=0;
  var start=Math.max(0,i-24), end=Math.min(text.length,i+q.length+60);
  var s=(start>0?'…':'')+text.slice(start,end)+(end<text.length?'…':'');
  // highlight all query terms
  q.split(/\s+/).filter(Boolean).forEach(function(t){
    s=s.replace(new RegExp('('+t.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+')','ig'),'\x01$1\x02');
  });
  return esc(s).replace(/\x01/g,'<mark>').replace(/\x02/g,'</mark>');
}
function matches(entry,terms){
  var t=entry.t.toLowerCase()+' '+entry.h.toLowerCase();
  for(var k=0;k<terms.length;k++){if(t.indexOf(terms[k])<0)return false;}
  return true;
}
function kindRank(k){return k==='head'?0:(k==='cmd'?1:2);}

var search=document.getElementById('search');
var results=document.getElementById('results');
var navEl=document.getElementById('nav');
var meta=document.getElementById('searchmeta');

function clearMarks(){document.querySelectorAll('main mark').forEach(function(m){var p=m.parentNode;p.replaceChild(document.createTextNode(m.textContent),m);p.normalize();});}

function doSearch(){
  var q=search.value.toLowerCase().trim();
  if(q.length<2){results.classList.remove('show');results.innerHTML='';navEl.style.display='';meta.textContent='';return;}
  var terms=q.split(/\s+/).filter(Boolean);
  var hits=INDEX.filter(function(e){return matches(e,terms);});
  // sort: phase asc, then heading>cmd>text
  hits.sort(function(a,b){return (a.p-b.p)||(kindRank(a.k)-kindRank(b.k));});
  meta.textContent=hits.length+' match'+(hits.length!==1?'es':'')+' across '+new Set(hits.map(function(h){return h.p;})).size+' phase(s)';
  navEl.style.display='none';
  if(!hits.length){results.innerHTML='<div class="nores">No matches. Try the binary name (evil-winrm), a technique (kerberoast, dcsync, esc1), or a port (445, 1433, 5985).</div>';results.classList.add('show');return;}
  var htmlout='',lastP=null,shown=0,MAX=80;
  for(var i=0;i<hits.length && shown<MAX;i++){
    var h=hits[i];
    if(h.p!==lastP){htmlout+='<div class="res-group">'+esc(h.p)+' — '+esc(h.pt)+'</div>';lastP=h.p;}
    var tag=h.k==='cmd'?'cmd':(h.k==='head'?'section':'note');
    var head=h.k==='head'?h.t:h.h;
    htmlout+='<a class="res" href="#'+h.a+'" data-anchor="'+h.a+'"><span class="rh">'+esc(head)+'<span class="tag">'+tag+'</span></span>'+(h.k!=='head'?'<span class="rs">'+snippet(h.t,q)+'</span>':'')+'</a>';
    shown++;
  }
  if(hits.length>MAX)htmlout+='<div class="nores">Showing first '+MAX+' of '+hits.length+' — refine your search.</div>';
  results.innerHTML=htmlout;results.classList.add('show');
}
search.addEventListener('input',doSearch);

function jump(anchor,q){
  var el=document.getElementById(anchor);
  if(!el)return;
  clearMarks();
  el.scrollIntoView({behavior:'smooth',block:'start'});
  el.classList.remove('flash');void el.offsetWidth;el.classList.add('flash');
  // highlight terms within this element
  if(q){
    var terms=q.split(/\s+/).filter(Boolean);
    highlightIn(el,terms);
  }
}
function highlightIn(root,terms){
  var walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT,null);
  var nodes=[],n;while(n=walker.nextNode())nodes.push(n);
  nodes.forEach(function(node){
    var txt=node.nodeValue,low=txt.toLowerCase(),hit=false;
    terms.forEach(function(t){if(low.indexOf(t)>=0)hit=true;});
    if(!hit)return;
    var frag=document.createDocumentFragment(),last=0,re=new RegExp('('+terms.map(function(t){return t.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');}).join('|')+')','ig'),m;
    while(m=re.exec(txt)){
      if(m.index>last)frag.appendChild(document.createTextNode(txt.slice(last,m.index)));
      var mk=document.createElement('mark');mk.textContent=m[0];frag.appendChild(mk);last=m.index+m[0].length;
    }
    if(last<txt.length)frag.appendChild(document.createTextNode(txt.slice(last)));
    node.parentNode.replaceChild(frag,node);
  });
}
results.addEventListener('click',function(e){
  var a=e.target.closest('.res');if(!a)return;
  e.preventDefault();
  jump(a.dataset.anchor, search.value.toLowerCase().trim());
  if(window.innerWidth<=820)document.getElementById('sidebar').classList.remove('open');
});
search.addEventListener('keydown',function(e){
  if(e.key==='Enter'){var first=results.querySelector('.res');if(first){e.preventDefault();jump(first.dataset.anchor,search.value.toLowerCase().trim());}}
  if(e.key==='Escape'){search.value='';doSearch();clearMarks();}
});

// scrollspy
var links=[].slice.call(document.querySelectorAll('.nav a[data-target]'));
var targets=links.map(function(l){return document.getElementById(l.dataset.target);}).filter(Boolean);
function spy(){var pos=window.scrollY+120,cur=null;targets.forEach(function(t){if(t&&t.offsetTop<=pos)cur=t.id;});links.forEach(function(l){l.classList.toggle('active',l.dataset.target===cur);});}
window.addEventListener('scroll',spy);spy();
// back to top
var bt=document.querySelector('.backtop');
window.addEventListener('scroll',function(){bt.style.display=window.scrollY>500?'block':'none';});
bt.addEventListener('click',function(){window.scrollTo({top:0,behavior:'smooth'});});
// theme
var tt=document.getElementById('themetoggle');
function setTheme(t){document.documentElement.setAttribute('data-theme',t);try{localStorage.setItem('larpers-theme',t);}catch(e){}tt.textContent=t==='light'?'\u25D0 Dark':'\u25D1 Light';}
tt.addEventListener('click',function(){setTheme(document.documentElement.getAttribute('data-theme')==='light'?'dark':'light');});
try{setTheme(localStorage.getItem('larpers-theme')||'dark');}catch(e){setTheme('dark');}
// mobile menu
var mb=document.getElementById('menubtn'),sb=document.getElementById('sidebar');
mb.addEventListener('click',function(){sb.classList.toggle('open');});
document.querySelectorAll('.nav a').forEach(function(a){a.addEventListener('click',function(){if(window.innerWidth<=820)sb.classList.remove('open');});});
// deep-link ?q=
(function(){var m=location.search.match(/[?&]q=([^&]+)/);if(m){search.value=decodeURIComponent(m[1].replace(/\+/g,' '));doSearch();}})();
</script>
</body>
</html>
'''

import datetime
out = (TEMPLATE
       .replace('__NAV__', '\n'.join(nav_html))
       .replace('__SECTIONS__', '\n'.join(sections_html))
       .replace('__INDEX__', INDEX_JSON)
       .replace('__PHASES__', PHASES_JSON)
       .replace('__DATE__', datetime.date.today().isoformat()))

with open(OUT,'w',encoding='utf-8') as f:
    f.write(out)

print("phases:", len(phase_meta))
print("index entries:", len(index))
print("cmd blocks:", sum(1 for e in index if e['k']=='cmd'))
print("bytes:", len(out))
# quick self-checks
low=out.lower()
for probe in ['evil-winrm','kerberoast','certipy','1433','ligolo','esc1','mitm6','pacu']:
    hits=sum(1 for e in index if probe in (e['t']+' '+e['h']).lower())
    print(f"  search '{probe}': {hits} index hits")
