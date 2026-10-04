import numpy as np
D=np.load('terrain.npz'); keys,mats,occs=D['keys'],D['mats'],D['occs']
def build(order):
    # order: 'xz' means index = y*1024 + x*32 + z ; 'zx' means y*1024 + z*32 + x
    xs=keys[:,0]; zs=keys[:,2]
    X0,X1,Z0,Z1=xs.min(),xs.max(),zs.min(),zs.max()
    nx=(X1-X0+1)*32; nz=(Z1-Z0+1)*32
    H=np.full((nx,nz),-1e9,np.float32); MT=np.zeros((nx,nz),np.uint8)
    for k,(cx,cy,cz) in enumerate(keys):
        m=mats[k].reshape(32,32,32); o=occs[k].reshape(32,32,32)
        if order=='zx': m=m.transpose(0,2,1); o=o.transpose(0,2,1)
        solid=(m!=0)&(m!=1)
        if not solid.any(): continue
        # top solid voxel index along y
        ys=np.arange(32)[:,None,None]
        top=np.where(solid,ys,-1).max(0)   # (x,z)
        has=top>=0
        ti=np.clip(top,0,31)
        oc=np.take_along_axis(o,ti[None],0)[0]/255.0
        mt=np.take_along_axis(m,ti[None],0)[0]
        h=(cy*32+ti)*4.0 + oc*4.0   # approx surface
        sx=(cx-X0)*32; sz=(cz-Z0)*32
        cur=H[sx:sx+32,sz:sz+32]
        upd=has&(h>cur)
        cur[upd]=h[upd]; MT[sx:sx+32,sz:sz+32][upd]=mt[upd]
    return H,MT,X0*128,Z0*128

if __name__ == '__main__':
    H, MT, ox, oz = build('zx')   # Voxel-Reihenfolge: y langsam, dann z, x am schnellsten
    np.save('H_zx.npy', H); np.save('MT_zx.npy', MT); open('origin_zx.txt', 'w').write(f'{ox} {oz}')
    print('Hoehenkarte', H.shape, ox, oz)
