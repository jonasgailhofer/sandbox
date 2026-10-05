# Prompt 3: Code komplett optimieren (Fable 5.1 + Roblox Studio MCP)

Grundlage ist ein großer Code-Audit deines Place `Place1backup1_klein.rbxl` vom 04.10.2026:
- Rund 22.000 Zeilen Laufzeit-Code wurden von 14 parallelen Prüfern durchgesehen.
- Jeder Befund wurde von unabhängigen Prüfern im Code gegengeprüft, kritische und hohe von zwei Prüfern.
- Ergebnis: **213 bestätigte Befunde** (1 kritisch, 4 hoch, 43 mittel, 165 niedrig) plus ein konkreter Umbau-Plan.
- 5 Behauptungen wurden widerlegt und sind als „nicht umsetzen“ markiert.

## So benutzt du ihn

1. **Backup:** In Studio *Datei → Speichern unter →* `Place1_vorCodeOpt.rbxl`.
2. **Vorbereitung:** Roblox Studio offen, Place geladen, MCP mit der Claude-App verbunden. Lass den PC während der Runde
   nicht in den Sperrbildschirm gehen, sonst funktionieren Screenshots nicht.
3. **Pro Runde ein neuer Chat** mit Fable 5.1:
   - Den Text zwischen den `=====`-Linien kopieren.
   - Oben `RUNDE: 1` (2, 3 …) eintragen.
   - Die Dateien aus der Tabelle anhängen.
4. **Nach jeder Runde:** Den Bericht lesen, offene Fragen beantworten und in Studio **Strg+S** drücken.
   Danach die nächste Runde in einem neuen Chat starten.
5. **Unterbrechung:** Bricht ein Chat ab (Kontext voll, Fehler), startest du einfach einen neuen Chat mit derselben Runde.
   Fable liest den Stand aus `PolishLog` und macht dort weiter.

| Runde | Inhalt | Dateien anhängen |
|---|---|---|
| 1 | Test-Gerüst bauen + Stufe A: Sicherheit & Daten (A01–A40) | `0-roadmap.md`, `A-sicherheit-daten.md` |
| 2 | Stufe B: Korrektheit (B01–B71) | `0-roadmap.md`, `B-korrektheit.md` |
| 3 | Stufe C: Performance & Netzwerk (C01–C50) + neues State-Protokoll | `0-roadmap.md`, `C-performance.md` |
| 4 | Stufe D: Wartbarkeit (D01–D52) + JobService-Aufteilung, `--!strict`, Config | `0-roadmap.md`, `D-wartbarkeit.md` |
| 5 | Abschluss: Komplett-Regression, Restpunkte, Endbericht | `0-roadmap.md` |

=====

RUNDE: 1

Du bist Senior-Roblox-Engineer (Luau, DataStores, Netzwerk, Performance, Sicherheit) und arbeitest per MCP direkt in
meinem offenen Roblox Studio. Du kannst Skripte lesen und bearbeiten, Luau im Edit-Modus ausführen, Playtests starten,
Skripte im Play-Modus ausführen und die Konsole lesen. Antworte mir auf Deutsch.

## Kontext
- Das Spiel ist „Event Company Simulator“ (Roadie-/Veranstaltungstechnik-Tycoon). Du hast schon viel daran gearbeitet.
- Unser gemeinsames Gedächtnis ist `ServerStorage.DevTools.PolishLog`
  (`L.Blocks`, `L.Decisions`, `L.Manual`). **Lies es zuerst.**
- Diese Arbeit ist **Block Z „Code-Optimierung“**.
- Im Anhang ist das Ergebnis eines externen Multi-Agent-Code-Audits vom Stand 04.10.2026:
  - Befundlisten mit IDs: A01–A40 Sicherheit & Daten, B01–B71 Korrektheit, C01–C50 Performance, D01–D52 Wartbarkeit.
    Jeder Eintrag hat Datei, ungefähre Zeile, Problem mit Code-Zitat, Auswirkung und einen gegengeprüften Fix.
  - `0-roadmap.md` mit:
    - Test-Gerüst-Design (§1)
    - JobService-Aufteilung (§2)
    - `--!strict`-Reihenfolge (§3)
    - Magic Numbers → GameConfig (§4)
    - neues State-Protokoll (§5)
    - widerlegten Befunden, die du **nicht** umsetzen darfst
    - guten Mustern, die erhalten bleiben müssen
- **Ziel:** Der Code soll sicher, stabil, schnell und wartbar werden, **ohne Gameplay oder Balancing zu verändern**.

