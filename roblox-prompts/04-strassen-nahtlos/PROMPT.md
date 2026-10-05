# Prompt 4: Straßen nahtlos machen (Fable 5.1 + Roblox Studio MCP)

Grundlage ist eine Analyse von `test123.rbxl` vom 04.10.2026. Dabei wurden alle Teile, das Gelände (Voxel) und alle Straßenskripte ausgelesen. Danach wurde das Fahrverhalten des LKW auf allen drei Städten simuliert.

## Was in diesem Ordner liegt

| Datei | Wofür |
|---|---|
| `RoadSmooth.rbxmx` | Das Werkzeug für Studio (ModuleScript mit `Core`, `TruckNeu`, `MeshData`) |
| `Strassen_Neustadt.obj`, `Strassen_Portavia.obj`, `Strassen_Metropolis.obj` | Neue, nahtlose Straßen-Optik (glatte Kurven, keine Kanten) |
| `BERICHT.md` | Was die Analyse gefunden hat und wie die Lösung funktioniert |
| `quellcode/` | Der Luau-Code als Text (gleich wie in der `.rbxmx`) |

## Was du vorher selbst machen musst (5 Minuten)

1. **Backup:** In Studio *Datei → Speichern unter →* `Place_vorStrassen.rbxl`.
2. **Werkzeug einfügen:** Im Explorer Rechtsklick auf `ServerStorage → DevTools` → **„Aus Datei einfügen…“** (*Insert from File*) und `RoadSmooth.rbxmx` wählen.
   Danach gibt es `ServerStorage.DevTools.RoadSmooth`.
3. **Neue Optik importieren** (kannst du auch später machen, wenn Fable danach fragt): Je Stadt *Datei → 3D importieren*
   (*Import 3D*) → `Strassen_<Stadt>.obj` wählen und mit den Standard-Einstellungen importieren.
   Die importierten Teile bleiben einfach im Workspace liegen, Fable räumt sie auf.
4. **Bildschirm wach lassen** (Fable macht Screenshots), Studio offen, MCP mit der Claude-App verbunden.
5. Text zwischen den `=====`-Linien in einen **neuen Chat mit Fable 5.1** kopieren.

Wenn der Chat zu lang wird oder abbricht: neuer Chat, gleicher Prompt. Fable liest den Stand aus `PolishLog` (Block V) und macht weiter.

=====

Du bist Senior-Roblox-Engineer und arbeitest per MCP direkt in meinem offenen Roblox Studio. Du kannst Luau im Edit-Modus ausführen,
Skripte lesen und ändern, Playtests starten, Code im Play-Modus ausführen, die Konsole lesen und Screenshots machen.
Antworte mir auf Deutsch. Arbeite selbstständig durch und berichte am Ende jeder Phase kurz mit Zahlen.

## Ziel
Alle Straßen, Kurven und Übergänge sollen **nahtlos** sein: keine sichtbaren Kanten, keine hässlichen Übergänge und keine Stöße,
Hänger oder Hindernisse, wenn man mit dem LKW darüberfährt.

## Was du wissen musst (Analyse von test123.rbxl, unbedingt lesen)

- **So fährt der LKW** (`StarterPlayerScripts.Client.Truck`):
  - Er hat keine Räder-Physik. Er schwebt: 4 Strahlen an den Radecken messen den Boden, AlignPosition hält den LKW auf
    Mittelwert + Fahrhöhe.
  - Die einzige Kollision ist ein unsichtbarer Kasten (`Chassis`). Seine Bodenfreiheit ist nur 1,36 (Van) bis 1,96 Studs (Titan).
  - Folgen:
    - Jede Stufe im Untergrund ist ein Ruck.
    - Stufen über ca. 1,3 Studs stoppen den Kasten, weil die Strahlen sie 3–5 Studs zu spät sehen.
    - Die Strahlen treffen bisher auch Teile ohne Kollision: Fahrbahnlinien, Trigger, Marker.
