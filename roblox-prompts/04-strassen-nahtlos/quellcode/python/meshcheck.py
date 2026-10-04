import sys, numpy as np, pickle, math
sys.path.insert(0,'.')
from PIL import Image, ImageDraw
import meshgen as MG
city=sys.argv[1]; d=sys.argv[2] if len(sys.argv)>2 else 'meshes'
F,final=pickle.load(open(f'{d}/field_{city}.pkl','rb'))
ff=MG.filled_field(F)
fn=lambda x,z: MG.bilinear(F,ff,x,z)
V=[];N=[];objs=[];cur=None
for line in open(f'{d}/Strassen_{city}.obj'):
    if line.startswith('o '): cur=dict(name=line.split()[1],faces=[]); objs.append(cur)
    elif line.startswith('v '): V.append(list(map(float,line.split()[1:4])))
    elif line.startswith('vn '): N.append(list(map(float,line.split()[1:4])))
    elif line.startswith('f '):
        cur['faces'].append([int(t.split('/')[0])-1 for t in line.split()[1:4]])
V=np.array(V); print(city,'verts',len(V),'objects',len(objs),'faces',sum(len(o['faces']) for o in objs))
# vertical error of flat faces (normal y>0.5) at centroid/edge midpoints
errs=[]; tops=[]
for o in objs:
    Fc=np.array(o['faces'])
    a,b,c=V[Fc[:,0]],V[Fc[:,1]],V[Fc[:,2]]
    n=np.cross(b-a,c-a); up=n[:,1]/np.maximum(np.linalg.norm(n,axis=1),1e-9)
    top=up>0.5; tops.append(Fc[top])
    for w in ((1/3,1/3,1/3),(0.5,0.5,0),(0,0.5,0.5),(0.5,0,0.5)):
        p=w[0]*a[top]+w[1]*b[top]+w[2]*c[top]
        f=fn(p[:,0],p[:,2]); errs.append(np.abs(p[:,1]-f))
    down=(up<-0.5).sum()
    if down: print('  WARN downward faces',o['name'],down)
e=np.concatenate(errs); print('  |mesh-field| pct',np.nanpercentile(e,[50,90,99,99.9]).round(3),'max',np.nanmax(e).round(3))
# coverage raster vs final footprint
T=np.concatenate(tops)
minx,minz=V[:,0].min(),V[:,2].min(); maxx,maxz=V[:,0].max(),V[:,2].max()
sc=1.0
W=int((maxx-minx)/sc)+2; H=int((maxz-minz)/sc)+2
img=Image.new('L',(W,H),0); dr=ImageDraw.Draw(img)
for t in T:
    pts=[((V[i,0]-minx)/sc,(V[i,2]-minz)/sc) for i in t]; dr.polygon(pts,fill=255)
cov=np.array(img)>0
import shapely
xs=np.arange(W)*sc+minx+0.5*sc; zs=np.arange(H)*sc+minz+0.5*sc
X,Z=np.meshgrid(xs,zs)
from shapely.ops import unary_union
fp=unary_union([g for g in final.values() if not g.is_empty])
inside=shapely.contains_xy(fp,X.ravel(),Z.ravel()).reshape(X.shape)
print('  footprint cells',inside.sum(),'covered by mesh',(inside&cov).sum()/inside.sum(),'mesh outside footprint',(cov&~inside).sum()/max(1,cov.sum()))
# hillshade preview
ny=np.zeros((H,W)); 
shade=Image.new('RGB',(W,H),(25,30,25)); sd=ImageDraw.Draw(shade)
L=np.array([-0.5,0.8,-0.3]); L/=np.linalg.norm(L)
for o in objs:
    cls=o['name'].split('_')[2]; base={'A':(70,72,80),'K':(140,128,110),'S':(200,185,140)}.get(cls,(150,150,150))
    for t in o['faces']:
        a,b,c=V[t[0]],V[t[1]],V[t[2]]; n=np.cross(b-a,c-a); ln=np.linalg.norm(n)
        if ln<1e-9: continue
        n/=ln
        if n[1]<0.5: continue
        k=0.55+0.6*max(0,n@L)
        col=tuple(int(min(255,ch*k)) for ch in base)
        sd.polygon([((V[i,0]-minx)/sc,(V[i,2]-minz)/sc) for i in t],fill=col)
shade.save(f'{d}/preview_{city}.png'); print('  preview',shade.size)
