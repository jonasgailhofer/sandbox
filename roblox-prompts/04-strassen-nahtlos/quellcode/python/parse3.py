import struct, lz4.block, zstandard, pickle, collections, sys
import numpy as np
F=sys.argv[1]
d=open(F,'rb').read()
p=32
def u32be(b,n):
    a=np.frombuffer(b[:4*n],dtype=np.uint8).reshape(4,n).T.copy()
    return a.view('>u4').reshape(n).astype(np.int64)
def ints(b,n):
    v=u32be(b,n); return ((v>>1) ^ -(v&1))
def floats(b,n):
    v=u32be(b,n).astype(np.uint32); v=((v>>1)|(v<<31)).astype(np.uint32); return v.view(np.float32)
def refs(b,n): return np.cumsum(ints(b,n)).tolist()
VEC=[(1,0,0),(0,1,0),(0,0,1),(-1,0,0),(0,-1,0),(0,0,-1)]
def special(idv):
    k=idv-1; r0=np.array(VEC[k//6],float); r1=np.array(VEC[k%6],float); r2=np.cross(r0,r1)
    return np.array([r0,r1,r2]).flatten()
classes={}; inst_class={}; props=collections.defaultdict(dict); parent={}
STRPROPS={'Name','Source','MeshId','CollisionGroup','Text','SmoothGrid','AttributesSerialize','Tags','MaterialVariant','TextureID','Texture'}
while p<len(d):
    name=d[p:p+4]; clen,ulen=struct.unpack_from('<II',d,p+4); p+=16
    if clen==0: body=d[p:p+ulen]; p+=ulen
    else:
        raw=d[p:p+clen]; p+=clen
        body=zstandard.ZstdDecompressor().decompress(raw,max_output_size=ulen) if raw[:4]==b'\x28\xb5\x2f\xfd' else lz4.block.decompress(raw,uncompressed_size=ulen)
    if name==b'END\0': break
    if name==b'INST':
        cid,=struct.unpack_from('<I',body,0); sl,=struct.unpack_from('<I',body,4); cn=body[8:8+sl].decode()
        q=8+sl; fmt=body[q]; n,=struct.unpack_from('<I',body,q+1); q+=5
        ids=refs(body[q:],n); classes[cid]=(cn,ids)
        for i in ids: inst_class[i]=cn
    elif name==b'PROP':
        cid,=struct.unpack_from('<I',body,0); sl,=struct.unpack_from('<I',body,4); pn=body[8:8+sl].decode('latin1')
        q=8+sl; t=body[q]; q+=1; b=body[q:]
        cn,ids=classes[cid]; n=len(ids)
        vals=None
        try:
            if t==1:
                vals=[];o=0
                for i in range(n):
                    l,=struct.unpack_from('<I',b,o); vals.append(b[o+4:o+4+l]); o+=4+l
                if pn in STRPROPS:
                    if pn not in ('SmoothGrid','AttributesSerialize','Tags'): vals=[v.decode('utf8','replace') for v in vals]
                else: vals=None
            elif t==2: vals=list(b[:n])
            elif t==3: vals=ints(b,n).tolist()
            elif t==4: vals=floats(b,n).tolist()
            elif t==0x0C: vals=list(zip(floats(b,n).tolist(),floats(b[4*n:],n).tolist(),floats(b[8*n:],n).tolist()))
            elif t==0x0E: vals=list(zip(floats(b,n).tolist(),floats(b[4*n:],n).tolist(),floats(b[8*n:],n).tolist()))
            elif t==0x12: vals=u32be(b,n).tolist()
            elif t==0x1A: vals=list(zip(b[:n],b[n:2*n],b[2*n:3*n]))
            elif t==0x10 and pn=='CFrame':
                o=0; rots=[]
                for i in range(n):
                    if b[o]==0: rots.append(np.array(struct.unpack_from('<9f',b,o+1))); o+=37
                    else: rots.append(special(b[o])); o+=1
                xs=floats(b[o:],n);ys=floats(b[o+4*n:],n);zs=floats(b[o+8*n:],n)
                for i,r,x,y,z in zip(ids,rots,xs,ys,zs): props[i]['Pos']=(float(x),float(y),float(z)); props[i]['Rot']=r
                vals=None
        except Exception as e: print('err',cn,pn,t,e)
        if vals is not None:
            for i,v in zip(ids,vals): props[i][pn]=v
    elif name==b'PRNT':
        n,=struct.unpack_from('<I',body,1)
        ch=refs(body[5:],n); pa=refs(body[5+4*n:],n)
        parent.update(zip(ch,pa))
pickle.dump((inst_class,dict(props),parent),open(sys.argv[2],'wb'),protocol=4)
for i,c in inst_class.items():
    if c=='Terrain' and 'SmoothGrid' in props[i]:
        open('smoothgrid.bin','wb').write(props[i]['SmoothGrid'])
c=collections.Counter(inst_class.values())
print(len(inst_class)); print(c.most_common(25))
