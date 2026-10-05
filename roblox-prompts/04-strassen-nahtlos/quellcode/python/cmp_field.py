import pickle, numpy as np, sys, collections
SUF = sys.argv[1] if len(sys.argv) > 1 else 'new'
for city in ['Neustadt', 'Portavia', 'Metropolis']:
    D = pickle.load(open(f'cmp_field_{city}.pkl', 'rb'))
    diffs = {1: [], 2: []}; mm = collections.Counter(); head = []
    for line in open(f'luau_out_{city}.{SUF}.txt'):
        if line.startswith('# '): head.append(line.strip()); continue
        if not line.startswith('F '): continue
        _, x, z, f, m = line.split(); m = int(m)
        i = int(float(x) - D['x0']); k = int(float(z) - D['z0'])
        if not (0 <= i < D['nx'] and 0 <= k < D['nz']): mm['oob'] += 1; continue
        pm = int(D['mask'][i, k])
        mm[(m, pm)] += 1
        if pm == m: diffs[m].append(float(f) - D['f'][i, k])
    print(city, ' | '.join(head))
    print('  mask pairs (luau, python):', dict(mm))
    for m in (1, 2):
        a = np.abs(np.array(diffs[m]))
        if len(a): print(f'  mask {m}: n {len(a)}  |diff| p50 {np.percentile(a,50):.4f} p99 {np.percentile(a,99):.4f} max {a.max():.4f}')