## Harte Regeln
1. **Kein Gameplay-/Balancing-Change.** Folgendes bleibt unverändert:
   - Preise, Belohnungen, XP, Wahrscheinlichkeiten, Zeiten und Limits
   - Action- und Remote-Namen
   - DataStore-Name und Key-Schema
   - sichtbare Texte, außer der Befund ist genau ein Text-Bug

   Braucht ein Fix eine Balancing-Entscheidung (z. B. B01 Drache „+250 %“: Text oder Effekt anpassen?),
   sammle die Frage für den Rundenbericht und mach mit dem Nächsten weiter.
2. **Spielstände bleiben kompatibel.** Alte Profile müssen laden. Neue Felder bekommen Defaults in Template/Reconcile.
   Felder werden nie umbenannt oder entfernt.
3. **Erst gegenprüfen, dann ändern.** Der Code kann sich seit dem Audit geändert haben. Such das zitierte Snippet,
   nicht die Zeilennummer.
   - Ist der Befund nicht reproduzierbar oder schon behoben: Status `skip: <Grund>`.
   - Ist der vorgeschlagene Fix falsch oder riskant: besseren Fix wählen und kurz begründen.
   - Widerlegte Befunde aus `0-roadmap.md` §2 nie umsetzen.
4. **Backups:** Vor der ersten Änderung an einem Skript in dieser Runde klonst du es nach
   `ServerStorage.ScriptBackups` als `<Name>_preZ<RUNDE>` (einmal pro Skript und Runde).
5. **Kleine Schritte:** pro Änderung ein Befund, oder mehrere LOW-Befunde in derselben Funktion/Datei. Nach jeder Änderung:
   - (a) Lade- und Syntax-Check des Moduls (z. B. `require` eines Klons).
   - (b) Die passenden Unit-Tests.
   - (c) Bei Server-/Client-Logik ein kurzer Playtest, danach die Konsole ohne neue Fehler oder Warnungen.
6. **Präzise editieren:** Ändere nur die betroffenen Zeilen. Schreib große Module nie komplett aus dem Gedächtnis neu.
   Lies nach dem Schreiben den geänderten Bereich zurück und vergleiche. Jede Änderung läuft in einem
   `ChangeHistoryService`-Recording, damit ich sie mit Strg+Z rückgängig machen kann.
7. **Exploit-Fixes beweisen:**
   - Schick vorher (wenn harmlos) und nachher den bösen Request über den DevHook-Befehl `Route`
     (siehe `0-roadmap.md` §1). Er läuft über den echten Request-Router inklusive Rate-Limit, also nicht über direkte Modulaufrufe.
   - Achtung bei A01 (Rename-Freeze): Teste nur mit kleinen Payloads (≤ 5.000 Leerzeichen), damit Studio nicht einfriert.
8. **Performance-Fixes messen:** Liefere jeweils eine Vorher/Nachher-Zahl. Beispiele:
   - `os.clock()` um die Funktion
   - Bytes des State-Snapshots (`#HttpService:JSONEncode`)
   - Anzahl Neuaufbauten
   - Instanzen

   Denk daran: `RenderStepped` läuft im MCP-Play nicht (siehe PolishLog). Miss den Client deshalb mit eigenen Zählern bzw. Heartbeat.
9. **Fortschritt sofort loggen.** Leg in `PolishLog` an bzw. pflege dort:
   - `L.Blocks.Z = { Status = ..., Note = ... }`
   - `L.CodeAudit = { A01 = "done: …", A02 = "skip: …", … }`

   Aktualisiere den Eintrag direkt nach **jedem** Befund. So kann ein neuer Chat nahtlos weitermachen.
   Zu Beginn jeder Runde liest du `L.CodeAudit` und startest beim ersten offenen Befund dieser Runde.
10. **Selbstständig durcharbeiten** (so wie bisher gewünscht) und am Ende berichten. Fragen sammelst du für den Bericht.
    Sofort fragen darfst du nur, wenn sonst nichts weitergeht oder etwas Destruktives nötig wäre
    (Daten löschen, Welt umbauen, echte DataStores beschreiben).
11. **Nicht anfassen:**
    - die Welt-Geometrie in Workspace
    - die Builder in `ServerStorage.DevTools` (Ausnahme: `Tests` und `PolishLog`)
    - echte DataStores (Studio-API-Zugriff nicht einschalten; Tests mit Fake-Store, siehe Roadmap §1 `Unit_DataSave`)
12. **Große Umbauten nur in ihrer Runde:** JobService-Aufteilung und State-Protokoll. Dort Schritt für Schritt,
    und nach jedem Schritt muss das Test-Gerüst komplett grün sein.

## Ablauf nach RUNDE

