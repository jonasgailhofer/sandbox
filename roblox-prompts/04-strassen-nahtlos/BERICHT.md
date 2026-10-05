# Bericht: Straßen nahtlos machen (Analyse von `test123.rbxl`)

## Kurzfassung
- **Warum die Straßen ruckeln:**
  - Der LKW „schwebt“ auf vier Bodenstrahlen. Jede kleine Kante zwischen den vielen Straßenplatten ist darum ein Stoß.
  - Seine einzige Kollision ist ein unsichtbarer Kasten mit nur 1,36–1,96 Studs Bodenfreiheit. Größere Stufen halten ihn auf.
  - Die schönen Straßen-Meshes, die man sieht, sind nur Optik. Gefahren wird auf den alten, unsichtbaren Platten darunter.
- **Die Lösung besteht aus drei Teilen**, die zusammenpassen:
  1. **Neues Fahrwerk:** glättet Kanten und hebt vor flachen Stufen rechtzeitig an. Simuliert **74 % weniger harte Stöße**.
     Auf Mauern, Fahrzeuge oder Gegenstände klettert es dabei nicht.
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
| Höhensprünge > 0,05 | 2.606 | 1.840 (−29 %) |
| Höhensprünge > 0,15 | 839 | 694 |
| Höhensprünge > 0,4 | 243 | 216 |
| Neigungsrucke > 1° | 849 | 641 (−25 %) |
| Rollrucke > 1° | 1.075 | 770 (−28 %) |
| Höhensprünge > 1 | 27 | 31 |

Die Sprünge über 1 Stud sind große Stufen in Vorstadt-Kreuzungen, die schon vorher da waren. Die Haut darf höchstens
0,4 Studs unter der alten Fahrbahn liegen. Deshalb fasst sie dort manchmal zwei halbe Stufen zu einer ganzen zusammen;
die Gesamthöhe bleibt gleich. Beseitigen lassen sie sich nur durch Umbauen (Phase 4 im Prompt).

Die Fahrhaut entfernt fast alle Fugen zwischen den Platten. Der Rest liegt an Übergängen zum Gelände, an echten großen Stufen und an Lücken.

Das neue Fahrwerk wurde mit einem Modell der Roblox-Federung (AlignPosition) auf 1.500 echten Fahrlinien simuliert,
bei 50 Studs/s:

| | altes Fahrwerk | neues Fahrwerk |
|---|---|---|
| harte Stöße > 100 Studs/s² | 1.854 | **488** |
| sehr harte Stöße > 300 Studs/s² | 210 | **87** |
| Kasten berührt fast den Boden (< 0,05) | 153 | **136** |

Dazu kam ein Längsschnitt-Test mit geneigtem Kasten, getrennt für Van und Titan, auf typischen Profilen. Angegeben ist die
größte senkrechte Beschleunigung in Studs/s², in Klammern das Nachschweben über dem Boden in Studs.

| Profil | Van alt | Van neu | Titan alt | Titan neu |
|---|---|---|---|---|
| 12°-Rampe | 266 (1,22) | **46 (0,23)** | 221 (1,11) | 247 (**0,21**) |
| 6°-Kuppe | 262 | **45** | 219 | **152** |
| 6°-Senke | 172 | **45** | 112 | **46** |
| 12°-Kuppe | 531 | **91** | 596 | **241** |
| Fugen 0,12 | 32 | 32 | 32 | 32 |
| Mauer 5 Studs | klettert 0,9 hoch | bleibt Hindernis | klettert 1,4 hoch | bleibt Hindernis |

Bei der 12°-Kuppe setzt der lange Titan zwischen den Achsen mit dem alten Fahrwerk 2,2 Studs tief auf, mit dem neuen
nur noch 1,0. Ganz verschwinden kann das nur, wenn die Kuppe in der Welt flacher wird.

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
- **Fahrwerk v2 im Detail:**
  - Die Bodenstrahlen ignorieren Teile ohne Kollision und andere Fahrzeuge.
  - Fehlt an einer Stelle die Fahrhaut, nehmen sie die alte Fahrbahn.
  - Die Höhe läuft durch einen Alpha-Beta-Filter mit zwei Grenzen:
    - höchstens 0,6 Studs über dem Boden, also kein Nachschweben nach Kuppen;
    - mindestens so hoch, dass die Unterkante des **geneigten** Kastens alle Bodenpunkte um 0,25 Studs überragt.
      Das gilt für die Ecken, die Mitte und die Stoßstange.
  - Die Vorausschau sieht nur Fahrhaut und Gelände. Sie zieht Rampen ab, die der Kasten durch Kippen selbst schafft,
    und hebt stetig an, um höchstens 1 Stud.
