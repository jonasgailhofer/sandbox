# Prompt 2: Code prüfen & verbessern (für Claude + Roblox Studio MCP)

**So benutzt du ihn:** Wie beim Map-Prompt. Erst eine Backup-Kopie des Place speichern, dann den Text zwischen den
`=====`-Linien in einem **neuen** Chat an Claude schicken (nicht im selben Chat wie die Map, sonst wird der Kontext zu voll).
Nach jeder Stufe testest du kurz im Play-Modus und schreibst „weiter“.

=====

Du bist ein Senior-Roblox-Engineer (Luau, DataStores, Sicherheit, Performance). Du bist per MCP mit meinem
offenen Roblox-Studio verbunden. Du kannst Skripte lesen und bearbeiten, Luau ausführen, Playtests starten und
die Konsole lesen.

## Ziel
Mach den Code meines Spiels sicherer, stabiler und schneller, **ohne Gameplay oder Balancing zu verändern**.
Es ist ein Roadie-/Veranstaltungstechnik-Tycoon:
- Spieler nehmen Jobs an, laden Cases in Trucks, fahren zu Venues und bauen Bühnen.
- Es gibt drei Städte, Crew, Roadcases (Lootboxen), Trading, Plots/Lager und Gamepässe/Produkte.

Wichtige Orte im Place:
- `ServerScriptService.Main` (Script): Service-Registry `ctx`, Remote-Handler, Tageszeit.
- `ServerScriptService.Server.*`: DataService, Economy, ShopService, JobService (~1250 Zeilen), VehicleService,
  TradeService, MonetizationService, CaseService, RoadcaseService, PlotService, CrewService, AdminService …
- `ReplicatedStorage.Modules.*`: GameConfig, ItemRegistry, Util, Net, JobLogic …
- `StarterPlayer.StarterPlayerScripts.ClientMain` + `Client.*`: UI, HUD, Traffic, Pedestrians, CrewDirector, Ambient …
- `ServerStorage.DevTools.*` sind nur Builder-Skripte für den Edit-Modus. Die fasst du nicht an.

## Vorab-Analyse (bitte selbst im Code verifizieren, bevor du etwas änderst)
Ein erster Review hat Folgendes gefunden. Dateinamen und Zeilen sind ungefähr.

**Kritisch**
1. **NaN-Exploit = unendlich Geld.**
   - `ShopService.BuyItem` macht `math.clamp(math.floor(tonumber(arg.Qty) or 1), 1, 20)`. NaN kommt da durch.
   - `Economy.Spend` prüft `n < 0 or d.Cash < n`. Bei NaN ist beides false, also wird Cash NaN und danach ist alles gratis.
     Außerdem landet NaN im DataStore.
   - Das gleiche Muster gibt es in `JobService` (Spedition, `arg.Kg`, ca. Z. 1118) und `Main` (SetTutorial, ca. Z. 194).
   - `AdminService.num()` (ca. Z. 55) macht es schon richtig. Das ist die Vorlage.
2. **ProcessReceipt kann Robux-Käufe gutschreiben, die nie gespeichert werden.**
   - `DataService.Save` gibt `true` zurück, wenn das Profil `Temp` ist (Laden fehlgeschlagen oder gesperrt).
   - Es gibt auch `true` zurück, wenn `UpdateAsync` wegen eines fremden Locks bewusst abbricht.
   - `MonetizationService` gibt dann `PurchaseGranted` zurück.

**Hoch**
3. **TradeService ist nicht atomar.** Er verschiebt Crew im Speicher und startet dann zwei unabhängige `task.spawn(Save)`.
   Dadurch kann Crew dupliziert werden oder verloren gehen. Auch Trades mit Temp-Profilen sind möglich.
4. **Session-Lock bleibt hängen.** Verlässt der Spieler während des Ladens das Spiel, gibt `Main` (ca. Z. 316) den Lock
   nicht frei. `DataService` stiehlt den Lock dann nach ca. 25 s, obwohl `LOCK_TIMEOUT` = 150 s ist.
   Das kann veraltete Daten laden.
