import sys, pickle
sys.argv = ['x', 'meshes_tmp']
sys.path.insert(0, '.')
import numpy as np
import meshgen as MG
import engine as E
cities = ['Neustadt', 'Portavia', 'Metropolis']
for city in cities:
    js = MG.collect(city)
    under = MG.find_under(js)
    js2 = np.array([j for j in js if int(j) not in under])
    with open(f'luau/data_{city}.luau', 'w') as f:
        f.write('return {\n')
        for j in js2:
            R = E.R[j]; C = E.C[j]; S = E.S[j]
            f.write('{k=%d,x=%.4f,y=%.4f,z=%.4f,r={%s},sx=%.4f,sy=%.4f,sz=%.4f,id=%d},\n' % (
                int(E.kind[j]), C[0], C[1], C[2], ','.join('%.6f' % v for v in R.reshape(-1)), S[0], S[1], S[2], int(j)))
        f.write('}\n')
    F = MG.build_field(js2)
    pickle.dump(dict(x0=F.x0, z0=F.z0, G=F.G, f=F.f, mask=F.mask, nx=F.nx, nz=F.nz), open(f'cmp_field_{city}.pkl', 'wb'), protocol=4)
    print(city, 'parts', len(js), 'under', len(under), 'data', len(js2), 'gapcells', int((F.mask == 2).sum()), flush=True)
    pickle.dump(sorted(under), open(f'under_{city}.pkl', 'wb'))
