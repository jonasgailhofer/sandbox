# Bericht: Straßen nahtlos machen (Analyse von `test123.rbxl`)

## Kurzfassung
- **Warum die Straßen ruckeln:**
  - Der LKW „schwebt“ auf vier Bodenstrahlen. Jede kleine Kante zwischen den vielen Straßenplatten ist darum ein Stoß.
  - Seine einzige Kollision ist ein unsichtbarer Kasten mit nur 1,36–1,96 Studs Bodenfreiheit. Größere Stufen halten ihn auf.
  - Die schönen Straßen-Meshes, die man sieht, sind nur Optik. Gefahren wird auf den alten, unsichtbaren Platten darunter.
- **Die Lösung besteht aus drei Teilen**, die zusammenpassen:
  1. **Neues Fahrwerk:** glättet Kanten und hebt rechtzeitig an. Simuliert **75 % weniger harte Stöße**.
  2. **Unsichtbare Fahrhaut:** eine glatte Fläche über allen Straßen, die nur das Fahrwerk sieht. Sie schließt Fugen und kleine Lücken.
  3. **Neue Straßen-Meshes:** aus derselben glatten Fläche, also deckungsgleich mit dem, worauf gefahren wird.
     Glatte Kurven, gerundete Kanten, keine Nähte.
- **Was übrig bleibt:** Echte Baufehler wie große Stufen in Vorstadt-Kreuzungen, Lücken über 4 Studs und Gegenstände in der Fahrbahn.
  Die findet das Audit-Werkzeug in Studio mit echten Raycasts. Fable arbeitet sie laut Prompt einzeln ab.

## Was analysiert wurde
- **Teile:** Alle 361.848 Instanzen aus `test123.rbxl` wurden ausgelesen, mit vollständigen Drehungen.
  67.006 Teile haben Kollision, davon 8.056 Fahrbahnteile.
- **Gelände:** Das Voxel-Gelände (`SmoothGrid`, 30.850 Chunks) wurde dekodiert und zu Höhenkarten umgerechnet.
  Die Höhe ist auf ±1 Stud genau, darum misst das Studio-Werkzeug das Gelände selbst nach.
- **Code:** Fahrzeug-Steuerung, Straßenbau-Skripte, Navi/Verkehr/Fußgänger-Daten und Fables Fortschritts-Log wurden gelesen.
- **Simulation:** Ein LKW-genauer Nachbau der Bodenstrahlen fuhr 2.000 zufällige Straßenstücke ab,
  zusätzlich eine Rasterprüfung von 1,33 Mio. Fahrbahnzellen.

## So fährt der LKW (wichtig für alles andere)
- **Federung:** 4 Strahlen an den Radecken (Start 6 Studs über der Ecke, 40 Studs nach unten).
  Das Fahrzeug wird auf Mittelwert + Fahrhöhe gehalten (AlignPosition), die Neigung kommt aus der Ebene der 4 Treffer.
- **Kollision:** Nur der Kasten `Chassis` kollidiert. Die Räder sind Deko.

  | Fahrzeug | Größe | Bodenfreiheit |
  |---|---|---|
  | Van | 6,6 × 7,4 × 17 | 1,36 |
  | Titan40 | 8,6 × 11,8 × 46 | 1,96 |

- **Bisherige Schwächen:**
  - Die Strahlen trafen auch Teile ohne Kollision (Fahrbahnlinien, Trigger, Marker).
  - Jede Höhenänderung wurde sofort als Sprung weitergegeben.
  - Hindernisse sahen die Strahlen erst 3–5 Studs zu spät, weil der Kasten über die Radecken hinausragt.

## Messwerte (Van, 2.000 Fahrbahn-Mittellinien)

| | vorher | mit Fahrhaut |
|---|---|---|
| Höhensprünge > 0,05 | 2.685 | 1.927 |
| Höhensprünge > 0,15 | 954 | 769 |
| Neigungsrucke > 1° | 891 | 681 |
| Rollrucke > 1° | 1.062 | 786 |

Die Fahrhaut entfernt fast alle Fugen zwischen den Platten. Der Rest liegt an Übergängen zum Gelände, an echten großen Stufen und an Lücken.