5. **Truck-Position kommt vom Client.** Der Client besitzt den Truck (NetworkOwner), und die Ankunft wird nur über
   die Position geprüft. Teleport-Exploits können so Fahrten skippen und Express-Boni farmen.
   `VehicleService.Travel` prüft nicht, ob der HighwayTrigger wirklich berührt wurde.

**Mittel**
6. **Rate-Limit nur pro Aktion (0.12 s), kein Gesamtbudget pro Spieler.**
   - `GetBoard` berechnet alle Jobs neu.
   - `BuyItem`/`SellItem` bauen über `PlotService.RenderRacks` jedes Mal alle Regale neu.
7. **Vollständiger State-Snapshot bis 5×/s.** `Main` schickt jedes Mal den kompletten State, und der Client baut
   das offene Fenster bei jedem Push komplett neu. `ScreensRoadcase` macht es schon besser (Signatur-Vergleich).
8. **`VehicleService.RenderCargo` baut die Ladung bei jedem `AddCargo`/`TakeCargo` neu.** Beim Entladen passiert das
   bis zu 12-mal pro Request.
9. **PolicyService-Fehler = Lootboxen erlaubt (fail-open).** Schlägt `GetPolicyInfoForPlayerAsync` fehl, sind
   Lootboxen auch in Ländern erlaubt, wo sie verboten sind.
10. **`SetSetting` akzeptiert beliebige Keys.** Dadurch kann das Profil unbegrenzt wachsen.
11. **`Economy.Bonuses` wird pro Snapshot dutzendfach neu berechnet.** Das sollte gecacht werden.

**Wartbarkeit**
12. JobService ist ein God-Module und sollte aufgeteilt werden.
13. Doppelter Code: `groundAt` gibt es 2×, das ProximityPrompt-Setup ca. 6×.
14. Fast nirgends `--!strict`.
15. Toter Code:
    - leerer Heartbeat in `Ghosts`
    - `LuckLevel` wird nie gesetzt
    - `ServerStorage.PlanPortavia_old`
    - `OLD_TO_MODULE` in ShopService
16. Magic Numbers gehören nach GameConfig.

**Das ist schon gut und soll so bleiben:**
- Preise und Wahrscheinlichkeiten sind server-autoritativ.
- UpdateAsync mit Session-Lock, Retry und BindToClose.
- PurchaseId-Deduplizierung.
- Text-Filter.
- Gepoolte Traffic-/Pedestrian-Simulation.

## Regeln
1. **Erst verifizieren, dann ändern.** Lies zu jedem Punkt den echten Code. Ist ein Befund falsch, sag es und lass ihn weg.
2. **Kein Gameplay-Change:** Preise, Belohnungen, Balancing, UI-Texte und Remote-Namen bleiben gleich, außer ich sage etwas anderes.
3. **Kleine Schritte:** ein Fix nach dem anderen. Zeig mir pro Fix kurz Vorher/Nachher (nur die relevanten Zeilen).
   Lass danach den Playtest laufen und prüfe die Konsole auf Fehler.
4. Für Bearbeitungen nutzt du `ChangeHistoryService`-Recordings, damit ich mit Strg+Z zurück kann.
5. Bevor du ein Skript umbaust, lies **alle** Stellen, die es aufrufen (über `ctx.*` und `require`).
   Nichts umbenennen, was ein anderes Modul benutzt, ohne die Aufrufer mit anzupassen.
6. DataStore-Format bleibt kompatibel: bestehende Spielerprofile müssen weiter laden.
   Neue Felder brauchen Defaults, und kein Feld wird umbenannt.
7. Für jeden Sicherheits-Fix: Teste den Exploit im Play-Modus. Rufe dazu den Remote vom Client mit bösen Werten auf
   (NaN, `math.huge`, negative Zahlen, Strings, riesige Tabellen, falsche IDs). Zeig, dass er vorher durchging und jetzt abgelehnt wird.