- **Fahrhaut:** ca. 11.400 unsichtbare Platten für alle drei Städte, Gruppe `RoadSkin`.
  - Jede Platte ist eine Kopie eines Fahrbahnteils, auf die geglättete Fläche gekippt und leicht überlappend.
  - Wo nötig, wird sie rekursiv halbiert, bis sie auf 0,12 Studs genau passt.
  - Ergebnis: 99 % der Fläche liegen innerhalb von 0,05 Studs an der glatten Fläche, die Abdeckung beträgt ≈ 100 %
    (fehlend: 0,01–0,04 % der Fahrbahnzellen).
  - Die Haut existiert nur für das Fahrwerk (Gruppe `TruckRay`). Für Figuren, den Kasten und alle anderen Raycasts gibt es sie nicht.
  - Sie wird nie weggestreamt (`Persistent`).
  - Ein altes Fahrbahnteil kommt nur dann in `RoadBase`, wenn eine Raycast-Prüfung zeigt, dass die Haut es zu ≥ 90 % abdeckt.
  - Unterführungen und Schiffsdecks bleiben unverändert.
- **Glatte Fläche:**
  - Rasterweite 1 Stud, zweimal geglättet (2 und 1 Stud).
  - Sie liegt höchstens 0,4 Studs unter der alten Fahrbahn. Große Stufen werden nur zu kurzen Rampen gemildert und bleiben im Audit sichtbar.
  - Lücken bis 4 Studs werden geschlossen, aber nur zwischen Fahrbahnen auf gleicher Höhe (Höhenunterschied höchstens 0,4 × Abstand + 0,3).
- **Prüfung des Rechenkerns:**
  - Der Luau-Kern wurde mit dem Luau-Interpreter auf den echten Daten aller drei Städte ausgeführt und gegen eine unabhängige
    Python-Version verglichen.
  - Die maximale Abweichung der glatten Fläche beträgt 0,008 Studs.
  - Die geschlossenen Lückenzellen stimmen in den Stichproben überein (insgesamt 1.230 zu 1.236 in Neustadt, identisch in den anderen Städten).
- **Meshes:**
  - 96 Meshes, ca. 171.000 Dreiecke. Zum Vergleich: die alten Meshes hatten ca. 245.000.
  - Genauigkeit: 99 % der Fläche weichen höchstens 0,05 Studs von der Fahrfläche ab. Die Meshes decken 99,8–99,9 % der Fahrbahn ab.
  - Je 512-Stud-Kachel und Belag (Asphalt, Kopfstein, Schotter) eins.
  - Dreiecke werden nur dort verfeinert, wo sich die Höhe ändert (Toleranz 0,05).
  - Kanten werden gemeinsam vereinfacht, damit die Beläge lückenlos aneinanderpassen.
  - Randschürzen gibt es nur dort, wo das Gelände tiefer liegt als die Straßenkante.
- **Rückgängig machen:** `RS.Restore`, `RS.RestoreTerrain`, `RS.UninstallTruck`, `RS.RestoreMeshes`.

## Unabhängiges Code-Review
- **Erste Prüfrunde:** 45 Befunde, darunter 13 schwere. Alle schweren und mittleren sind behoben.
- **Behoben wurden unter anderem:**
  - Die Vorausschau hob den LKW auf andere LKWs und Mauern.
  - Die Mindesthöhe rechnete mit einem waagrechten Kasten.
  - Nach Kuppen fehlte eine Obergrenze.
  - Die Haut kollidierte mit Figuren.
  - Schiffsdecks wurden als Straße behandelt.
  - Die Gelände-Sicherung war zu klein, und es wurde auch ohne Sicherung abgesenkt.
  - Bei der Testfahrt fehlten Streaming und Netzwerk-Besitz, die Kurvenbremse fehlte, und der Start zählte als falscher Stoß.
  - Das Audit zählte Sprünge dreifach und wertete Rampen als Aufsetzen.
  - Lücken wurden zwischen verschiedenen Ebenen geschlossen.
  - Hintergrund-Jobs verloren den Traceback.
- **Zweite Prüfrunde:** Sie lief über alle Änderungen und fand keinen schweren Fehler.
  - Sie bestätigt die Geometrie der Mindesthöhe, die Vorzeichen der Vorausschau, die Roblox-API-Aufrufe und die Rechenkern-Tests.
  - Drei kleinere Fehler hat sie gefunden, alle sind behoben:
    - Ein Fahrwerk-Update hätte das Original-Backup ersetzt.
    - Die Vorausschau sah Fahrbahnteile ohne Haut nicht.
    - `RS.Reset` hat den alten Job nicht beendet.
  - **Bekannt und bewusst offen (gering):**
    - Am Fahrbahnrand glättet die Fläche das Quergefälle etwas.
    - Das Audit bildet die neue Filterlogik nicht nach; dafür gibt es die echte Testfahrt.
    - `CornerWedge`-Teile werden wie Blöcke behandelt.
    - Einige Durchläufe über das Raster geben Studio keine Pause.

## Grenzen (ehrlich)
- **Testlauf:** Die Werkzeuge konnten nicht in Roblox selbst laufen. Der Rechenkern ist getestet und der Code gegen die
  Roblox-Typdefinitionen geprüft und unabhängig reviewt. Fable prüft jeden Schritt in Studio mit Audit und Testfahrt.
- **Optik:** Ob die neuen Meshes besser aussehen als die alten, kann man nur im Spiel beurteilen. Deshalb gibt es `RS.RestoreMeshes`.
- **Spätere Änderungen:** Wenn Straßen in Phase 4 verschoben werden, müssen die Meshes neu berechnet werden.
  Dafür die neue `.rbxl` hochladen; der Generator liegt in `quellcode/`.
