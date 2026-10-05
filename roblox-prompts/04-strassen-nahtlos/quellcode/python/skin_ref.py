"""Reference implementation (Python) of the RoadSmooth skin algorithm. The Luau Core must match this."""
import sys, numpy as np, pickle, collections, time
sys.path.insert(0,'.')
import engine as E
names=np.array([p.rsplit('/',1)[1] for p in E.paths])
ROAD={'Road','RoadFill','RoadRamp','SlitFill','RoadBevel','Asphalt','Joint','JointSquare','Lane','LaneJoint','LaneLink','TurnCircle','EndCap','Deck','Track','Yard'}
EXCL=('/CaseScenes/','/Plots/')
P=dict(G=1.0,SIGMA=2.0,SIGMA2=1.0,LO=0.4,TOL=0.04,OVL=0.25,THICK=0.4,UNDER=3.0,MAXSPLIT=24)
UP=np.array([0.,1.,0.])
def region_of_x(x): return 'Portavia' if x>4000 else ('Metropolis' if x<-4000 else 'Neustadt')
def drivable():
    out=[]
    for j in E.COL:
        if names[j] in ROAD and '/World/' in E.paths[j] and not any(e in E.paths[j] for e in EXCL): out.append(j)
    return np.array(out)
# ---- top face ------------------------------------------------------------
def top_face(j):
    """returns (axisvec_local (3,), type) where type in box-face/tri/disc/slope"""
    M=E.R[j]; k=E.kind[j]; s=E.S[j]
    if k==2:  # cylinder, faces +-X
        sg=1 if M[1,0]>=0 else -1
        return np.array([sg,0,0.]),'disc'
    if k==1:
        cands=[(np.array([1,0,0.]),'tri'),(np.array([-1,0,0.]),'tri'),(np.array([0,-1,0.]),'rect'),(np.array([0,0,1.]),'rect')]
        ns=np.array([0,1,-s[1]/s[2]]); ns/=np.linalg.norm(ns); cands.append((ns,'slope'))
        best=max(cands,key=lambda c:(M@c[0])[1]); return best
    cands=[(np.array(v,float),'rect') for v in ([1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1])]
    return max(cands,key=lambda c:(M@c[0])[1])
def face_samples(j,nloc,ftype,step=1.0):
    """local-space sample points on the top face"""
    s=E.S[j]; h=s/2
    if ftype=='disc':
        r=min(s[1],s[2])/2; pts=[]
        n=max(2,int(np.ceil(r/step)))
        for a in np.linspace(-r,r,2*n+1):
            for b in np.linspace(-r,r,2*n+1):
                if a*a+b*b<=r*r+1e-9: pts.append((nloc[0]*h[0],a,b))
        return np.array(pts)
    if ftype=='tri':  # wedge triangle in local YZ plane: region y <= -h1 + s1*(z/s2+0.5)
        pts=[]; ny=max(2,int(np.ceil(s[1]/step))); nz=max(2,int(np.ceil(s[2]/step)))
        for y in np.linspace(-h[1],h[1],ny+1):
            for z in np.linspace(-h[2],h[2],nz+1):
                if y<= -h[1]+s[1]*(z/s[2]+0.5)+1e-9: pts.append((nloc[0]*h[0],y,z))
        return np.array(pts)
    if ftype=='slope':  # slope face param by x,z
        pts=[]; nx=max(2,int(np.ceil(s[0]/step))); nz=max(2,int(np.ceil(s[2]/step)))
        for x in np.linspace(-h[0],h[0],nx+1):
            for z in np.linspace(-h[2],h[2],nz+1): pts.append((x,-h[1]+s[1]*(z/s[2]+0.5),z))
        return np.array(pts)
    a=int(np.argmax(np.abs(nloc))); others=[i for i in range(3) if i!=a]
    u,v=others; nu=max(2,int(np.ceil(s[u]/step))); nv=max(2,int(np.ceil(s[v]/step)))
    pts=[]
    for x in np.linspace(-h[u],h[u],nu+1):
        for y in np.linspace(-h[v],h[v],nv+1):
            p=np.zeros(3); p[a]=nloc[a]*h[a]; p[u]=x; p[v]=y; pts.append(p)
    return np.array(pts)