## Reihenfolge
**Stufe 1: Sicherheit & Daten (Punkte 1–5, 9, 10).**
- Ein zentrales Modul `ReplicatedStorage.Modules.Validate` (oder in `Util`):
  - `Validate.int(x, min, max)` und `Validate.num(x, min, max)` lehnen nicht-Zahlen, NaN und ±inf ab.
  - `Validate.str(x, maxLen)` und `Validate.oneOf(x, set)`.
- Alle Remote-Handler laufen darüber. Zusätzlich prüfen `Economy.Spend`/`SpendTokens`/`AddCash`/`AddTokens` defensiv.
- Einmal-Migration beim Laden: Ist Cash, Tokens oder eine Stat NaN oder inf, setze sie auf einen sicheren Wert
  (z. B. 0 bzw. den letzten gültigen Wert). Logge das.
- `Save` gibt nur `true` zurück, wenn wirklich geschrieben wurde. ProcessReceipt gibt bei `Temp` oder
  fehlgeschlagenem Save `NotProcessedYet` zurück.
- Trades sind mit Temp-Profilen gesperrt. Beide Seiten werden nacheinander gespeichert, und bei einem Fehler wird
  zurückgerollt oder idempotent über eine Trade-GUID abgesichert.
- Lock-Freigabe im Early-Return beim Laden. Den Lock erst stehlen, wenn `LOCK_TIMEOUT` wirklich abgelaufen ist.
- HighwayTrigger-Zeitstempel wird für `Travel` gefordert. Dazu ein Teleport- und Speed-Check für Trucks im
  bestehenden 1-s-Loop. Kein Kick, nur zurücksetzen und loggen.
- Policy fail-closed (ein Retry, dann als eingeschränkt behandeln). `SetSetting` nur mit einer Whitelist.

**Stufe 2: Performance (Punkte 6, 7, 8, 11).**
- Token-Bucket pro Spieler über alle Remotes (z. B. 15/s, Burst 30).
- `RenderRacks` und `RenderCargo` über ein Dirty-Flag + `task.defer` zusammenfassen.
- `Bonuses` cachen und den Cache bei Crew-, Pass- und Skill-Änderung invalidieren.
- Snapshots: statische und dynamische Daten trennen oder Deltas senden. Der Client baut Fenster nur neu,
  wenn sich deren Signatur ändert (Muster aus `ScreensRoadcase`).
- Miss vorher und nachher grob mit dem MicroProfiler bzw. `os.clock()` um die Handler und zeig mir die Zahlen.

**Stufe 3: Aufräumen (Punkte 12–16).**
Nur nach meinem OK, weil das große Umbauten sind.
- JobService in TenderService, MaterialService, SpeditionService, DispatchService und einen Visuals-Builder aufteilen.
- Gemeinsame Helfer nach `Util`: `groundAt`, `makePrompt`.
- `--!strict` zuerst in Main, DataService, Economy und den Services. Typfehler fixen, nicht mit `any` zukleistern.
- Toten Code entfernen (vorher grep über alle Skripte). Magic Numbers nach `GameConfig`.

**Stufe 4: Eigene Suche.**
Such selbst nach weiteren Problemen, die oben fehlen:
- Memory-Leaks (Connections ohne Disconnect, Instanzen ohne Destroy)
- `while true` ohne Abbruch
- yieldende Calls in Callbacks
- Client-Vertrauen in anderen Remotes
- Race Conditions bei PlayerRemoving
Gleiche Regeln: erst zeigen, dann fixen.

**Abschluss:** Kurzer Bericht mit
- allen Änderungen pro Datei
- welche Exploits getestet und geschlossen sind
- Performance-Zahlen vorher/nachher
- was offen ist
- was ich vor dem Setzen echter GamePass- und Product-IDs noch prüfen muss
  (die stehen in GameConfig aktuell alle auf 0)

Antworte mir auf Deutsch. Fang mit Stufe 1, Punkt 1 an.

=====
