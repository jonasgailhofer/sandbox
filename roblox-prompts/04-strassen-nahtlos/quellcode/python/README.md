# Python-Werkzeugkette (Analyse + Mesh-Generator)

Nur nötig, um die Straßen-Meshes nach Änderungen am Place neu zu berechnen. Ablauf (Python 3, `pip install numpy lz4 zstandard shapely triangle pillow scipy`):

```bash
python3 parse3.py Place.rbxl place3.pkl      # .rbxl lesen (alle Teile mit Drehung, Skripte, Gelaende-Blob)
python3 terrain2.py                          # Voxel-Gelaende (smoothgrid.bin) dekodieren -> terrain.npz
python3 hmap.py                              # Hoehenkarte H_zx.npy / origin_zx.txt
python3 colliders.py                         # Kollisions-Arrays -> colliders.npz
python3 meshgen.py meshes                    # Meshes -> meshes/Strassen_<Stadt>.obj + meshdata.pkl
python3 meshcheck.py Neustadt                # Genauigkeit/Abdeckung + Vorschaubild
```

`skin_ref.py` ist die Python-Referenz des Luau-Rechenkerns (`Core.luau`); `test_core.luau` führt den Luau-Kern mit dem
`luau`-Interpreter auf exportierten Daten aus (Vergleich Feld/Platten). `make_rbxmx.py` packt die Luau-Module in `RoadSmooth.rbxmx`.
