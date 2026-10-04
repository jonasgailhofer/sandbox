"""Generate seamless road meshes (OBJ) + MeshData.luau from the same smoothed field the RoadSmooth skin uses."""
import sys, numpy as np, pickle, collections, time, math, os
sys.path.insert(0, '.')
import engine as E
import skin_ref as S
import shapely
from shapely.geometry import Polygon, MultiPolygon, box
from shapely.ops import unary_union
import triangle as tr

OUT = sys.argv[1] if len(sys.argv) > 1 else 'meshes'
os.makedirs(OUT, exist_ok=True)
names = np.array([p.rsplit('/', 1)[1] for p in E.paths])
ROAD = {'Road', 'RoadFill', 'RoadRamp', 'SlitFill', 'RoadBevel', 'Asphalt', 'Joint', 'JointSquare', 'Lane', 'LaneJoint',
        'LaneLink', 'TurnCircle', 'EndCap', 'Deck', 'Track', 'Yard'}
EXCL = {'CaseScenes', 'Plots', 'FahrHaut', 'StrassenMesh', 'StrassenMesh2', 'Landschaft', 'Fleet', 'Decor', 'Trading', 'Hub', 'Staging'}
MAT = {256: 'Plastic', 272: 'SmoothPlastic', 816: 'Concrete', 836: 'Pavement', 880: 'Cobblestone', 1376: 'Asphalt', 1360: 'Ground', 864: 'Pebble', 1088: 'Metal', 512: 'Wood', 528: 'WoodPlanks', 1296: 'Sand', 800: 'Slate', 848: 'Brick', 832: 'Granite'}
P = dict(SIMPLIFY=0.15, TILE=512, MAXAREA=60.0, MINAREA=1.5, VTOL=0.05, DENS=4.0, CLOSE=2.0, ROUND=0.3, SKIRT=0.6, MAXTRI=18000)

def city_of_x(x): return 'Portavia' if x > 4000 else ('Metropolis' if x < -4000 else 'Neustadt')

def collect(city):
    out = []
    for j in E.COL:
        if names[j] not in ROAD or E.kind[j] in (5,): continue
        segs = E.paths[j].split('/')
        if segs[1] != 'World' or any(s in EXCL for s in segs[2:-1]): continue
        if city_of_x(E.C[j, 0]) != city: continue
        out.append(j)
    return np.array(out)

# -------------------------------------------------------------------------------------------- field (mirror of Core.Smooth)
def build_field(js):
    x0 = min(E.C[j, 0] - E.H[j, 0] for j in js); x1 = max(E.C[j, 0] + E.H[j, 0] for j in js)
    z0 = min(E.C[j, 2] - E.H[j, 2] for j in js); z1 = max(E.C[j, 2] + E.H[j, 2] for j in js)
    x0, z0 = math.floor(x0) - 8, math.floor(z0) - 8; x1, z1 = math.ceil(x1) + 8, math.ceil(z1) + 8
    F = S.Field(x0, z0, int(math.ceil(x1 - x0)), int(math.ceil(z1 - z0)), 1.0)
    S.raster(F, js)
    m = np.isfinite(F.top)
    env = np.where(m, F.top, np.nan)
    s = S.blur(env, m, 2.0); s = np.maximum(s, env - 0.4)
    s = S.blur(s, m, 1.0); s = np.maximum(s, env - 0.4)
    # gap closing r=2 (disc), weighted interpolation sigma 2 within radius 6
    def dil(a, r):
        o = a.copy()
        for di in range(-r, r + 1):
            for dk in range(-r, r + 1):
                if di * di + dk * dk <= r * r:
                    sh = np.zeros_like(a)
                    xs = slice(max(0, di), a.shape[0] + min(0, di)); xd = slice(max(0, -di), a.shape[0] + min(0, -di))
                    zs = slice(max(0, dk), a.shape[1] + min(0, dk)); zd = slice(max(0, -dk), a.shape[1] + min(0, -dk))
                    sh[xs, zs] = a[xd, zd]
                    o |= sh
        return o
    closed = ~dil(~dil(m, 2), 2)
    gap = closed & ~m
    num = np.zeros_like(s); den = np.zeros_like(s)
    sv = np.where(m, s, 0.0)
    for di in range(-6, 7):
        for dk in range(-6, 7):
            w = math.exp(-0.5 * (di * di + dk * dk) / 4.0)
            sh = np.zeros_like(s); shm = np.zeros_like(s)
            xs = slice(max(0, di), s.shape[0] + min(0, di)); xd = slice(max(0, -di), s.shape[0] + min(0, -di))
            zs = slice(max(0, dk), s.shape[1] + min(0, dk)); zd = slice(max(0, -dk), s.shape[1] + min(0, -dk))
            sh[xs, zs] = sv[xd, zd]; shm[xs, zs] = m[xd, zd]
            num += w * sh; den += w * shm
    g = gap & (den > 1e-9)
    s = np.where(g, num / np.maximum(den, 1e-12), s)
    F.f = s; F.mask = np.where(m, 1, np.where(g, 2, 0)).astype(np.uint8)
    return F

