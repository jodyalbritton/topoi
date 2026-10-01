# Throwaway probe used 2026-10-01 to size the turn-normalization rules in PRD §13 against the ElevenLabs sample.
# Not app code; the app is Elixir. Kept so the thresholds can be re-derived when the sample set grows.
import re, json, sys
p="/Users/jody/Work/debate-dossier/samples/xh9D0oLxwQg.elevenlabs.srt.txt"
raw=open(p).read()
pat=re.compile(r'(\d\d):(\d\d):(\d\d),(\d{3}) --> (\d\d):(\d\d):(\d\d),(\d{3}) \[Speaker (\d+)\]\n(.*?)(?:\n\n|\n?$)', re.S)
segs=[]
for m in pat.finditer(raw):
    g=list(map(int,m.groups()[:8])); spk=int(m.group(9)); txt=m.group(10).strip()
    s=g[0]*3600+g[1]*60+g[2]+g[3]/1000; e=g[4]*3600+g[5]*60+g[6]+g[7]/1000
    segs.append(dict(s=s,e=e,spk=spk,txt=txt))
print("segments",len(segs))
# 1. merge consecutive same-speaker segments regardless of gap (a turn ends only when the other speaker holds the floor)
GAP=4.0
turns=[]
for sg in segs:
    if turns and turns[-1]['spk']==sg['spk'] and sg['s']-turns[-1]['e']<=GAP:
        turns[-1]['e']=sg['e']; turns[-1]['txt']+=' '+sg['txt']; turns[-1]['n']+=1
    else:
        turns.append(dict(s=sg['s'],e=sg['e'],spk=sg['spk'],txt=sg['txt'],n=1))
print("turns after same-speaker merge (gap<=%.0fs)"%GAP,len(turns))
# 2. backchannel: short, few words, no question mark
def words(t): return len(re.findall(r"[A-Za-z']+",t))
BC_SEC, BC_WORDS = 2.0, 6
bc=[t for t in turns if (t['e']-t['s'])<BC_SEC and words(t['txt'])<=BC_WORDS and '?' not in t['txt']]
print("backchannel turns",len(bc))
subst=[t for t in turns if t not in bc]
print("substantive turns",len(subst))
# 3. re-merge across backchannels: A talks, B says 'yeah', A continues -> one A turn
merged=[]
i=0
for t in turns:
    if t in bc:
        merged.append(t); continue
    # look back: last substantive turn
    k=len(merged)-1
    while k>=0 and merged[k] in bc: k-=1
    if k>=0 and merged[k]['spk']==t['spk'] and t['s']-merged[k]['e']<=8.0:
        merged[k]['e']=t['e']; merged[k]['txt']+=' '+t['txt']; merged[k]['n']+=t['n']
    else:
        merged.append(t)
subst2=[t for t in merged if t not in bc]
print("substantive turns after bridging backchannels",len(subst2))
import statistics
durs=[t['e']-t['s'] for t in subst2]; wc=[words(t['txt']) for t in subst2]
print("mean dur %.1fs median %.1fs max %.0fs; mean words %.0f median %.0f"%(statistics.mean(durs),statistics.median(durs),max(durs),statistics.mean(wc),statistics.median(wc)))
for spk in (0,1):
    print("spk",spk,"turns",sum(1 for t in subst2 if t['spk']==spk),"talk-seconds %.0f"%sum(t['e']-t['s'] for t in subst2 if t['spk']==spk))
# disfluency density
fillers=sum(len(re.findall(r"\b(um|uh|like|you know)\b",t['txt'],re.I)) for t in subst2)
tot=sum(wc); print("filler tokens %d of %d words (%.1f%%)"%(fillers,tot,100*fillers/tot))
# where does argument start? first turn > 40 words
for t in subst2:
    if words(t['txt'])>40:
        print("first long turn at %.0fs spk%d words %d"%(t['s'],t['spk'],words(t['txt']))); break
json.dump(subst2,open("turns.json","w"))
