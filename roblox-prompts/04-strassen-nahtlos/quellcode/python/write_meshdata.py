import pickle, sys
src = sys.argv[1] if len(sys.argv) > 1 else 'meshes/meshdata.pkl'
res = pickle.load(open(src, 'rb'))
L = ['-- RoadSmooth.MeshData: automatisch erzeugt (Strassen-Meshes aus der geglaetteten Flaeche). Nicht von Hand bearbeiten.',
     '-- objs: name = Objektname in der OBJ-Datei, cls = A (Asphalt) | K (Kopfstein) | S (Schotter), min/max = Weltbox.',
     'return {']
for city in ['Neustadt', 'Portavia', 'Metropolis']:
    d = res[city]
    L.append(f'\t{city} = {{')
    L.append('\t\tlook = { ' + ', '.join(f'{k} = {{ "{v[0]}", "{v[1]}" }}' for k, v in sorted(d['look'].items())) + ' },')
    L.append('\t\tobjs = {')
    for o in d['objs']:
        mn = ', '.join('%.4f' % v for v in o['min']); mx = ', '.join('%.4f' % v for v in o['max'])
        L.append(f'\t\t\t{{ name = "{o["name"]}", cls = "{o["cls"]}", tris = {o["tris"]}, min = {{ {mn} }}, max = {{ {mx} }} }},')
    L.append('\t\t},')
    L.append('\t},')
L.append('}')
open('luau/MeshData.luau', 'w').write('\n'.join(L) + '\n')
print('meshes', sum(len(res[c]['objs']) for c in res), 'tris', sum(o['tris'] for c in res for o in res[c]['objs']), 'max', max(o['tris'] for c in res for o in res[c]['objs']))