def filled_field(F, iters=24):
    """extend field values outward (for mesh vertices slightly outside the raster footprint)"""
    f = np.where(F.mask > 0, F.f, np.nan)
    for _ in range(iters):
        nanm = np.isnan(f)
        if not nanm.any(): break
        acc = np.zeros_like(f); cnt = np.zeros_like(f)
        for di, dk in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.full_like(f, np.nan)
            xs = slice(max(0, di), f.shape[0] + min(0, di)); xd = slice(max(0, -di), f.shape[0] + min(0, -di))
            zs = slice(max(0, dk), f.shape[1] + min(0, dk)); zd = slice(max(0, -dk), f.shape[1] + min(0, -dk))
            sh[xs, zs] = f[xd, zd]
            ok = ~np.isnan(sh)
            acc[ok] += sh[ok]; cnt[ok] += 1
        upd = nanm & (cnt > 0)
        f[upd] = acc[upd] / cnt[upd]
    return f

def bilinear(F, ff, x, z):
    u = (x - F.x0) / F.G - 0.5; v = (z - F.z0) / F.G - 0.5
    i0 = np.clip(np.floor(u).astype(int), 0, F.nx - 2); k0 = np.clip(np.floor(v).astype(int), 0, F.nz - 2)
    fu = np.clip(u - i0, 0, 1); fv = np.clip(v - k0, 0, 1)
    a = ff[i0, k0]; b = ff[i0 + 1, k0]; c = ff[i0, k0 + 1]; d = ff[i0 + 1, k0 + 1]
    vals = np.stack([a, b, c, d]); w = np.stack([(1 - fu) * (1 - fv), fu * (1 - fv), (1 - fu) * fv, fu * fv])
    ok = ~np.isnan(vals)
    ws = np.where(ok, w, 0).sum(0)
    out = np.where(ok, vals * w, 0).sum(0) / np.maximum(ws, 1e-9)
    return np.where(ws > 1e-6, out, np.nan)

# -------------------------------------------------------------------------------------------- footprint polygons
def part_polygon(j):
    nloc, ft = S.top_face(j)
    M = E.R[j]; c = E.C[j]; s = E.S[j]; h = s / 2
    if ft == 'disc':
        r = min(s[1], s[2]) / 2
        pts = [(nloc[0] * h[0], r * math.cos(t), r * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 33)[:-1]]
    elif ft == 'tri':
        pts = [(nloc[0] * h[0], -h[1], -h[2]), (nloc[0] * h[0], -h[1], h[2]), (nloc[0] * h[0], h[1], h[2])]
    elif ft == 'slope':
        pts = [(x, -h[1] + s[1] * (z / s[2] + 0.5), z) for (x, z) in ((-h[0], -h[2]), (h[0], -h[2]), (h[0], h[2]), (-h[0], h[2]))]
    else:
        a = int(np.argmax(np.abs(nloc))); u, v = [i for i in range(3) if i != a]
        pts = []
        for (su, sv) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            p = np.zeros(3); p[a] = nloc[a] * h[a]; p[u] = su * h[u]; p[v] = sv * h[v]; pts.append(p)
    w = np.array([c + M @ np.asarray(p) for p in pts])
    poly = Polygon(w[:, [0, 2]])
    if not poly.is_valid: poly = poly.buffer(0)
    return poly

def part_class(j):
    if names[j] in ('Track', 'Yard'): return 'S'
    return 'K' if E.mat[j] == 880 else 'A'

def looks(js):
    acc = collections.defaultdict(lambda: collections.Counter())
    pr = pickle.load(open('place3.pkl', 'rb'))[1]
    for j in js:
        col = pr[int(E.ids[j])].get('Color3uint8', (128, 128, 128))
        acc[part_class(j)][(MAT.get(int(E.mat[j]), 'SmoothPlastic'), '%02x%02x%02x' % tuple(col))] += E.S[j, 0] * E.S[j, 2]
    return {k: list(v.most_common(1)[0][0]) for k, v in acc.items()}