- **So sind die Straßen gebaut:**
  - Viele einzelne Platten: Stadt `Road` + `RoadFill`-Keile, Vorstadt `Lane` + `LaneJoint`-Scheiben + `Verge`, Rampen, Schlitz-Füller.
  - Die sichtbare Optik sind deine `StrassenMesh`-Meshes. Die alten Platten sind unsichtbar, aber **sie** sind das, worauf der LKW fährt.
  - Die Analyse zählt auf den Fahrlinien (Van):
    - rund 2.700 Höhensprünge > 0,05 Studs auf 2.000 Teilstrecken,
    - ca. 340 > 0,4 und 120 > 1 Stud,
    - dazu Lücken bis mehrere Studs (z. B. verwinkelte Vorstadt-Kreuzungen in Portavia um (7945, −214)),
    - Gelände, das durch die Fahrbahn ragt,
    - und echte Hindernisse:
      - **Navi-Linie führt durch das Rathaus** Neustadt (x 482–514, z 655–666).
      - Die Platte `Venues.Kongress.KongressBuilding.Forecourt` ragt **3,3 Studs über der Fahrbahn** seitlich in die Straße
        (x 811–884, z ≈ 1484).
- **Navi, KI-Verkehr und Fußgänger** haben ihre Höhen fest eingebacken (`NavData`, `TrafficData`, `PedData`).
  Wenn du Straßen-Höhen um mehr als ein paar Zehntel änderst, müssen die Exporter neu laufen
  (`NavExport` → `VenuesLand.ExportNav` → `TrafficExport` → `PedExport` → `GrasU`).

## Die Lösung (fertig im Werkzeug `ServerStorage.DevTools.RoadSmooth`)

`local RS = require(game.ServerStorage.DevTools.RoadSmooth)` und dann `print(RS.Help())`.

1. **Fahrwerk v2** (`RS.InstallTruck()`):
   - Die Strahlen ignorieren Teile ohne Kollision, andere Fahrzeuge (`World.Vehicles`) und nutzen die Kollisionsgruppe `TruckRay`.
   - Wo an einer Stelle (noch) keine Fahrhaut liegt, sehen sie automatisch die alte Fahrbahn. Es gibt also kein Durchsacken.
   - Ein Alpha-Beta-Höhenfilter folgt Steigungen ohne Verzug und glättet Kanten.
     Nach Kuppen schwebt der LKW höchstens 0,6 Studs nach.
   - Die Mindesthöhe rechnet mit dem **geneigten** Kasten (Hang, Kuppe zwischen den Achsen).
   - Vorausschau-Strahlen an der Stoßstange sehen nur Fahrhaut und Gelände. Vor flachen Stufen heben sie stetig an,
     um höchstens 1 Stud. Mauern, Fahrzeuge und Gegenstände bleiben Hindernisse, der LKW klettert nicht darauf.
   - Die Neigung wird weich nachgeführt.
   - Simuliert auf 1.500 echten Fahrlinien: **74 % weniger harte Stöße**.
2. **Fahrhaut** (`RS.Run("Build", stadt)`):
   - Eine unsichtbare, geglättete Fläche über allen Fahrbahnen, ca. 11.400 Platten für alle drei Städte, Gruppe `RoadSkin`.
   - Die Haut existiert **nur für das Fahrwerk**: Figuren, der Kasten, andere Raycasts und Overlaps gehen durch sie hindurch.
   - Sie ist `Persistent`, wird also nie weggestreamt.
   - Die alten Platten kommen in die Gruppe `RoadBase`, aber nur, wenn die Haut sie nachweislich zu ≥ 90 % abdeckt
     (Raycast-Prüfung). Die sieht nur noch das Fahrwerk nicht, Figuren laufen normal darauf.
   - Kleine Lücken bis 4 Studs werden geschlossen, aber nur zwischen Fahrbahnen auf gleicher Höhe.
     So entstehen keine Rampen zwischen zwei Ebenen.
   - Unterführungen bleiben unverändert. Ebenso Schiffsdecks, `Deck` zählt nur unter `Bridges`.
   - Der Rechenkern ist gegen eine unabhängige Python-Referenz auf deinen echten Daten getestet: Abweichung ≤ 0,008, Abdeckung ≈ 100 %.
