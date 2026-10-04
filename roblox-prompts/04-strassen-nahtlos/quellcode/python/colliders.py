import pickle, numpy as np, collections
ic,pr,pa=pickle.load(open('place3.pkl','rb'))
def name(i): return pr.get(i,{}).get('Name','?')
memo={}
def path(i):
    if i in memo: return memo[i]
    r=name(i) if (i not in pa or pa[i]==-1) else path(pa[i])+'/'+name(i)
    memo[i]=r; return r
ws=[i for i in ic if ic[i]=='Workspace'][0]
rows=[]
for i,c in ic.items():
    if c not in ('Part','WedgePart','MeshPart','CornerWedgePart','TrussPart','SpawnLocation','Seat','VehicleSeat','UnionOperation'): continue
    p=pr[i]
    if 'Pos' not in p: continue
    pth=path(i)
    if not pth.startswith('Workspace/'): continue
    cc=p.get('CanCollide',1)
    shape={'Part':p.get('shape',1),'SpawnLocation':p.get('shape',1)}.get(c,1)
    kind=0  # box
    if c=='WedgePart': kind=1
    elif c in('Part','SpawnLocation') and shape==2: kind=2   # cylinder
    elif c in('Part','SpawnLocation') and shape==0: kind=3   # ball
    elif c=='CornerWedgePart': kind=4
    elif c in ('MeshPart','UnionOperation'): kind=5
    rows.append((i,kind,cc,p.get('Transparency',0.0),p['Pos'],p['Rot'],p.get('size',(1,1,1)),p.get('Material',256),pth,p.get('CollisionGroup','Default'),p.get('Anchored',1),p.get('CanQuery',1)))
ids=np.array([r[0] for r in rows]); kind=np.array([r[1] for r in rows],np.int8); cc=np.array([r[2] for r in rows],bool)
tr=np.array([r[3] for r in rows],np.float32); C=np.array([r[4] for r in rows],np.float64); R=np.array([np.asarray(r[5]).reshape(3,3) for r in rows]); S=np.array([r[6] for r in rows],np.float64)
mat=np.array([r[7] for r in rows]); paths=[r[8] for r in rows]; cg=[r[9] for r in rows]; anch=np.array([r[10] for r in rows],bool)
# AABB half extents
H=np.einsum('nij,nj->ni',np.abs(R),S/2)
np.savez('colliders.npz',ids=ids,kind=kind,cc=cc,tr=tr,C=C,R=R,S=S,H=H,mat=mat,anch=anch)
pickle.dump((paths,cg),open('collider_meta.pkl','wb'))
print(len(ids),'parts;',cc.sum(),'collidable;',collections.Counter(kind[cc].tolist()), 'unanchored', (~anch).sum())
print(collections.Counter(cg))
# check determinants (mirrored)
det=np.linalg.det(R); print('mirrored (det<0):',(det<0).sum(), 'non-orthonormal:',(np.abs(det-1)>0.01).sum())
