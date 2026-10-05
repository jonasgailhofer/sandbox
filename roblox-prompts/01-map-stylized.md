# Prompt 1: Map auf „stylized“ umbauen (für Claude + Roblox Studio MCP)

**So benutzt du ihn:**
1. Sichere den Place vorher als Kopie (Datei → Speichern unter → `Place1_backup.rbxl`).
2. Roblox Studio öffnen, den Place laden und den eingebauten MCP-Server aktivieren
   (Anleitung: <https://create.roblox.com/docs/studio/mcp>).
3. In Claude (Desktop-App oder Claude Code) die Roblox-Studio-Verbindung einschalten.
4. Alles zwischen den beiden `=====`-Linien kopieren und als erste Nachricht schicken.
5. Nach jeder Phase prüfst du kurz in Studio und schreibst dann „weiter“ (oder was dir nicht gefällt).

=====

Du bist ein erfahrener Roblox-Environment-Artist und Luau-Entwickler. Du bist über MCP direkt mit meinem
offenen Roblox-Studio verbunden. Nutze die verfügbaren Tools: Luau-Code im Edit-Modus ausführen,
den Explorer/Datamodel lesen, Viewport-Screenshots machen und Modelle aus dem Creator Store einfügen.

## Ziel
Meine Map soll **stylized** aussehen, nicht hyperrealistisch. Gemeint ist ein sauberer, gemütlicher
„Cozy-City“-Look wie in Toca Boca, Animal Crossing oder Fortnite Creative:
satte, harmonische Farben, weiches warmes Licht, klare Formen, wenig Texturrauschen und Bäume, die nach
Cartoon aussehen statt nach Fotoscan. Das Gameplay darf dabei **auf keinen Fall** kaputtgehen.

## Was du über den Place wissen musst (habe ich vorher analysiert)
- Es ist ein Roadie-/Veranstaltungstechnik-Tycoon mit drei Städten: **Neustadt** (Altstadt, Ringstraße),
  **Portavia** (Hafen, Speicherstadt) und **Metropolis** (Großstadt, Arena, Stadion). Die Städte liegen weit
  auseinander (X ≈ 700, X ≈ 7700, X ≈ −7800).
- In Workspace liegen ca. **204.000 Parts**. Davon sind etwa 156.000 Parts, 33.000 MeshParts und 16.000 WedgeParts.
- Struktur: `Workspace.World` mit
  - `City/<Stadt>/Houses|StreetSurface|Parks|Quays|Promenade|Skyline|Lanterns|StreetLights|Bridges|Gardens|Landmarks|Squares|Speicherstadt|HarborHouses|Hafenanlagen|Containerterminal`
  - `Nature/<Stadt>/C<x>_<z>/…`: Chunk-Ordner mit ca. 15.000 **realistischen PBR-Bäumen, Felsen und Büschen**
    (Pine, Spruce, Oak, Birch, Broadleaf, „Medium Moss Boulder“, Bush1–5, Rhododendron) mit `SurfaceAppearance`.
  - `Venues/<Venue>` (Stadion, Arena, HafenOpenAir, Stadthalle, Kongress, ClubDock, TVStudio, Messehalle, Stadtpark, Marktplatz)
  - `Industrie`, `Roads`, `Plots`, `RoadcaseStations`, `Hub`, `Trading`, `Regions`, `Ground` und `SpawnLocation`
- Die Häuser wurden prozedural von Builder-Modulen in `ServerStorage.DevTools` gebaut
  (`WorldKit`, `BuildKit`, `CityBuildCore`, `CityBuildNeustadt`, `AltstadtKit`, `ModernKit`, `BuildPortavia`, `BuildMetropolis` …).
  Die Farbpaletten stehen in `WorldKit.C` und `BuildKit.C`.
- **Tag-Nacht-Zyklus:** `ServerScriptService.Main` setzt beim Start `Lighting.ClockTime = 14` und lässt die Zeit laufen
  (1 Spielstunde = 1 Minute). Das Licht muss also **zu jeder Tageszeit** gut aussehen: Mittag, Abendrot und Nacht.
  Teste mit Screenshots bei ClockTime 13, 18 und 22.
- **Nachtlogik:** Das Client-Modul `StarterPlayerScripts.Client.Ambient` sucht Parts mit den Attributen
  `NightWindow`, `NightLight` und `TownClock`. Fenster mit `NightWindow` werden nachts zu Neon. Laternen mit
  `NightLight` merken sich Material und Farbe (`ECS_LampMat` / `ECS_LampCol`) und schalten ihr Light an und aus.
  Diese Attribute dürfen nie entfernt werden. Wenn du solche Parts umfärbst, lösche vorhandene
  `ECS_LampMat`/`ECS_LampCol`-Attribute, damit die neue Farbe übernommen wird.
- Warum die Map gerade realistisch und eher fad wirkt:
  1. **Farben:** Die Palette ist fast nur Grau, Off-White und dunkles Blaugrau. Die häufigsten Farben sind
     (246,244,238), (163,162,165), (46,58,74), (176,170,160) und (52,66,82).
  2. **Materialien:** Realistische Materialien dominieren: Concrete 45k, Glass 32k, Metal 22k, Slate 8k und Cobblestone 5k.
  3. **Bäume/Felsen:** Die PBR-Fotoscan-Bäume und -Felsen beißen sich stilistisch mit den glatten Plastik-Häusern.
  4. **Schatten:** `CastShadow` ist bei ~83 % aller Parts aus. Die Häuser wirken deshalb flach und ohne Tiefe.
  5. **Licht:** Lighting = ShadowMap mit grauem Atmosphere-Dunst (Haze 1.1). ColorCorrection hat kaum Sättigung (0.08)
     und der Bloom ist hart.
  6. **Details:** Es gibt sehr viele Mini-Detailteile (Fenstersimse, Stürze, Keystones, Mullions). Das ist
     realistisch gedacht und kostet Performance.

## Unverletzliche Regeln (Gameplay-Schutz)
1. **Niemals umbenennen, löschen, verschieben oder skalieren:** Parts und Modelle, die Skripte benutzen.
   Dazu gehören alles mit `Stage`, `StagePad`, `PadCorner`, `Arrival`, `Unload`, `FOH`, `Trigger`, `Plot`,
   `FreeLot`, `FreeSign`, `CaseSpot`, `Pedestal`, `Screen`, `Sign`, `Kiosk`, `Spawn`, `HighwayGate`,
   `Field` und `StageLabel` im Namen, außerdem alles in `Hub`, `Trading`, `Plots`, `RoadcaseStations` und `Regions`.
   Bevor du *irgendetwas* löschst oder umbenennst, durchsuche alle Skripte nach dem Namen
   (z. B. mit `Source:find`). Ist der Name dort referenziert, bleibt er unangetastet.
2. Teile mit den Attributen `NightWindow`, `NightLight` oder `TownClock` sowie alle Teile mit `ProximityPrompt`,
   `ClickDetector`, `SurfaceGui` oder Skript-Referenz zählen ebenfalls als geschützt.
   Bei geschützten Teilen änderst du nur Optik: `Color`, `Material`, `MaterialVariant`, `Reflectance`
   und `CastShadow`. `Transparency` nur, wenn das Teil vorher schon sichtbar war. `CanCollide`, Größe,
   Position und Attribute fasst du nie an.
3. Jede Änderung läuft über `ChangeHistoryService:TryBeginRecording` / `FinishRecording`, damit ich sie mit Strg+Z
   zurücknehmen kann.
4. Arbeite in Batches (z. B. 2.000 Instanzen, dann `task.wait()`), damit Studio nicht einfriert.
   Teste jeden Schritt zuerst an **einem** Beispiel (ein Haus, ein Baum, ein Straßenstück). Mach einen Screenshot,
   zeig ihn mir und rolle es erst dann auf alles aus.
5. Markiere bearbeitete Instanzen mit dem Attribut `Stylized = true`, damit jeder Schritt idempotent ist.
6. Leg den ganzen Stil-Code als wiederverwendbares Modul `ServerStorage.DevTools.StylePass` an
   (Palette + Funktionen pro Phase). So kann ich ihn später erneut laufen lassen.
7. Mach nach jeder Phase Vorher/Nachher-Screenshots aus **denselben drei Kamerapositionen**
   (Neustadt-Ring, Portavia-Hafen, Metropolis-Stadion). Warte danach auf mein „weiter“.
8. Füge insgesamt **nicht mehr Parts hinzu, als du entfernst**. Die Performance soll gleich bleiben oder besser werden.

## Vorgehen in Phasen

**Phase 0: Bestandsaufnahme.**
Lies das Datamodel und gleiche meine Analyse oben ab. Prüf, welche Namen in Skripten vorkommen, und erstelle
daraus eine Schutzliste. Setz die drei Referenzkameras und mach Vorher-Screenshots.
Stell mir dann max. 3 kurze Fragen, zum Beispiel: Eher pastellig oder kräftig? Wie dunkel darf die Nacht sein?
Darf ich Mini-Details zusammenführen?

**Phase 1: Licht & Atmosphäre (größter Effekt, null Risiko).**
- Setz `ClockTime` nicht fest (macht das Server-Skript). Die Werte müssen über den ganzen Zyklus funktionieren.
  Optional, nur nach meinem OK: ein kleines Client-Modul `Client.SkyGrade`, das Atmosphere und ColorCorrection
  nach Tageszeit sanft tweent (Tag: frisch und hell, Abend: warm-orange, Nacht: blau-violett, nicht zu dunkel).
- `Lighting.Technology = Future`. Prüf danach die Performance. Ist sie schlecht, bleib bei `ShadowMap`.
- Lighting-Werte:
  - `Brightness ≈ 3`
  - `Ambient` und `OutdoorAmbient` wärmer und heller (z. B. 120,115,135 bzw. 150,150,170)
  - `EnvironmentDiffuseScale ≈ 0.4` und `EnvironmentSpecularScale ≈ 0.2`, damit weniger PBR-Glanz entsteht
  - `ShadowSoftness ≈ 0.15`
- `Atmosphere`: `Density ≈ 0.28`, `Haze ≈ 0`, `Glare ≈ 0`, ein leicht bläulich-pastelliges `Color` und ein warmes `Decay`.
- `ColorCorrection`: `Saturation +0.2…0.3`, `Contrast ≈ 0.08` und einen leicht warmen Tint.
- `Bloom`: `Intensity ≈ 0.5`, `Size ≈ 20` und `Threshold ≈ 1.8` (nur Neon und Lichter sollen leuchten).
  `SunRays` dezent lassen.
- Sky: Füg einen stylized/cartoon Skybox aus dem Creator Store ein (Suchbegriffe: "stylized sky", "cartoon skybox").
  Prüf zuerst, dass er keine Skripte enthält. Dazu eine `Clouds`-Instanz unter Terrain mit weißen, fluffigen Wolken.

**Phase 2: Farbpalette & Materialien.**
- Definiere im StylePass-Modul eine feste Palette mit ca. 20 Farben und zeig sie mir. Leitlinien:
  - Wände: Creme, Pastellgelb, Pfirsich, Mint, Hellblau, Altrosa.
  - Dächer: Terrakotta, Petrol, Dunkelblau, Schiefer-Lila.
  - Zierleisten in warmem Weiß. Glas hellblau statt dunkel.
  - Straße: blaugrau statt schwarz. Gehweg: warmes Beige.
  - Grün: saftiges Gras (≈ 106,170,76) und kräftiges Laub.
  - Kein reines Schwarz, Weiß oder Neutralgrau.
- Mapping nach Namen und Rolle, also nicht einfach jede Farbe ersetzen:
  - `Body` → Wandfarbe
  - `Roof*` / `Dormer*` → Dachfarbe
  - `Win*` / `Cornice` / `Plinth` → Zierfarbe
  - `*Glass` → Glasfarbe
  - Gib jedem Haus eine leicht variierte Wandfarbe aus der Palette, mit HSV-Jitter von ±4 % pro Haus-Modell
    (deterministisch über den Haus-Namen oder die Position). So wirkt die Straße lebendig statt gleichförmig.
- Materialien: `Concrete`, `Slate`, `Cobblestone`, `Pavement`, `Limestone`, `Granite`, `Brick`, `Metal` und
  `Plastic` → `SmoothPlastic`. Für Straßen/Plätze ist ein dezentes eigenes `MaterialVariant` (stylized, wenig Rauschen) okay.
  `Glass` → `SmoothPlastic` mit `Transparency 0.25` und `Reflectance 0.1`, aber nur, wenn das Teil vorher durchsichtig war.
  Neon bleibt.
- Pass auch die Paletten in `WorldKit.C` und `BuildKit.C` an, damit künftig gebaute Teile automatisch passen.

**Phase 3: Natur (der größte Stilbruch).**
- Teste an **einem** Baum jedes Typs (Pine, Spruce, Oak, Birch, Broadleaf), was besser aussieht. Zeig mir beides als Screenshot:
  - (a) `SurfaceAppearance` entfernen und die Meshes flach einfärben.
  - (b) Den Baum durch einen stylized Low-Poly-Baum ersetzen. Bau ihn prozedural: Stamm als Zylinder, Krone aus
    2–3 Kugeln/Blöcken in 2–3 Grüntönen, Nadelbäume als gestapelte Kegel/Wedges. Max. 5 Parts pro Baum.
    Übernimm CFrame und Höhe des Originals und dreh/skaliere leicht zufällig (deterministisch).
- Rolle die bessere Variante chunkweise aus (`Nature/<Stadt>/C*`). Zähl die Parts vorher und nachher.
- Felsen: `SurfaceAppearance` weg, `SmoothPlastic`, warmes Blaugrau mit zwei Tönen. Büsche: runde Kugelbüsche in Grün.
- Terrain:
  - `Terrain:SetMaterialColor` für Grass, LeafyGrass, Ground, Rock, Sand und Mud in Palette-Farben.
  - `Decoration` aus, falls das realistische Gras stört (frag mich).
  - Wasser: `WaterColor` türkis, `WaterTransparency ≈ 0.6`, `WaterReflectance ≈ 0.3` und `WaterWaveSize` klein.

**Phase 4: Formsprache & Tiefe.**
- `CastShadow = true` für alle Gebäude-Hauptkörper, Dächer, Bäume und großen Props (Größe > ca. 4 Studs).
  Kleinteile bleiben ohne Schatten.
- Optional, nur nach meinem OK: Mini-Details zusammenfassen bzw. vereinfachen.
  Pro Fenster reichen 1–2 Parts statt Sims + Sturz + Keystone + Rahmen + Glas.
  Das ist stilistischer **und** spart zehntausende Parts. Verwende dafür, wo es geht, die Builder-Module statt Einzelparts.
- Stylized-Akzente sparsam einsetzen: Blumenkästen, bunte Markisen, Bänke, Laternen mit warmem `PointLight` (Range 12–16).
  Nie mehr Parts hinzufügen, als in diesem Schritt gespart wurden.

**Phase 5: Feinschliff & Kontrolle.**
- Screenshots aus allen drei Referenzpositionen plus 2–3 Bodenperspektiven in Spielerhöhe.
- Kurzer Playtest (Play-Modus starten, Konsole auf Fehler prüfen und wieder stoppen).
- Abschlussbericht:
  - Was wurde geändert?
  - Part-Anzahl vorher/nachher
  - Offene Ideen
  - Wie kann ich einzelne Phasen per `StylePass` erneut ausführen?

Antworte mir auf Deutsch. Fang mit Phase 0 an.

=====