3. **Neue Optik** (`RS.Run("PlaceMeshes", stadt)` nach dem OBJ-Import):
   - Meshes aus **derselben** glatten Fläche: Optik und Fahrfläche liegen deckungsgleich.
   - 96 Meshes, ca. 171.000 Dreiecke, also weniger als die alten Meshes.
   - Fahrbahnteile unter einer anderen Fahrbahn (Unterführung) bleiben sichtbar, die Meshes decken sie nicht ab.
   - Asphalt, Kopfstein und Schotter getrennt, Kanten leicht gerundet.
   - Randschürzen nur dort, wo das Gelände tiefer liegt.
4. **Audit** (`RS.Run("Audit", stadt, {Mode = "alt" | "neu"})`):
   - Fährt alle Fahrbahn-Mittellinien und Navi-Linien LKW-genau mit echten Raycasts ab.
   - Zählt: Sprünge, Neigungsrucke, Löcher, Aufsetzen (Kasten trifft Boden) und Anstoßen (etwas im Kasten-Volumen).
   - Liefert eine Liste der schlimmsten Stellen: `RS.Spots(20)`, `RS.Look(i)` richtet die Kamera für Screenshots aus.
5. **Gelände** (`RS.Run("CarveTerrain", stadt, {Dry = true})`): Gelände, das durch die Fahrhaut ragt, wird knapp über
   der Fahrbahn abgesenkt. Das Original wird vorher als TerrainRegion gesichert.
6. **Testfahrt** (`RS.Run("DriveTest", {Lines = 6})`, nur im Play-Modus in der **Server**-Konsole, dann `RS.Status()`):
   - Autopilot über die Studio-Testattribute des Sitzes. Der LKW wird an den Routenanfang gesetzt und bremst in Kurven.
   - Misst Stöße, Luftsprünge und Hängenbleiben. Die Stellen stehen in `RS.LastDrive.Spots`.
7. **Alles ist rückgängig zu machen:** `RS.Restore(stadt)`, `RS.RestoreTerrain(stadt)`, `RS.UninstallTruck()`, `RS.RestoreMeshes(stadt)`.

Lange Funktionen startest du mit `RS.Run(...)` im Hintergrund und fragst alle 20–30 s `RS.Status()` ab.
So läuft dir kein MCP-Aufruf in einen Timeout.
- Fehler kommen mit vollständigem Traceback zurück.
- Hängt der Status, zum Beispiel weil der Play-Modus beendet wurde: `RS.Reset()`. Das bricht den alten Job ab.
  War es ein `Build` oder `CarveTerrain`, ist er halb fertig. Dann `Build` neu laufen lassen bzw. `RS.RestoreTerrain(stadt)`.

Wichtige Hinweise:
- **Vor `RS.InstallTruck()`** den Skript-Tab von `StarterPlayerScripts.Client.Truck` schließen, falls er offen ist.
  - Ist Collaborative Editing (Team Create) an, danach im Skript prüfen, dass oben „[RoadSmooth] Fahrwerk v2“ steht.
  - Falls ein Entwurf (Draft) offen ist: committen.
- **Nach `RS.PlaceMeshes`** nicht mehr `StrassenMeshU.Place`/`StrassenMeshU.Restore` benutzen.
  Die holen die alten Meshes bzw. Abschnitte zurück und es gibt doppelte Flächen. Zurück geht es nur mit `RS.RestoreMeshes(stadt)`.
- Die Haut ist für alles außer dem Fahrwerk unsichtbar und durchlässig.
  Eigene Raycasts, etwa von Verkehr, Fußgängern oder Platzierung, sehen weiter die alten Fahrbahnteile. Das ist gewollt.