# ---- field ----------------------------------------------------------------
class Field:
    def __init__(s,x0,z0,nx,nz,G):
        s.x0,s.z0,s.nx,s.nz,s.G=x0,z0,nx,nz,G
        s.top=np.full((nx,nz),-np.inf); s.own=np.full((nx,nz),-1,np.int64); s.f=None
    def ij(s,x,z): return ((x-s.x0)/s.G).astype(int),((z-s.z0)/s.G).astype(int)
def raster(field,js):
    for j in js:
        c=E.C[j]; h=E.H[j]
        i0=max(0,int(np.floor((c[0]-h[0]-field.x0)/field.G))); i1=min(field.nx-1,int(np.floor((c[0]+h[0]-field.x0)/field.G)))
        k0=max(0,int(np.floor((c[2]-h[2]-field.z0)/field.G))); k1=min(field.nz-1,int(np.floor((c[2]+h[2]-field.z0)/field.G)))
        if i1<i0 or k1<k0: continue
        I,K=np.meshgrid(np.arange(i0,i1+1),np.arange(k0,k1+1),indexing='ij'); I=I.ravel(); K=K.ravel()
        xs=field.x0+(I+0.5)*field.G; zs=field.z0+(K+0.5)*field.G
        lo,hi=E.intervals(xs,zs,np.array([j])); top=hi[:,0]; ok=~np.isnan(top)
        I,K,top=I[ok],K[ok],top[ok]
        cur=field.top[I,K]; upd=top>cur
        field.top[I[upd],K[upd]]=top[upd]; field.own[I[upd],K[upd]]=j
def blur(f,m,sigma):
    r=int(np.ceil(3*sigma)); k=np.exp(-0.5*(np.arange(-r,r+1)/sigma)**2); k/=k.sum()
    def conv(a,ax):
        pad=[(0,0),(0,0)]; pad[ax]=(r,r); ap=np.pad(a,pad); out=np.zeros_like(a)
        for i,w in enumerate(k):
            sl=[slice(None),slice(None)]; sl[ax]=slice(i,i+a.shape[ax]); out+=w*ap[tuple(sl)]
        return out
    num=conv(conv(np.where(m,f,0.0),0),1); den=conv(conv(m.astype(float),0),1)
    with np.errstate(invalid='ignore',divide='ignore'): return np.where(m,num/np.maximum(den,1e-12),np.nan)
def smooth(field):
    m=np.isfinite(field.top); env=np.where(m,field.top,np.nan)
    s=blur(env,m,P['SIGMA']); s=np.maximum(s,env-P['LO'])
    s=blur(s,m,P['SIGMA2']); s=np.maximum(s,env-P['LO'])
    field.f=s; field.m=m; return s
def sample_field(field,xs,zs):
    i,k=field.ij(xs,zs); ok=(i>=0)&(k>=0)&(i<field.nx)&(k<field.nz)
    out=np.full(np.shape(xs),np.nan); out[ok]=field.f[i[ok],k[ok]]; return out
# ---- pieces ------------------------------------------------------------------
def rot_between(a,b):
    a=a/np.linalg.norm(a); b=b/np.linalg.norm(b); v=np.cross(a,b); c=float(a@b); s=np.linalg.norm(v)
    if s<1e-9: return np.eye(3) if c>0 else -np.eye(3)
    vx=np.array([[0,-v[2],v[1]],[v[2],0,-v[0]],[-v[1],v[0],0]])
    return np.eye(3)+vx+vx@vx*((1-c)/(s*s))
def plane_fit(w,f):
    A=np.stack([w[:,0],w[:,2],np.ones(len(w))],1); cf,*_=np.linalg.lstsq(A,f,rcond=None)
    return cf, float(np.abs(A@cf-f).max())
