import numpy as np, pickle, time
g=open('smoothgrid.bin','rb').read()
def coords(b):
    v=[]
    for a in range(3):
        x=(b[a]<<24)|(b[3+a]<<16)|(b[6+a]<<8)|b[9+a]
        if x>=1<<31: x-=1<<32
        v.append(x)
    return v
o=2; cur=None; keys=[]; mats=[]; occs=[]
t=time.time()
while o<len(g):
    d=coords(g[o:o+12]); o+=12
    cur=d if cur is None else [cur[k]+d[k] for k in range(3)]
    mat=np.empty(32768,np.uint8); occ=np.empty(32768,np.uint8)
    n=0
    while n<32768:
        h=g[o];o+=1
        m=h&0x3f; oc=255 if m else 0
        if h&0x40: oc=g[o];o+=1
        c=1
        if h&0x80:
            c=g[o]+1;o+=1
            if c==1: o+=1
        mat[n:n+c]=m; occ[n:n+c]=oc; n+=c
    keys.append(tuple(cur)); mats.append(mat); occs.append(occ)
keys=np.array(keys,np.int32); mats=np.stack(mats); occs=np.stack(occs)
print(len(keys),time.time()-t, keys.min(0), keys.max(0))
np.savez_compressed('terrain.npz',keys=keys,mats=mats,occs=occs)