## Harte Regeln
1. Lies zuerst `ServerStorage.DevTools.PolishLog` und lege **Block V „Straßen nahtlos (RoadSmooth)“** an.
   Trag dort nach jeder Phase Status, Zahlen vorher/nachher und offene Stellen ein, damit ein neuer Chat weitermachen kann.
2. Für jede Änderung außerhalb von RoadSmooth gilt:
   - `ChangeHistoryService`-Recording.
   - Vorher Backup: Originalwerte als Attribute (wie `PolishT_CF`) oder Kopie nach `ServerStorage.Backups`.
   - Keine Gameplay-Teile löschen. Das sind Bühnen, Trigger, Arrival/Unload-Zonen, Spawns, `HighwayTrigger`, `TruckSpot`, Plots.
3. Kein Balancing, keine UI-Änderungen. Keine echten DataStores beschreiben.
4. Ändere RoadSmooth-Code nur bei echten Fehlern. Dann: Fehler zeigen, minimal fixen, im PolishLog vermerken.
5. Nach jeder Phase: Audit-Zahlen vergleichen. Wird etwas schlechter, gehst du sofort zurück (Restore-Funktionen) und untersuchst den Grund.
6. Jede Phase endet mit Screenshots von denselben Stellen: die 3 schlimmsten Audit-Stellen je Stadt plus die
   Referenzkameras aus `PolishLog.L.Cameras`.

## Ablauf

**Phase 0: Ausgangslage**
- `print(RS.Help())`.
- Für alle drei Städte: `RS.Run("Audit", stadt, {Mode = "alt"})` (warten, `RS.Status()`).
  Zahlen notieren, `RS.Spots(15)` sichten, die 3 schlimmsten Stellen je Stadt per `RS.Look(i)` + Screenshot festhalten.
- Wenn der Play-Modus per MCP geht: `RS.Run("DriveTest", {Lines = 6})` in der Server-Konsole mit dem **alten** Fahrwerk
  als Vergleich (`RS.Status()` bis fertig).

**Phase 1: Fahrwerk**
- `RS.InstallTruck()`.
- Playtest: Prüfe in der Konsole, dass das Fahrwerk ohne Fehler startet.
  Dann `RS.Run("DriveTest", {Lines = 6})` und mit Phase 0 vergleichen.
- Kurz selbst prüfen:
  - Rückwärtsfahren
  - Rampe hoch und runter
  - Brücke
  - Autobahn-Reise (`HighwayTrigger`)
  - Parken/Aussteigen
  - Hinter einem anderen LKW herfahren: Er darf nicht auf ihn hinaufklettern.
- Nichts darf schlechter sein.

**Phase 2: Fahrhaut**
- Je Stadt erst `RS.Run("Build", stadt, {Dry = true})` (nur Zählung). Danach `RS.Run("Build", stadt)`.
- Prüfen:
  - Ordner `workspace.World.FahrHaut.<Stadt>` hat Platten.
  - Die alten Fahrbahnteile haben `CollisionGroup = RoadBase`.
- `RS.Run("Audit", stadt, {Mode = "neu"})` und mit Phase 0 vergleichen, dazu eine Testfahrt.
- Die Haut ist unsichtbar. Zum Kontrollieren kannst du kurz 20 Platten auf `Transparency 0.5` setzen, Screenshot machen
  und danach wieder auf 1.

**Phase 3: Gelände**
- `RS.Run("CarveTerrain", stadt, {Dry = true})`.
- Bei plausibler Anzahl ohne Dry ausführen. Danach Audit und Screenshots der Ränder:
  Es darf keine sichtbaren Gruben neben der Straße geben, sonst `RS.RestoreTerrain(stadt)` und mit größerem `Inset` erneut.