Das neue Fahrwerk wurde mit einem Modell der Roblox-Federung (AlignPosition) simuliert, bei 50 Studs/s:

| | altes Fahrwerk | neues Fahrwerk |
|---|---|---|
| harte Stöße > 100 Studs/s² | 1.854 | **461** |
| sehr harte Stöße > 300 Studs/s² | 210 | **75** |

## Konkrete Funde
- **Navi-Linie durch das Rathaus** Neustadt (x 482–514, z 655–666): Die Route führt durch das Gebäude.
- **Kongress-Vorplatz** (`Venues.Kongress.KongressBuilding.Forecourt`, 196 × 0,6 × 24): Er ragt 3,3 Studs über der Fahrbahn seitlich
  in die Straße (x 811–884, z ≈ 1484). Daran stößt der Kasten an.
- **Vorstadt-Kreuzungen:**
  - Teilweise Lücken über 4 Studs und große Höhenunterschiede zwischen den Spuren.
  - Beispiel Portavia (7945, −214): Spuren zwischen 12 und 21 Studs Höhe auf 48 Studs Abstand.
- **Gelände:** Es ragt an vielen Stellen in oder knapp unter die Fahrbahn. Das Werkzeug misst das in Studio genau und senkt es auf Wunsch ab.
- **Lücken:** Etwa 3.000 kleine Schlitze und Ecken bis 4 Studs in der Fahrbahnfläche, ca. 1.300 Stellen. Die Fahrhaut schließt sie.

## Die Werkzeuge
- **Fahrhaut:** ca. 12.000 unsichtbare Platten für alle drei Städte, Gruppe `RoadSkin`.
  - Jede Platte ist eine Kopie eines Fahrbahnteils, auf die geglättete Fläche gekippt und leicht überlappend.
  - Wo nötig, wird sie rekursiv halbiert, bis sie auf 0,12 Studs genau passt.
  - Ergebnis: 99 % der Fläche liegen innerhalb von 0,05 Studs an der glatten Fläche, die Abdeckung beträgt ≈ 100 %.
- **Glatte Fläche:**
  - Rasterweite 1 Stud, zweimal geglättet (2 und 1 Stud).
  - Sie liegt höchstens 0,4 Studs unter der alten Fahrbahn. Große Stufen werden nur zu kurzen Rampen gemildert und bleiben im Audit sichtbar.
  - Lücken bis 4 Studs werden geschlossen.
- **Prüfung des Rechenkerns:** Der Luau-Kern wurde mit dem Luau-Interpreter auf den echten Daten aller drei Städte ausgeführt
  und gegen eine unabhängige Python-Version verglichen. Die maximale Abweichung beträgt 0,008 Studs.
- **Meshes:**
  - 97 Meshes, ca. 172.000 Dreiecke. Zum Vergleich: die alten Meshes hatten ca. 245.000.
  - Je 512-Stud-Kachel und Belag (Asphalt, Kopfstein, Schotter) eins.
  - Dreiecke werden nur dort verfeinert, wo sich die Höhe ändert (Toleranz 0,05).
  - Kanten werden gemeinsam vereinfacht, damit die Beläge lückenlos aneinanderpassen.
  - Randschürzen gibt es nur dort, wo das Gelände tiefer liegt als die Straßenkante.
- **Rückgängig machen:** `RS.Restore`, `RS.RestoreTerrain`, `RS.UninstallTruck`, `RS.RestoreMeshes`.

## Grenzen (ehrlich)
- **Testlauf:** Die Werkzeuge konnten nicht in Roblox selbst laufen. Der Rechenkern ist getestet und der Code gegen die
  Roblox-Typdefinitionen geprüft und unabhängig reviewt. Fable prüft jeden Schritt in Studio mit Audit und Testfahrt.
- **Optik:** Ob die neuen Meshes besser aussehen als die alten, kann man nur im Spiel beurteilen. Deshalb gibt es `RS.RestoreMeshes`.
- **Spätere Änderungen:** Wenn Straßen in Phase 4 verschoben werden, müssen die Meshes neu berechnet werden.
  Dafür die neue `.rbxl` hochladen; der Generator liegt in `quellcode/`.