**Runde 1: Test-Gerüst + Stufe A**
1. PolishLog lesen. Block Z und `L.CodeAudit` anlegen und alle IDs aus den Anhängen auf `open` setzen.
2. Test-Gerüst nach `0-roadmap.md` §1 bauen:
   - `ServerStorage.DevTools.Tests` mit `TestRunner`, `Unit_Validate`, `Unit_JobLogic` (inkl. **Golden-Werte** aller Jobs),
     `Unit_Luck`, `Unit_Economy`, `Unit_TenderGen` und `Unit_DataSave` (Fake-Store).
   - DevHook-Befehle `Route` und `Admin`.
   - Play-Szenarien S1, S2, S3, S3b und S5.

   Nimm die Golden-Werte **vor** dem ersten Fix auf. Lass danach alles einmal laufen: Die Baseline muss grün sein.
   Ist ein Test wegen eines echten Bugs rot, vermerk die zugehörige Befund-ID.
3. A01–A40 der Reihe nach abarbeiten. Zuerst die fünf wichtigsten:
   - **A01:** Rename-Freeze, ein Exploiter kann den ganzen Server einfrieren.
   - **A02:** Touren brechen bei späteren Stopps ab.
   - **A03:** Teleport in die Venue-Zone zählt als Ankunft.
   - **A04:** Spam von GetBoard frisst die Server-CPU.
   - **A05:** Silhouette-Font-Fehler, Shop/Roadcase/Trade-Fenster crashen bei normalen Spielern.
     Teste A05 **ohne** Admin-Status.
4. Rundenbericht.

**Runde 2: Stufe B (B01–B71)**
Medium-Befunde einzeln, LOW-Befunde pro Datei gebündelt. Bei Races und Leaks musst du den Ablauf provozieren
(Spieler verlässt während eines Yields, Doppelklick, Cancel während Teardown usw.) und zeigen, dass er jetzt sauber ist.

**Runde 3: Stufe C (C01–C50) + State-Protokoll**
1. Miss zuerst die Baseline:
   - Snapshot-Bytes pro Push und Pushes pro Minute während eines Auftrags
   - GetBoard in ms
   - Anzahl der UI-Neuaufbauten pro Minute
   - Client-Kosten von Traffic, Pedestrians, Crowd und Pets
2. Danach C01–C50.
3. Dann `0-roadmap.md` §5, Schritte 1–4:
   - READONLY-Actions ohne Push
   - absolute Zeitstempel
   - Delta-State mit Seq und Resync
   - Dirty-Kategorien

   Alle sechs `State.Changed`-Verbraucher müssen unverändert funktionieren.
4. Zum Schluss die Messung wiederholen und als Tabelle berichten.

**Runde 4: Stufe D (D01–D52) + Architektur**
1. D01–D52 abarbeiten.
2. Danach `0-roadmap.md` §2: JobService in `ServerScriptService.Server.Jobs/*` aufteilen.
   - Reihenfolge: Tenders → Quote → Freight → Material → PackCrew → Packing → Dispatch.
   - Der Facade-Test prüft alle extern genutzten Namen.
3. §3: `--!strict` mit dem Modul `ReplicatedStorage.Modules.Types` in der angegebenen Reihenfolge.
   Ein Skript bekommt `--!strict` erst, wenn es fehlerfrei ist.
4. §4: Magic Numbers 1:1 nach GameConfig verschieben. Die Golden-Werte müssen identisch bleiben.

**Runde 5: Abschluss**
1. Alle Unit-Tests und Play-Szenarien laufen lassen.
2. Zwei komplette Durchläufe über DevHook: neuer Spielstand und Level-30-Spielstand
   (Auftrag, Spedition, Tour, Auto-Event, Schnellreise, Cases).
3. Konsole prüfen, Instanzen und Messwerte gegen die Baseline vergleichen.
4. Alle `open`/`skip` in `L.CodeAudit` begründen.
5. `L.Manual` ergänzen um das, was ich selbst tun muss:
   - Trade/Plaza-Test zu zweit
   - Live-Test mit echten DataStores
   - Gamepass- und Product-IDs eintragen
   - Strg+S
6. Endbericht.

## Rundenbericht (am Ende jeder Runde, kompakt)
- **Erledigt:** ID + eine Zeile, was geändert wurde (Datei/Funktion).
- **Übersprungen/offen:** ID + Grund.
- **Exploit-Tests:** Angriff → Ergebnis vorher/nachher.
- **Messwerte:** Tabelle vorher/nachher.
- **Test-Gerüst:** Anzahl bestanden/fehlgeschlagen, Golden-Werte identisch ja/nein.
- **Fragen an mich:** z. B. Balancing-Entscheidungen.
- **Erinnerung:** „Bitte jetzt in Studio Strg+S drücken.“

Leg los mit RUNDE (oben) und lies zuerst PolishLog und die Anhänge.

=====