**Phase 4: Reststellen**
Arbeite die Audit-Liste ab, schlimmste zuerst: `anstoss`, dann `aufsetzen`, dann `loch`, dann `sprung` > 1.
Zu jeder Stelle: `RS.Look(i)` + Screenshot, Ursache benennen, minimal beheben. Danach `RS.Run("Build", stadt)` neu bauen
(schnell, idempotent) und ein kurzes Audit mit `Sample = 0.3`.

- **anstoss** (etwas ragt in den Fahrraum):
  - Objekt versetzen oder kürzen. Beispiel Kongress-`Forecourt`: Platte bis zur Bordsteinkante zurücknehmen.
  - Rein dekorative Überhänge über 3 Studs Höhe dürfen `CanCollide = false` bekommen.
  - Bäume und Laternen auf der Fahrbahn an den Rand rücken (Backup-Attribut).
- **aufsetzen** (Stufe ≥ 1,3 oder zu steiler Knick):
  - Spuren angleichen, mit den vorhandenen Werkzeugen (`SuburbRoads2.FixBranches`, `SuburbRoadFixT`, `RoadScan.PatchSeams`)
    oder einer Rampe, max. 15° und max. 3° Knick je Übergang.
  - Danach Haut neu bauen.
- **loch** (Lücke > 4 Studs in der Fahrbahn): Fehlendes Fahrbahnstück ergänzen, gleiche Breite und Höhe wie die Nachbarn.
  Besonders die verwinkelten Vorstadt-Kreuzungen in Portavia.
- **sprung > 1**: meist Kreuzungen mit großen Höhenunterschieden. Kreuzung auf eine gemeinsame Höhe/Ebene bringen.
- **Navi durch das Rathaus:**
  - Prüfen, ob die Straße in `CityPlanNeustadt` dort noch existiert.
  - Falls nicht: Linie im Plan entfernen bzw. umlegen, `NavExport` neu laufen lassen, danach `VenuesLand.ExportNav`.
- Nach Höhenänderungen > 0,3 Studs an Stadtstraßen: Exporter neu laufen lassen (siehe oben) und Verkehr/Fußgänger kurz prüfen.

**Phase 5: Optik**
- Falls ich die OBJ-Dateien noch nicht importiert habe: sag mir kurz Bescheid und warte.
- `RS.MeshStatus()`, dann je Stadt `RS.Run("PlaceMeshes", stadt)` (`RS.Status()` bis fertig).
  Es setzt die Meshes, archiviert die alten `StrassenMesh`-Meshes und blendet noch sichtbare alte Fahrbahnteile aus.
  Unterführungen bleiben sichtbar.
- Screenshots aus den Referenzkameras (Tag und Nacht). Prüfe:
  - Kanten an Bordsteinen
  - Übergänge Asphalt/Kopfstein
  - Kurven
  - Brücken, Unterführungen
  - Z-Fighting, Löcher
- Gefällt etwas nicht: `RS.RestoreMeshes(stadt)` (alles zurück). Kleine Fehler einzelner Meshes melden, nicht von Hand verbiegen.
- Hinweis: Die Meshes wurden aus dem Stand von test123 berechnet. Wenn du in Phase 4 Straßen verschoben hast, können dort
  kleine Abweichungen sichtbar sein. Notiere diese Stellen, dann rechne ich die Meshes neu.

**Phase 6: Abschluss**
- Audit für alle Städte mit `Vehicle = "Van"` und `Vehicle = "Titan"` sowie Testfahrten.
- Konsole ohne Fehler, Instanzen-Anzahl notieren.
- Endbericht als Tabelle vorher/nachher je Stadt: Sprünge > 0,15 / > 0,4 / > 1, Neigungsrucke, Löcher, Aufsetzen, Anstoßen, Testfahrt-Stöße.
  Dazu die erledigten und die offenen Stellen mit Koordinaten.
- Block V im PolishLog abschließen.
- Erinnere mich an **Strg+S**.

Leg los mit Phase 0.

=====