# -------------------------------------------------------------------------------------------- triangulation
def densify_ring(coords, step):
    out = []
    coords = list(coords)
    for a, b in zip(coords[:-1], coords[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(math.ceil(L / step)))
        for t in range(n):
            out.append((a[0] + (b[0] - a[0]) * t / n, a[1] + (b[1] - a[1]) * t / n))
    return out

def snap(p, q=1e-4): return (round(p[0] / q) * q, round(p[1] / q) * q)

def tri_polygon(poly):
    verts = []; segs = []; holes = []
    def add_ring(ring):
        pts = densify_ring(ring.coords, P['DENS'])
        pts = [snap(p) for p in pts]
        # drop consecutive duplicates
        clean = []
        for p in pts:
            if not clean or p != clean[-1]: clean.append(p)
        if len(clean) > 1 and clean[0] == clean[-1]: clean.pop()
        if len(clean) < 3: return False
        b = len(verts)
        verts.extend(clean)
        n = len(clean)
        segs.extend([(b + i, b + (i + 1) % n) for i in range(n)])
        return True
    if not add_ring(poly.exterior): return None
    for ring in poly.interiors:
        if add_ring(ring):
            rp = Polygon(ring)
            if rp.area > 0.01: holes.append(rp.representative_point().coords[0])
    A = dict(vertices=np.array(verts), segments=np.array(segs))
    if holes: A['holes'] = np.array(holes)
    try:
        T = tr.triangulate(A, 'pa%.3fY' % P['MAXAREA'])
    except Exception:
        return tr.triangulate(A, 'pY')
    # adaptive Verfeinerung: wo die lineare Interpolation von der glatten Flaeche abweicht
    for _ in range(6):
        V = T['vertices']; Tt = T['triangles']
        if FIELD_FN is None: break
        y = FIELD_FN(V[:, 0], V[:, 1])
        a, b, c = V[Tt[:, 0]], V[Tt[:, 1]], V[Tt[:, 2]]
        ya, yb, yc = y[Tt[:, 0]], y[Tt[:, 1]], y[Tt[:, 2]]
        area = 0.5 * np.abs((b[:, 0] - a[:, 0]) * (c[:, 1] - a[:, 1]) - (c[:, 0] - a[:, 0]) * (b[:, 1] - a[:, 1]))
        err = np.zeros(len(Tt))
        for wa, wb, wc in ((1/3, 1/3, 1/3), (0.5, 0.5, 0), (0.5, 0, 0.5), (0, 0.5, 0.5), (2/3, 1/6, 1/6), (1/6, 2/3, 1/6), (1/6, 1/6, 2/3)):
            px = wa * a[:, 0] + wb * b[:, 0] + wc * c[:, 0]; pz = wa * a[:, 1] + wb * b[:, 1] + wc * c[:, 1]
            lin = wa * ya + wb * yb + wc * yc
            f = FIELD_FN(px, pz)
            e = np.abs(np.nan_to_num(f - lin))
            err = np.maximum(err, e)
        bad = (err > P['VTOL']) & (area > P['MINAREA'])
        if not bad.any(): break
        maxa = np.where(bad, np.maximum(P['MINAREA'], area / 4), -1.0)
        T2 = dict(vertices=T['vertices'], triangles=T['triangles'], segments=T.get('segments', A['segments']), triangle_max_area=maxa)
        if 'holes' in A: T2['holes'] = A['holes']
        try:
            T = tr.triangulate(T2, 'rpaY')
        except Exception:
            break
    return T

FIELD_FN = None
ROADSET = None
def neighbor_top(xs, zs, ey):
    """hoechste Oberkante (Teile ohne alte Fahrbahn + Gelaende) knapp ausserhalb der Kante, im Fenster [ey-6, ey+2]"""
    out = np.full(len(xs), -1e9)
    for a in range(0, len(xs), 256):
        b = min(len(xs), a + 256)
        cx = (xs[a:b].min() + xs[a:b].max()) / 2; cz = (zs[a:b].min() + zs[a:b].max()) / 2
        pad = max(np.ptp(xs[a:b]), np.ptp(zs[a:b])) / 2 + 2
        J = E.cands(cx, cz, pad=pad)
        if ROADSET is not None and len(J): J = np.array([j for j in J if j not in ROADSET])
        if len(J):
            lo, hi = E.intervals(xs[a:b], zs[a:b], J)
            e = ey[a:b, None]
            win = (hi <= e + 2) & (hi >= e - 6)
            out[a:b] = np.max(np.where(win, hi, -1e9), axis=1)
        t = E.terrain_top(xs[a:b], zs[a:b])
        out[a:b] = np.maximum(out[a:b], np.where((t <= ey[a:b] + 2) & (t >= ey[a:b] - 6), t, -1e9))
    return out

def mesh_city(city):
    t0 = time.time()
    js = collect(city)
    print(city, 'drivable parts', len(js), flush=True)
    F = build_field(js)
    ff = filled_field(F)
    global FIELD_FN, ROADSET
    FIELD_FN = lambda x, z: bilinear(F, ff, x, z)
    ROADSET = set(js.tolist())
    look = looks(js)
    # owner class raster
    cls_of = {j: part_class(j) for j in js}
    # polygons per class, priority resolution by owner raster majority
    polys = collections.defaultdict(list)
    for j in js:
        pg = part_polygon(j)
        if pg.is_empty or pg.area < 0.01: continue
        polys[cls_of[j]].append(pg)
    U = {c: unary_union(v).buffer(0) for c, v in polys.items()}
    classes = sorted(U, key=lambda c: -U[c].area)
    print('  classes', {c: round(U[c].area) for c in classes}, round(time.time() - t0, 1), flush=True)
    # owner class grid
    own = F.own
    clsgrid = np.full(own.shape, '', dtype='<U1')
    valid = own >= 0
    clsgrid[valid] = np.vectorize(lambda j: cls_of.get(int(j), 'A'))(own[valid])
    def majority(pg):
        minx, minz, maxx, maxz = pg.bounds
        xs = np.arange(math.floor(minx) + 0.5, maxx, 1.0); zs = np.arange(math.floor(minz) + 0.5, maxz, 1.0)
        if len(xs) == 0 or len(zs) == 0: return None
        X, Z = np.meshgrid(xs, zs, indexing='ij')
        inside = shapely.contains_xy(pg, X.ravel(), Z.ravel())
        I = ((X.ravel()[inside] - F.x0) / F.G).astype(int); K = ((Z.ravel()[inside] - F.z0) / F.G).astype(int)
        ok = (I >= 0) & (K >= 0) & (I < F.nx) & (K < F.nz)
        c = collections.Counter(clsgrid[I[ok], K[ok]]); c.pop('', None)
        return c.most_common(1)[0][0] if c else None
    # resolve overlaps pairwise
    final = dict(U)
    for a_i in range(len(classes)):
        for b_i in range(a_i + 1, len(classes)):
            a, b = classes[a_i], classes[b_i]
            ov = final[a].intersection(final[b])
            if ov.is_empty: continue
            geoms = getattr(ov, 'geoms', [ov])
            for g in geoms:
                if g.geom_type != 'Polygon' or g.area < 1e-3: continue
                win = majority(g) or a
                if win == a: final[b] = final[b].difference(g)
                else: final[a] = final[a].difference(g)
    # closing on the total footprint, assign added area to nearest class, round corners slightly
    total = unary_union(list(final.values()))
    closed = total.buffer(P['CLOSE'], join_style=1).buffer(-P['CLOSE'], join_style=1)
    extra = closed.difference(total)
    assigned = set()
    for c in classes:
        add = extra.intersection(final[c].buffer(P['CLOSE'] * 1.6))
        for c2 in assigned: add = add.difference(final[c2])
        final[c] = unary_union([final[c], add])
        assigned.add(c)
    for c in classes:
        g = final[c].buffer(-P['ROUND'], join_style=1).buffer(P['ROUND'], join_style=1)
        # drop tiny bits and holes
        parts = []
        for pg in getattr(g, 'geoms', [g]):
            if pg.geom_type != 'Polygon' or pg.area < 2: continue
            ints = [r for r in pg.interiors if Polygon(r).area >= 6]
            parts.append(Polygon(pg.exterior, ints))
        final[c] = MultiPolygon(parts) if parts else Polygon()
    # gemeinsame Vereinfachung (Kanten zwischen den Belaegen bleiben deckungsgleich)
    keys = [c for c in classes if not final[c].is_empty]
    simp = shapely.coverage_simplify([final[c] for c in keys], P['SIMPLIFY'])
    for c, g in zip(keys, simp):
        g = g.buffer(0)
        parts = [pg for pg in getattr(g, 'geoms', [g]) if pg.geom_type == 'Polygon' and pg.area >= 2]
        final[c] = MultiPolygon(parts) if parts else Polygon()
    print('  footprint resolved', {c: round(final[c].area) for c in classes}, round(time.time() - t0, 1), flush=True)
    # tiles
    objs = []
    T = P['TILE']
    outer = closed.boundary
    def emit(c, geom, tag):
        tris_all = []; verts_all = []; skirts = []
        for pg in getattr(geom, 'geoms', [geom]):
            if pg.geom_type != 'Polygon' or pg.area < 0.5: continue
            R = tri_polygon(pg)
            if R is None or 'triangles' not in R: continue
            V = R['vertices']; Tt = R['triangles']
            base = len(verts_all)
            verts_all.extend([tuple(v) for v in V]); tris_all.extend([(a + base, b + base, cc + base) for a, b, cc in Tt])
            # skirt along ring edges that are not tile cuts
            for ring in [pg.exterior] + list(pg.interiors):
                pts = [snap(p) for p in densify_ring(ring.coords, P['DENS'])]
                n = len(pts)
                for i in range(n):
                    a, b = pts[i], pts[(i + 1) % n]
                    if a == b: continue
                    skirts.append((a, b))
        if skirts:
            mids = np.array([((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in skirts])
            d = shapely.distance(shapely.points(mids), outer)
            skirts = [sk for sk, dd in zip(skirts, d) if dd < 0.05]
        if skirts:
            # nur wo die Umgebung tiefer liegt als die Kante (sonst verdeckt Bordstein/Gehweg/Bankett die Kante)
            keep = []
            mids = np.array([((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in skirts])
            dirs = np.array([(b[0] - a[0], b[1] - a[1]) for a, b in skirts]); ln = np.linalg.norm(dirs, axis=1, keepdims=True); dirs = dirs / np.maximum(ln, 1e-9)
            nout = np.stack([dirs[:, 1], -dirs[:, 0]], 1)
            probe = mids + nout * 0.8
            inside = shapely.contains_xy(geom, probe[:, 0], probe[:, 1])
            nout[inside] *= -1
            probe = mids + nout * 0.8
            ey = FIELD_FN(mids[:, 0], mids[:, 1])
            nb = neighbor_top(probe[:, 0], probe[:, 1], ey)
            skirts = [sk for sk, e, n in zip(skirts, ey, nb) if not np.isnan(e) and (n < e - 0.15)]
        return verts_all, tris_all, skirts
    for c in classes:
        g = final[c]
        if g.is_empty: continue
        minx, minz, maxx, maxz = g.bounds
        for tx in range(int(math.floor(minx / T)), int(math.floor(maxx / T)) + 1):
            for tz in range(int(math.floor(minz / T)), int(math.floor(maxz / T)) + 1):
                cell = box(tx * T, tz * T, (tx + 1) * T, (tz + 1) * T)
                sub = g.intersection(cell)
                if sub.is_empty or sub.area < 1: continue
                pieces = [(sub, (tx, tz, T))]
                done = []
                while pieces:
                    geom, (ax, az, size) = pieces.pop()
                    V, Tr_, Sk = emit(c, geom, None)
                    if len(Tr_) + 2 * len(Sk) > P['MAXTRI'] and size > 32:
                        h = size / 2
                        for qx in (0, 1):
                            for qz in (0, 1):
                                cb = box(ax * size + qx * h, az * size + qz * h, ax * size + (qx + 1) * h, az * size + (qz + 1) * h)
                                sg = geom.intersection(cb)
                                if not sg.is_empty and sg.area >= 1:
                                    pieces.append((sg, ((ax * size + qx * h) / h, (az * size + qz * h) / h, h)))
                        continue
                    if Tr_: done.append((V, Tr_, Sk))
                for V, Tr_, Sk in done:
                    objs.append(dict(cls=c, V=V, T=Tr_, S=Sk))
    print('  objects', len(objs), 'tris', sum(len(o['T']) for o in objs), round(time.time() - t0, 1), flush=True)
    # heights, normals, OBJ
    lines = ['# RoadSmooth road meshes ' + city, 'mtllib none']
    vbase = 1; nbase = 1; tbase = 1
    meta = []
    gx, gz = np.gradient(np.where(np.isnan(ff), 0, ff))
    for oi, o in enumerate(objs):
        name = 'RS_%s_%s_%02d' % (city, o['cls'], oi + 1)
        V = np.array(o['V'])
        y = bilinear(F, ff, V[:, 0], V[:, 1])
        bad = np.isnan(y)
        if bad.any():
            y[bad] = np.nanmean(y) if (~bad).any() else 0
        # normals from field gradient (bilinear-ish via nearest cell)
        I = np.clip(((V[:, 0] - F.x0) / F.G).astype(int), 0, F.nx - 1); K = np.clip(((V[:, 1] - F.z0) / F.G).astype(int), 0, F.nz - 1)
        nx_ = -gx[I, K] / F.G; nz_ = -gz[I, K] / F.G
        nrm = np.stack([nx_, np.ones_like(nx_), nz_], 1); nrm /= np.linalg.norm(nrm, axis=1, keepdims=True)
        verts = [(V[i, 0], y[i], V[i, 1]) for i in range(len(V))]
        norms = [tuple(nrm[i]) for i in range(len(V))]
        faces = []
        for a, b, c in o['T']:
            pa, pb, pc = np.array(verts[a]), np.array(verts[b]), np.array(verts[c])
            if np.cross(pb - pa, pc - pa)[1] < 0: b, c = c, b
            faces.append((a, b, c, a, b, c))
        # skirts
        idx = {(round(v[0], 4), round(v[2], 4)): i for i, v in enumerate(verts)}
        for (a, b) in o['S']:
            ia = idx.get((round(a[0], 4), round(a[1], 4))); ib = idx.get((round(b[0], 4), round(b[1], 4)))
            if ia is None or ib is None: continue
            A_ = verts[ia]; B_ = verts[ib]
            A2 = (A_[0], A_[1] - P['SKIRT'], A_[2]); B2 = (B_[0], B_[1] - P['SKIRT'], B_[2])
            d = np.array([B_[0] - A_[0], 0, B_[2] - A_[2]]); n_out = np.array([d[2], 0, -d[0]]); ln = np.linalg.norm(n_out)
            if ln < 1e-9: continue
            n_out = n_out / ln
            ia2 = len(verts); verts.append(A2); norms.append(tuple(n_out))
            ib2 = len(verts); verts.append(B2); norms.append(tuple(n_out))
            na = len(norms); norms.append(tuple(n_out))
            # two triangles, facing outward (orientation fixed by cross product test)
            for tri in ((ia, ib, ib2), (ia, ib2, ia2)):
                p0, p1, p2 = (np.array(verts[t]) for t in tri)
                nn = np.cross(p1 - p0, p2 - p0)
                if nn @ n_out < 0: tri = (tri[0], tri[2], tri[1])
                faces.append((tri[0], tri[1], tri[2], na - 1, na - 1, na - 1))
        Va = np.array(verts)
        mn = Va.min(0); mx = Va.max(0)
        lines.append('o ' + name)
        lines.extend('v %.4f %.4f %.4f' % v for v in verts)
        lines.extend('vt %.4f %.4f' % (v[0] / 8.0, v[2] / 8.0) for v in verts)
        lines.extend('vn %.5f %.5f %.5f' % n for n in norms)
        for f in faces:
            a, b, c, na_, nb_, nc_ = f
            lines.append('f %d/%d/%d %d/%d/%d %d/%d/%d' % (a + vbase, a + tbase, na_ + nbase, b + vbase, b + tbase, nb_ + nbase, c + vbase, c + tbase, nc_ + nbase))
        meta.append(dict(name=name, cls=o['cls'], tris=len(faces), verts=len(verts), min=mn.round(4).tolist(), max=mx.round(4).tolist()))
        vbase += len(verts); tbase += len(verts); nbase += len(norms)
    open(os.path.join(OUT, f'Strassen_{city}.obj'), 'w').write('\n'.join(lines) + '\n')
    print('  wrote', city, len(meta), 'meshes', sum(m['tris'] for m in meta), 'tris', round(time.time() - t0, 1), flush=True)
    return dict(look=look, objs=meta), F, final

if __name__ == '__main__':
    cities = sys.argv[2:] or ['Neustadt', 'Portavia', 'Metropolis']
    res = {}
    for city in cities:
        d, F, final = mesh_city(city)
        res[city] = d
        pickle.dump((F, final), open(os.path.join(OUT, f'field_{city}.pkl'), 'wb'), protocol=4)
    pickle.dump(res, open(os.path.join(OUT, 'meshdata.pkl'), 'wb'))
