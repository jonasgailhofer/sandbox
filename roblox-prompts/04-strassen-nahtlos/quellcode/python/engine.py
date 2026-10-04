import numpy as np, pickle, collections
D=np.load('colliders.npz')
ids,kind,cc,tr,C,R,S,H=D['ids'],D['kind'],D['cc'],D['tr'],D['C'],D['R'],D['S'],D['H']
mat=D['mat']
paths,cgs=pickle.load(open('collider_meta.pkl','rb'))
COL=np.where(cc)[0]
CELL=16.0
grid=collections.defaultdict(list)
for j in COL:
    x0=int(np.floor((C[j,0]-H[j,0])/CELL)); x1=int(np.floor((C[j,0]+H[j,0])/CELL))
    z0=int(np.floor((C[j,2]-H[j,2])/CELL)); z1=int(np.floor((C[j,2]+H[j,2])/CELL))
    if (x1-x0+1)*(z1-z0+1)>4000:  # giant parts: register anyway (coarse)
        pass
    for gx in range(x0,x1+1):
        for gz in range(z0,z1+1):
            grid[(gx,gz)].append(j)
grid={k:np.array(v) for k,v in grid.items()}
# terrain
TH=np.load('H_zx.npy'); TOX,TOZ=map(float,open('origin_zx.txt').read().split())
TERRAIN_OFFSET=1.9
def terrain_top(x,z):
    ix=((np.asarray(x)-TOX)//4).astype(int); iz=((np.asarray(z)-TOZ)//4).astype(int)
    ok=(ix>=0)&(iz>=0)&(ix<TH.shape[0])&(iz<TH.shape[1])
    out=np.full(np.shape(x),-1e9)
    out[ok]=TH[ix[ok],iz[ok]]+TERRAIN_OFFSET
    out[out<-1e8]=-1e9
    return out
def cands(x,z,pad=0.0):
    gx0=int(np.floor((x-pad)/CELL)); gx1=int(np.floor((x+pad)/CELL)); gz0=int(np.floor((z-pad)/CELL)); gz1=int(np.floor((z+pad)/CELL))
    arrs=[grid[k] for k in ((a,b) for a in range(gx0,gx1+1) for b in range(gz0,gz1+1)) if k in grid]
    if not arrs: return np.zeros(0,int)
    return np.unique(np.concatenate(arrs))
BIG=1e9
def intervals(xs,zs,J):
    """vertical line intervals for points (xs,zs) [n] against colliders J [m] -> lo,hi [n,m] (nan if none)"""
    xs=np.asarray(xs,float)[:,None]; zs=np.asarray(zs,float)[:,None]
    M=R[J]; c=C[J]; s=S[J]; k=kind[J]
    dx=xs-c[None,:,0]; dz=zs-c[None,:,2]; dy=-c[None,:,1]
    # a_k = M[0,k]dx + M[1,k]dy + M[2,k]dz ; b_k = M[1,k]
    a=(M[None,:,0,:]*dx[...,None]+M[None,:,1,:]*dy[...,None]+M[None,:,2,:]*dz[...,None])  # n,m,3
    b=M[None,:,1,:]  # 1,m,3
    hs=s/2
    lo=np.full(a.shape[:2],-BIG); hi=np.full(a.shape[:2],BIG)
    def plane(n,d,mask):
        # n: (m,3) or (3,), d:(m,)
        na=(a*n).sum(-1); nb=(b*n).sum(-1)
        with np.errstate(divide='ignore',invalid='ignore'):
            t=(d-na)/nb
        up=(nb>1e-9); dn=(nb<-1e-9); par=~(up|dn)
        nonlocal lo,hi
        hi=np.where(mask&up,np.minimum(hi,t),hi)
        lo=np.where(mask&dn,np.maximum(lo,t),lo)
        bad=mask&par&(na>d)
        hi=np.where(bad,-BIG,hi)
    m=len(J); ones=np.ones(m,bool)[None,:]
    boxlike=(k==0)|(k==1)|(k==4)|(k==5)|(k==2)
    E=np.eye(3)
    for ax in range(3):
        if ax==1:
            # top: box -> y<=hs, wedge -> y - (sy/sz) z <= 0
            nb_box=np.tile(E[1],(m,1)); d_box=hs[:,1]
            nw=np.stack([np.zeros(m),np.ones(m),-s[:,1]/s[:,2]],1); dw=np.zeros(m)
            isw=(k==1)
            nn=np.where(isw[:,None],nw,nb_box); dd=np.where(isw,dw,d_box)
            plane(nn[None],dd[None],(boxlike&(k!=2))[None,:]|np.zeros_like(lo,bool))
            plane(-E[1][None,None],hs[None,:,1],(boxlike&(k!=2))[None,:]|np.zeros_like(lo,bool))
        elif ax==0:
            plane(E[0][None,None],hs[None,:,0],boxlike[None,:]|np.zeros_like(lo,bool))
            plane(-E[0][None,None],hs[None,:,0],boxlike[None,:]|np.zeros_like(lo,bool))
        else:
            plane(E[2][None,None],hs[None,:,2],(boxlike&(k!=2))[None,:]|np.zeros_like(lo,bool))
            plane(-E[2][None,None],hs[None,:,2],(boxlike&(k!=2))[None,:]|np.zeros_like(lo,bool))
    # cylinder radial (axis x): (a_y+t b_y)^2+(a_z+t b_z)^2 <= r^2
    cyl=(k==2)
    if cyl.any():
        r=np.minimum(s[:,1],s[:,2])/2
        A=b[...,1]**2+b[...,2]**2; B=2*(a[...,1]*b[...,1]+a[...,2]*b[...,2]); Cq=a[...,1]**2+a[...,2]**2-r[None,:]**2
        A=np.broadcast_to(A,B.shape)
        disc=B*B-4*A*Cq
        with np.errstate(divide='ignore',invalid='ignore'):
            sq=np.sqrt(np.maximum(disc,0)); t1=(-B-sq)/(2*A); t2=(-B+sq)/(2*A)
        vert=A<1e-9
        cl=np.where(vert, np.where(Cq<=0,-BIG,BIG), np.where(disc>=0,t1,BIG))
        ch=np.where(vert, np.where(Cq<=0,BIG,-BIG), np.where(disc>=0,t2,-BIG))
        lo=np.where(cyl[None,:],np.maximum(lo,cl),lo); hi=np.where(cyl[None,:],np.minimum(hi,ch),hi)
    ball=(k==3)
    if ball.any():
        r=np.min(s,1)/2
        B=2*(a*b).sum(-1); Cq=(a*a).sum(-1)-r[None,:]**2; disc=B*B-4*Cq
        sq=np.sqrt(np.maximum(disc,0)); t1=(-B-sq)/2; t2=(-B+sq)/2
        lo=np.where(ball[None,:],np.where(disc>=0,t1,BIG),lo); hi=np.where(ball[None,:],np.where(disc>=0,t2,-BIG),hi)
    valid=lo<=hi
    lo=np.where(valid,lo,np.nan); hi=np.where(valid,hi,np.nan)
    return lo,hi