def make_piece(Mw,c,s,kind,nloc,ftype,cf):
    """align part (rotation Mw (rows=world basis per local col convention world=c+Mw@l), center c, size s) so its top face lies on plane y=a x+b z+cc"""
    a,b,cc=cf
    n_new=np.array([-a,1.0,-b]); n_new/=np.linalg.norm(n_new)
    n_old=Mw@nloc; n_old/=np.linalg.norm(n_old)
    Rm=rot_between(n_old,n_new); M2=Rm@Mw
    ax=int(np.argmax(np.abs(nloc))) if ftype!='slope' else 1
    s2=s.copy()
    if ftype=='slope':
        # convert to box: top face = local +Y after alignment of slope normal; keep x,z extents
        s2=np.array([s[0],P['THICK'],np.hypot(s[1],s[2])])
        # local axes for box: Y = n_new, Z = slope direction projected
        zdir=M2@np.array([0,s[1],s[2]])/np.hypot(s[1],s[2])
        zdir-=n_new*(zdir@n_new); zdir/=np.linalg.norm(zdir); xdir=np.cross(n_new,zdir)
        M2=np.stack([xdir,n_new,zdir],1); nloc2=np.array([0,1.,0]); ax=1; kind=0
    else:
        nloc2=nloc
    # top face center in world (before thickness change): c + M2 @ (nloc2*h)
    h=s2/2
    topc_local=np.zeros(3); topc_local[ax]=np.sign(nloc2[ax])*h[ax]
    if ftype=='tri':
        # centroid of triangle in local yz: wedge triangle vertices (y,z): (-h1,-h2),(-h1,h2),(h1,h2) -> centroid (-h1/3, h2/3)
        topc_local[1]=-h[1]/3; topc_local[2]=h[2]/3
    topc=c+M2@topc_local
    topc[1]=a*topc[0]+b*topc[2]+cc
    # thickness & overlap
    s3=s2.copy(); s3[ax]=P['THICK']
    for i in range(3):
        if i!=ax: s3[i]=s3[i]+2*P['OVL']
    if kind==2:  # disc: diameter = y,z
        pass
    center_local_off=np.zeros(3); center_local_off[ax]=np.sign(nloc2[ax])*P['THICK']/2
    if ftype=='tri':
        center_local_off[1]=-topc_local[1]*(s3[1]/s2[1]); center_local_off[2]=-topc_local[2]*(s3[2]/s2[2])
        # top-center expressed relative to new center: (+-T/2, -h1'/3, h2'/3)
        rel=np.array([np.sign(nloc2[0])*P['THICK']/2,-s3[1]/6,s3[2]/6])
        center=topc-M2@rel
    else:
        center=topc-M2@center_local_off
    return dict(kind=int(kind),C=center,M=M2,S=s3)
def build_pieces(field,js,under):
    pieces=[]; stats=collections.Counter()
    for j in js:
        if j in under: stats['under']+=1; continue
        nloc,ftype=top_face(j)
        Mw=E.R[j]; c=E.C[j]; s=E.S[j].copy(); k=E.kind[j]
        if (Mw@nloc)[1]<0.5: stats['steep']+=1; continue   # not a road top (wall-like)
        # split boxes along in-plane axes
        subs=[(c,s)]
        if ftype=='rect' and k in (0,5):
            loc=face_samples(j,nloc,ftype); w=c+loc@Mw.T; f=sample_field(field,w[:,0],w[:,2]); ok=np.isfinite(f)
            if ok.sum()<3: stats['nofield']+=1; continue
            cf,err=plane_fit(w[ok],f[ok])
            if err>P['TOL']:
                a=int(np.argmax(np.abs(nloc))); u,v=[i for i in range(3) if i!=a]
                # number of splits proportional to error, along the longer axis first
                n_u=1; n_v=1
                tot=int(min(P['MAXSPLIT'],np.ceil(np.sqrt(err/P['TOL'])*2)))
                if s[u]>=s[v]: n_u=max(1,min(tot,int(s[u]//2))); n_v=max(1,min(int(np.ceil(tot*s[v]/s[u])),int(s[v]//2)))
                else: n_v=max(1,min(tot,int(s[v]//2))); n_u=max(1,min(int(np.ceil(tot*s[u]/s[v])),int(s[u]//2)))
                subs=[]
                for iu in range(n_u):
                    for iv in range(n_v):
                        off=np.zeros(3); off[u]=-s[u]/2+(iu+0.5)*s[u]/n_u; off[v]=-s[v]/2+(iv+0.5)*s[v]/n_v
                        ss=s.copy(); ss[u]=s[u]/n_u; ss[v]=s[v]/n_v
                        subs.append((c+Mw@off,ss))
                stats['split']+=1
        for (cc_,ss_) in subs:
            # samples for this sub-part
            j_tmp=None
            hs=ss_/2
            loc=face_samples_generic(k,nloc,ftype,ss_)
            w=cc_+loc@Mw.T; f=sample_field(field,w[:,0],w[:,2]); ok=np.isfinite(f)
            if ok.sum()<3: stats['nofield']+=1; continue
            cf,err=plane_fit(w[ok],f[ok])
            pc=make_piece(Mw,cc_,ss_,k if k!=5 else 0,nloc,ftype,cf)
            pc['src']=int(j); pc['err']=err
            pieces.append(pc); stats['pieces']+=1
    return pieces,stats
def face_samples_generic(k,nloc,ftype,s):
    class Tmp: pass
    # reuse face_samples with temp size
    old=E.S[0].copy()
    return _fs(k,nloc,ftype,s)
def _fs(k,nloc,ftype,s,step=1.0):
    h=s/2
    if ftype=='disc':
        r=min(s[1],s[2])/2; n=max(2,int(np.ceil(r/step))); pts=[]
        for a in np.linspace(-r,r,2*n+1):
            for b in np.linspace(-r,r,2*n+1):
                if a*a+b*b<=r*r+1e-9: pts.append((nloc[0]*h[0],a,b))
        return np.array(pts)
    if ftype=='tri':
        pts=[]; ny=max(2,int(np.ceil(s[1]/step))); nz=max(2,int(np.ceil(s[2]/step)))
        for y in np.linspace(-h[1],h[1],ny+1):
            for z in np.linspace(-h[2],h[2],nz+1):
                if y<= -h[1]+s[1]*(z/s[2]+0.5)+1e-9: pts.append((nloc[0]*h[0],y,z))
        return np.array(pts)
    if ftype=='slope':
        pts=[]; nx=max(2,int(np.ceil(s[0]/step))); nz=max(2,int(np.ceil(s[2]/step)))
        for x in np.linspace(-h[0],h[0],nx+1):
            for z in np.linspace(-h[2],h[2],nz+1): pts.append((x,-h[1]+s[1]*(z/s[2]+0.5),z))
        return np.array(pts)
    a=int(np.argmax(np.abs(nloc))); u,v=[i for i in range(3) if i!=a]
    nu=max(2,int(np.ceil(s[u]/step))); nv=max(2,int(np.ceil(s[v]/step))); pts=[]
    for x in np.linspace(-h[u],h[u],nu+1):
        for y in np.linspace(-h[v],h[v],nv+1):
            p=np.zeros(3); p[a]=nloc[a]*h[a]; p[u]=x; p[v]=y; pts.append(p)
    return np.array(pts)
def find_under(js):
    """drivable parts that lie under another drivable part (>UNDER above) on >=30% of their top samples"""
    under=set(); Jset=set(js.tolist())
    for j in js:
        nloc,ft=top_face(j)
        loc=_fs(E.kind[j],nloc,ft,E.S[j],step=2.0); w=E.C[j]+loc@E.R[j].T
        cnt=0
        J=E.cands(E.C[j,0],E.C[j,2],pad=max(E.H[j,0],E.H[j,2]))
        J=np.array([x for x in J if x in Jset and x!=j])
        if len(J)==0: continue
        lo,hi=E.intervals(w[:,0],w[:,2],J)
        above=(lo>w[:,1:2]+P['UNDER'])
        frac=np.mean(np.any(above,1))
        if frac>=0.3: under.add(int(j))
    return under
if __name__=='__main__':
    t0=time.time()
    js=drivable(); print('drivable parts',len(js))
    under=find_under(js); print('under parts',len(under),[E.paths[j].split('/World/')[1] for j in list(under)[:12]])
    out={}
    for reg,(x0,x1,z0,z1) in {'Neustadt':(-1300,2100,-900,2700),'Portavia':(6800,9400,-1200,1600),'Metropolis':(-9400,-6400,-1200,1800)}.items():
        jr=np.array([j for j in js if x0<=E.C[j,0]<=x1 and j not in under])
        F=Field(x0,z0,int((x1-x0)/P['G']),int((z1-z0)/P['G']),P['G'])
        raster(F,jr); smooth(F)
        pcs,st=build_pieces(F,jr,under)
        print(reg,'parts',len(jr),st,'err pct',np.percentile([p['err'] for p in pcs],[50,90,99]).round(3),time.time()-t0)
        out[reg]=dict(field=F,pieces=pcs,parts=jr)
    pickle.dump((out,under),open('skin_ref.pkl','wb'),protocol=4)
