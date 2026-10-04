# Befundliste Stufe D: Wartbarkeit (Duplikate, toter Code, veraltete APIs, Struktur)

Quelle: Multi-Agent-Code-Audit von `Place1backup1_klein.rbxl` (Stand 04.10.2026). Jeder Befund wurde von mindestens einem unabhängigen Prüfer im Code gegengeprüft, kritische und hohe Befunde von zwei Prüfern.
- **Zeilennummern** beziehen sich auf diesen Stand. Suche im aktuellen Code nach dem zitierten Snippet, nicht nach der Zeilennummer.
- **Fix (gegengeprüft)** ist der vom Prüfer korrigierte Fix. Er hat Vorrang vor dem ursprünglichen Vorschlag.
- Die Befundtexte sind auf Englisch, die IDs (D01 …) dienen dem Status-Tracking in `ServerStorage.DevTools.PolishLog` (Block Z).

## Übersicht

| ID | Schwere | Datei | Titel |
|---|---|---|---|
| D01 | medium | JobService | JobService is an 1,850-line god module (board, tenders, packing crew, robots, material, sp |
| D02 | medium | RoadcaseService | CaseService and RoadcaseService duplicate the whole purchase/open pipeline (roll, open, re |
| D03 | medium | Effects | Vehicle 'prop' code copy-pasted three times with diverging behaviour (door offset, ground  |
| D04 | low | CrewRegistry | Missing load-time consistency asserts in the registries (ByRarity overwrite, PassOrder cov |
| D05 | low | GameConfig | Unused exports and dead data across the registries |
| D06 | low | GameConfig | G.Expansions is dead legacy config that contradicts WarehouseConfig (only .Name is still r |
| D07 | low | GameConfig | Pass, staff and expansion effect numbers are duplicated as magic numbers in services and i |
| D08 | low | ItemRegistry | Region and level data are duplicated between ItemRegistry, RoadcaseRegistry and WorldConfi |
| D09 | low | VehicleRegistry | VehicleRegistry Titan40 has a dead TokenPrice that no server or UI path honours |
| D10 | low | WorldConfig | Large duplication between small() and big() stage layout builders |
| D11 | low | WorldConfig | Shared registry tables are mutable; layout slots and job defs are shared by reference acro |
| D12 | low | Main | Duplicate or diverging region logic with magic X thresholds |
| D13 | low | Main | Change-notification hooks duplicated with diverging side effects (OnCrewChanged / OnPasses |
| D14 | low | Main | No shared safe-loop helper: every server forever-loop hand-rolls (or forgets) its error is |
| D15 | low | AdminService | Admin MAX_CREW = 300 contradicts G.CrewInventoryMax = 100 |
| D16 | low | AdminService | Validate is used in 7 of 25 server modules; other handlers hand-roll checks or duplicate V |
| D17 | low | AdminService | AdminService duplicates helpers (ground raycast, numeric clamp) and re-requires modules in |
| D18 | low | AdminService | C.Staff mints cash to bypass the hire cost: cash can drift if HireCost and Hire disagree |
| D19 | low | CrewService | Dead code / unused exports and imports in the slice |
| D20 | low | CrewWork | Crew show/idle positions computed by duplicated server and client formulas with magic numb |
| D21 | low | DataService | Profile migrations are spread across four places; Template.Version is unused; Crew.Migrate |
| D22 | low | DataService | Small dead code and redundancy in the data and validation layer |
| D23 | low | JobService | Dead code: unused locals/exports in the jobs slice |
| D24 | low | JobService | Server re-implements shared Util helpers: fmtT == U.Tons, S.MatNeed/MatMissing == U.MatMis |
| D25 | low | JobService | Token-to-cash rate is still hardcoded as 100 in JobService.rentPrice (Polish F7 incomplete |
| D26 | low | JobService | Magic numbers scattered through job logic (rent, distances, timings) |
| D27 | low | JobService | Tender spawn errors are silently swallowed |
| D28 | low | JobService | Night-time thresholds hardcoded in four modules, and the gameplay gate depends on them |
| D29 | low | JobService | Owner-only ProximityPrompts copy-pasted 8 times and shown to every player |
| D30 | low | JobService | crewLoop fetch branch and robotLoop duplicate about 50 lines of route/claim/drop logic |
| D31 | low | PlacementService | Build-phase advance uses a hard-coded upper bound 6 although the job carries MaxPhase |
| D32 | low | PlacementService | Dead branch in AutoTruss: the worker list never contains 'Crew_MasterRigger' |
| D33 | low | RoadcaseService | Dead runtime code: RoadcaseService.RefreshSigns targets a folder that no longer exists, pl |
| D34 | low | StaffService | Lead-training level requirement `10 + Tier * 2` hardcoded on server and client |
| D35 | low | StaffService | Duplicated magic numbers and divergent rent formulas across slice |
| D36 | low | TenderGen | TenderGen conditions(): second chance() roll triggers a DuplicateCondition lint; intent un |
| D37 | low | TradeService | Dead code and unused locals in the slice |
| D38 | low | VehicleService | Minor dead or redundant code in the slice |
| D39 | low | VehicleService | Duplicated ProximityPrompt and grid code plus scattered magic numbers in the vehicle and b |
| D40 | low | WarehouseBuilder | Template originals are stored as world-space positions in 7 replicated attributes per part |
| D41 | low | AdminMoves | Admin fly uses deprecated BodyVelocity/BodyGyro; noclip scans character every physics step |
| D42 | low | CrewDirector | Legacy RunService events (Stepped/Heartbeat) instead of PreSimulation/PostSimulation |
| D43 | low | Effects | Magic numbers and inconsistent unit conversions across client modules |
| D44 | low | Ghosts | Dead code and unused locals across the slice |
| D45 | low | HUD | Dead code and unused locals across the slice |
| D46 | low | HUD | Carry limit 12 is hard-coded in both HUD and CarryService |
| D47 | low | Hatch | Hatch: item and pet rise animation is a verbatim duplicate block |
| D48 | low | Pedestrians | Dead code in slice |
| D49 | low | ScreensJobs | God functions in client UI and FX modules (Init functions of 250-546 lines) |
| D50 | low | ScreensJobs | Daily window shows no check marks after a full 7-day cycle; the computed `done` is never u |
| D51 | low | ScreensRoadcase | Duplicated UI helpers and roughly 76 hard-coded RichText colour literals outside Theme |
| D52 | low | ShowDirector | ShowDirector: local `dimmed` shadows the module-level `dimmed` table; a failure after `run |

## Details

### D01 · MEDIUM · maintainability — JobService is an 1,850-line god module (board, tenders, packing crew, robots, material, spedition, dispatch, public state)
`ServerScriptService.Server.JobService` ~Zeile 1 · Aufwand L
- **Problem:** Header L1-2 lists 8 responsibilities. Several functions are long: startJob L522-650 (130 lines), crewLoop L1270-1410 (140 lines), S.Spedition L1653-1732 (80 lines). PolishLog lists 'JobService-Aufteilung' under BEWUSST NICHT, so it is still open.
- **Auswirkung:** High regression risk for every change; hard to test pieces in isolation.
- **Fix (gegengeprüft):** Keep the same split, with three safeguards.

1. **Move shared state into one table.** crewLoop, robotLoop, startJob, the staging code and Spedition share module-level locals: per-player job and staging tables, reservation state, and helpers such as alive() and packingDone. Put this state in a single table, for example `local St = {}`, and pass it to every child module together with ctx. If each child module gets its own copy of a local, the state silently splits apart and Cancel, ForcePack and the Spedition fetch-claimed path break.

2. **Make it a pure move.** Keep `S.*` as thin re-exports so the ctx.Jobs API does not change. Keep the order of `S.Init` side effects exactly as it is now: building the yards, starting the tender loop and connecting events.

3. **Verify after each step.** Move one area per commit, starting with the code that has the fewest dependencies (Tenders, then Material/Spedition, then Packing). After each move, rerun the play tests listed in PolishLog L, K and T: gartenparty prep with the trainee (Azubi) and with the warehouse workers, AutoPack, Cancel during a rack run, Komplett-Service, and a full stadium (Stadion XL) job.

### D02 · MEDIUM · maintainability — CaseService and RoadcaseService duplicate the whole purchase/open pipeline (roll, open, reveal, policy, near-check, triple pass, broadcast)
`ServerScriptService.Server.RoadcaseService` ~Zeile 116 · Aufwand M
- **Problem:** Both modules define local roll(), open(), reveal() with the same structure (CaseService L14-52, RoadcaseService L48-89). Buy() repeats the same Near check (`ctx.Interact.Near(p, "Case_"..caseId, 90)` / `"Roadcase_"..caseId, 90`), the TripleHatch message, the `pol.ArePaidRandomItemsRestricted` block and the delayed broadcast string. The near radius 90 is a magic number in both, and the client copies it as 84 (ScreensRoadcase L116 `(maxDist or 84) -- ... (Server: 90)`). The copies have already diverged: Roadcase OpenOwned validates `RC.Cases[caseId]` (L155), Case OpenOwned (L96-98) does not, and Case open() calls ctx.OnCrewChanged once per opened case (3x for a triple).
- **Auswirkung:** Every rule change (policy text, radius, broadcast format, secret masking) has to be made twice, plus once in the client. The OnCrewChanged-per-case pattern repeats JSONEncode, CrewWork.Publish and UpdateTrail three times per triple open.
- **Fix (gegengeprüft):** 1. Create a shared helper module Server/LootCommon with these functions:
   - near(p, prefix, caseId)
   - policyBlocked(p) / policy message
   - tripleCheck(p, count)
   - announce(p, rarity, shownName, caseName, pctText, fast)
   - reveal(p, list, keyName)
   Keep the different message texts per service by passing them as parameters.

2. Add G.CaseBuyRadius = 90 to GameConfig. Use it in both services, and use `G.CaseBuyRadius - 6` in ScreensRoadcase L116.

3. In CaseService, delete `ctx.OnCrewChanged(p)` at L41. Add `if #list > 0 then ctx.OnCrewChanged(p) end` right before `reveal(p, list)` in BOTH K.Buy (before L89) and K.OpenOwned (before L115).

4. In CaseService.OpenOwned, add `if type(caseId) ~= "string" or not CR.Cases[caseId] then return false, "Unbekanntes Case." end` before L98.

5. In the CaseService open() broadcast check (L28), change the condition to `local info = CrewR.RarityInfo[rarity]; if info and info.Broadcast then`.

### D03 · MEDIUM · maintainability — Vehicle 'prop' code copy-pasted three times with diverging behaviour (door offset, ground placement, cleanup)
`StarterPlayer.StarterPlayerScripts.Client.Effects` ~Zeile 163 · Aufwand M
- **Problem:** spedTruck (L163-270) and spedPickup (L274-386) repeat the same blocks: descendant sanitising (L173-191 / L284-302), the `move()` lerp loop (L232-242 / L335-345), the reverse-beeper spawn (L245-251 / L347-353), the door lift loop (L254-262 / L356-363) and setAlpha. StaffTruck (L485-518) is a third variant. The copies already disagree. spedPickup lifts the pivot to the ground: `-- Modell-Pivot liegt nicht zwingend am Boden: Unterkante auf den Boden setzen ... local lift = m:GetPivot().Position.Y - (bcf.Position.Y - size.Y / 2)` (L313-316). spedTruck pivots straight onto `g.Y` (L214). StaffTruck uses `size.Y / 2 + 0.2` (L498). StaffTruck also keeps Seats and Sounds that the other two destroy or disable. The door bug above comes from exactly this divergence.
- **Auswirkung:** Bugs get fixed in one copy only, as the doorRel bug shows. By spedPickup's own comment, spedTruck can park sunk into the ground by the pivot-to-bottom offset. About 200 lines of near-duplicate code are maintained in a 664-line module.
- **Fix (gegengeprüft):** Extract local helpers in Effects:
- sanitize(m, color, name) returns parts. Pass options for the extra cleanup (destroy joints/sounds, disable seats) so StaffTruck keeps its current behaviour.
- moveProp(m, from, to, dur, parts, fadeFrom, fadeTo, easing).
- liftDoor(m, door, parkCF, doorRel, dur).
- reverseBeeps(m, pos).

In spedTruck, compute doorRel with m:GetPivot():ToObjectSpace(door.CFrame) right after cloning, before any PivotTo. Only adopt spedPickup's ground lift in spedTruck after checking the Truck_Titan40/Truck_Heavy18 pivots in Studio. Keep all timings, offsets and StaffTruck's easing unchanged.

### D04 · LOW · maintainability — Missing load-time consistency asserts in the registries (ByRarity overwrite, PassOrder coverage)
`ReplicatedStorage.Modules.CrewRegistry` ~Zeile 45 · Aufwand S
- **Problem:** for id, t in pairs(C.Types) do ... C.ByRarity[t.Rarity] = id ... end. CaseService L23 does `local typeId = CrewR.ByRarity[rarity]` and then ctx.Crew.Add(p, typeId). Adding a second pet with the same rarity would silently replace the first in pairs order, which is non-deterministic. GameConfig L65 G.PassOrder is a hand-maintained copy of the G.Passes keys with no check.
- **Fix (gegengeprüft):** `assert(not C.ByRarity[t.Rarity], 'CrewRegistry: doppelte Seltenheit ' .. t.Rarity)` before assigning. Also assert every C.Rarities entry has a type, and in GameConfig assert that #PassOrder equals the number of Passes keys and every entry exists. This mirrors the odds-sum asserts already used in Case/RoadcaseRegistry.

### D05 · LOW · dead-code — Unused exports and dead data across the registries
`ReplicatedStorage.Modules.GameConfig` ~Zeile 7 · Aufwand S
- **Problem:** Grep over all runtime files (excluding DevTools) finds no external use of: G.StartVehicle (DataService L21 hardcodes `Vehicles = { Van = true }, ActiveVehicle = "Van"`), G.RobuxToTokens, G.MaxCarryVisual, R.BestOfType, R.IsExclusive, R.CaseBase, R.RarityMult, R.ExclusiveModelRef, R.Qualities, R.QualityName, R.LEDWall.Module ("PixelForge_LEDModule" is not an item id), W.TenderNames, W.SystemOrder, RC.RegionOf, C.IsPets. In WorldConfig, the …
- **Fix (gegengeprüft):** Use G.StartVehicle in DataService.Template (`Vehicles = { [G.StartVehicle] = true }, ActiveVehicle = G.StartVehicle`) and delete the remaining unused exports. In small() and big(), place Follow slots with a placeholder X sign only, e.g. `CFrame.new(-1,0,0)`, or let fohFit create them.

### D06 · LOW · dead-code — G.Expansions is dead legacy config that contradicts WarehouseConfig (only .Name is still read)
`ReplicatedStorage.Modules.GameConfig` ~Zeile 33 · Aufwand S
- **Problem:** G.Expansions = { { Id = "HallExtension", ..., Desc = "Zweite Regalreihe öffnet sich: +80 Lagerplätze", Price = 25000, Level = 3, Storage = 80 }, ... { Id = "CrewLounge", ..., CrewSlots = 1 }, ... }
The only runtime reader is StaffService L82 (`for _, e in ipairs(G.Expansions) do if e.Id == def.Needs then ex = e end end`), which uses `ex.Name`. Storage comes from WarehouseConfig (ShopService L19 `G.BaseStorage + WCfg.Stat(d, "Storage")`; …
- **Fix (gegengeprüft):** Change only what is needed and leave the save flags alone. d.Expansions and its Ids must stay, because WC.Mirror/Migrate and the client use them. Replace the G.Expansions table with `G.ExpansionNames = { HallExtension = "Hallen-Erweiterung", SecondDock = "2. Laderampe", OutdoorStorage = "Außenlager", Dispatch = "Dispositions-Büro", CrewLounge = "Crew-Lounge", Branch = "Niederlassung Portavia" }`. Then change StaffService L81-83 to `return false, "Benötigt " .. (G.ExpansionNames[def.Needs] or def.Needs) .. "."`. Before removing the table, grep the edit-time ServerStorage.DevTools builders for G.Expansions.

### D07 · LOW · maintainability — Pass, staff and expansion effect numbers are duplicated as magic numbers in services and in Desc strings
`ReplicatedStorage.Modules.GameConfig` ~Zeile 59 · Aufwand M
- **Problem:** GameConfig only has text: `BigWarehouse = { Desc = "+150 Lagerplätze ..." }`, `TurboTruck = { Desc = "+30 % Tempo ..." }`, `DailyPlus = { Desc = "Doppelte tägliche Belohnungen." }`, `CrewSlots = { Desc = "Zwei zusätzliche Pets ..." }`, `VIP = { Desc = "... +1 Pet-Slot ..." }`. The values live in the services: ShopService L20 `cap += 150`, VehicleService L209 `HasPass(p, "TurboTruck") and 0.3`, RewardService L54 `HasPass(p, "DailyPlus") and 2`, …
- **Fix (gegengeprüft):** Add value fields to the pass entries (e.g. `BigWarehouse = { ..., Storage = 150 }`, `TurboTruck = { ..., SpeedMult = 0.3 }`, `DailyPlus = { ..., Mult = 2 }`, `CrewSlots = { ..., Slots = 2 }`, `VIP = { ..., Slots = 1, Cash = 0.25 }`). Read them in the services, and build the Desc strings with string.format from those fields and from G.Dispatch/G.Staff. Behaviour stays the same.

### D08 · LOW · maintainability — Region and level data are duplicated between ItemRegistry, RoadcaseRegistry and WorldConfig; ppb values are named 'ppm'
`ReplicatedStorage.Modules.ItemRegistry` ~Zeile 256 · Aufwand S
- **Problem:** R.RoadcaseWorlds = { N = { Region = "Neustadt", Cap = 7, Level = 1 }, P = { Region = "Portavia", ..., Level = 8 }, M = { ..., Level = 15 } } repeats W.Regions levels (WorldConfig L6-8). RoadcaseRegistry L23-27 RC.Regions repeats W.RegionOrder. RoadcaseRegistry L69-72 `local ppm = c.Odds[r] ... Ppm = ppm` holds parts-per-billion values (L2 "Chancen als Ganzzahlen pro Milliarde (ppb)"); ScreensShop L128 continues the misnomer.
- **Fix (gegengeprüft):** Same fix as proposed. The rename must also update the client consumer StarterPlayer.StarterPlayerScripts.Client.ScreensRoadcase L237 (`e.Ppm / Luck.Total`), and ScreensShop if it reads the field. The simplest option is to have WorldConfig.Regions take Level from R.RoadcaseWorlds, or to derive both from one table.

### D09 · LOW · dead-code — VehicleRegistry Titan40 has a dead TokenPrice that no server or UI path honours
`ReplicatedStorage.Modules.VehicleRegistry` ~Zeile 11 · Aufwand S
- **Problem:** Titan40 = { ..., Price = 900000, TokenPrice = 1200, ... }
ShopService.BuyVehicle (L102-111) only does `ctx.Economy.Spend(p, v.Price)`. A grep for TokenPrice shows no vehicle reader on server or client. This is the same issue Polish F7 fixed for R.LEDWall ("toter TokenPrice entfernt (BuyLED kennt nur Cash)").
- **Fix (gegengeprüft):** Remove `TokenPrice = 1200, ` from Titan40. Do not add token buying to BuyVehicle, because that would be a balancing change.

### D10 · LOW · maintainability — Large duplication between small() and big() stage layout builders
`ReplicatedStorage.Modules.WorldConfig` ~Zeile 52 · Aufwand M
- **Problem:** small() (L52-179) and big() (L236-391) repeat near-identical blocks: FOH Mixer/LightDesk at (-2.4/2.6, 0, -30), Follow spots, PA LineArray stacking `CFrame.new(sx*X, 2.12, Z) ... CFrame.new(sx*X, 3.1, Z) * CFrame.Angles(rad(-4),0,0)`, Outfill CompactArray pairs, hanging TrussLights/Spots/Blinders `CFrame.new(x, spanY - 0.02, tz) * CFrame.Angles(0,0,math.pi), { Hanging = true }`, and System/Gen for outdoor.
- **Fix (gegengeprüft):** Extract helpers, e.g. `foh(L)`, `paStack(L, x, z)`, `outfill(L, ox, oz)`, `hang(L, group, typ, phase, x, y, z)`, and call them from both builders with their size-specific coordinates. Output stays identical, which can be verified by diffing W.GetLayout results before and after for all 64 venue|size keys.

### D11 · LOW · maintainability — Shared registry tables are mutable; layout slots and job defs are shared by reference across all players
`ReplicatedStorage.Modules.WorldConfig` ~Zeile 428 · Aufwand S
- **Problem:** W.Layouts[key] = L; return L. The cached slot tables reach JobService.startJob as `Slots = slots` (L549-552 via J.Slots, which returns the cached slot tables) and `Def = job` (the W.Jobs entry). RoadcaseRegistry L53 shares one NORMAL1/NORMAL2/PREMIUM odds table between 3 cases each. Economy L26 comments "Rückgabe nur lesen, nicht verändern!", so read-only is enforced only by convention.
- **Fix (gegengeprüft):** Same idea, applied with care. Freeze only after every build step has run. In GetLayout, that means after the `s.Index = i` loop (and after fohFit), not before. For W.Jobs, freeze only after NormalizeJob, and only if no runtime code fills in defaults lazily. Before shipping, run a playtest that covers startJob, roadcase opening and tenders, because a frozen table raises an error on any write that grep missed. A safer first step is to freeze only in Studio (`if RunService:IsStudio() then table.freeze(...) end`), so stray writes show up there before you freeze in production.

### D12 · LOW · maintainability — Duplicate or diverging region logic with magic X thresholds
`ServerScriptService.Main` ~Zeile 49 · Aufwand S
- **Problem:** Main L51 `if pos.X > 4000 then return "Portavia" elseif pos.X < -4000 then return "Metropolis" end return "Neustadt"`, while ReplicatedStorage.Modules.NavGraph L123 `G.RegionAt(pos)` uses real road-network bounds. Countryside venues and the plaza scenes are all classified as 'Neustadt' on the server.
- **Fix (gegengeprüft):** In ctx.RegionAt, after the type check, call `local r = NavGraph.RegionAt(pos)` and return r if it is set. Otherwise keep the existing X-threshold rule as the fallback, which leaves current behavior unchanged for positions outside every region. Before switching, check that NavGraph.Regions() is populated on the server; if it is empty, every call falls back to the old rule anyway. Move 4000 into a GameConfig constant. A second, optional step is to remove the copy-pasted `hrp and ctx.RegionAt(...) or GetAttribute("Region")` fallback from all call sites.

### D13 · LOW · maintainability — Change-notification hooks duplicated with diverging side effects (OnCrewChanged / OnPassesChanged / Skill applied)
`ServerScriptService.Main` ~Zeile 105 · Aufwand S
- **Problem:** Main L106-118 ctx.OnCrewChanged: Invalidate, Push, Carry.UpdateSpeed, CrewWork.Publish, Crew.UpdateTrail, Pets attribute. Main L120-126 ctx.OnPassesChanged: Invalidate, Push, Carry.UpdateSpeed, Vehicles.UpdateStats, CrewWork.Publish (no UpdateTrail). SkillService L21-27 applied(): Invalidate, Carry.UpdateSpeed, Vehicles.UpdateStats, CrewWork.Publish, Push (no UpdateTrail). AdminService L791/L807 call Economy.Invalidate directly, and …
- **Fix (gegengeprüft):** Add `ctx.OnBonusesChanged(p)`. It should run `Economy.Invalidate`, `Carry.UpdateSpeed`, `pcall(Vehicles.UpdateStats)`, `pcall(CrewWork.Publish)` and `pcall(Crew.UpdateTrail)`, then call `ctx.Push`. Keep each side effect in its own pcall, as the existing hooks do, so one error does not block Push. `OnCrewChanged` should call it and then set the Pets attribute. `OnPassesChanged` and SkillService's `applied()` should simply call it. SkillService gets ctx at Init, so call `ctx.OnBonusesChanged` there when the function runs, not at module load.

### D14 · LOW · maintainability — No shared safe-loop helper: every server forever-loop hand-rolls (or forgets) its error isolation
`ServerScriptService.Main` ~Zeile 175 · Aufwand S
- **Problem:** Forever loops in runtime server code: Main L175 (State push, partially protected), Main L511 (ClockTime, unprotected but trivial), CrewWork L25 (unprotected), DataService L180 (autosave, safe because each save is task.spawn'd), JobService L241 (per-player pcall), L255 (pcall, error swallowed), L261 (unprotected), PlazaService L104 (SetAsync under pcall), StaffService L47 (per-player pcall), TradeService L133 and VehicleService L38 (already …
- **Fix (gegengeprüft):** Add one helper to ctx in Main, e.g. `function ctx.Every(name, interval, perPlayer) task.spawn(function() while true do task.wait(interval) for p, s in pairs(ctx.Sessions) do if p.Parent then local ok, err = pcall(perPlayer, p, s) if not ok then warn("[" .. name .. "] " .. tostring(err)) end end end end end) end`, plus a non-per-player variant `ctx.Loop(name, interval, fn)` that pcalls fn on each iteration. Then switch the CrewWork, Jobs-tick, Staff-tick and tender-cleanup loops over to it. Behaviour stays the same; only error isolation is unified.

### D15 · LOW · maintainability — Admin MAX_CREW = 300 contradicts G.CrewInventoryMax = 100
`ServerScriptService.Server.AdminService` ~Zeile 25 · Aufwand S
- **Problem:** local MAX_CREW = 300
...
local n = math.min(num(a.Count, 1, 25, 1), MAX_CREW - ctx.Crew.Count(t))
CaseService and TradeService enforce `G.CrewInventoryMax` (100).
- **Fix (gegengeprüft):** In AdminService, replace `local MAX_CREW = 300` with `local MAX_CREW = G.CrewInventoryMax`. If over-filling test accounts is deliberate, add a separate named config value instead.

### D16 · LOW · maintainability — Validate is used in 7 of 25 server modules; other handlers hand-roll checks or duplicate Validate
`ServerScriptService.Server.AdminService` ~Zeile 55 · Aufwand M
- **Problem:** AdminService L55-59 `local function num(v, lo, hi, def) v = tonumber(v) if not v or v ~= v or v == math.huge ...` re-implements Validate.clampInt (and also accepts numeric strings). TradeService L178/L201 use `tonumber(targetId) or 0`. CrewService/TradeService/StaffService use ad-hoc `type(uid) == "string"` (Trade adds `#uid > 16`). Main SetSetting L289-298 checks types by hand. Validate.str and V.tbl, written for exactly these cases, have no …
- **Fix (gegengeprüft):** Do the validation in the H.* adapters in Main using Validate.str, Validate.int and Validate.tbl. In AdminService, replace the body of `num` with `return Validate.clampInt(tonumber(v), lo, hi, def)`. Keep tonumber so admin inputs that arrive as numeric strings still work. Add the `type(uid)=="string"` and `#uid>16` checks to the adapters, but leave the existing checks inside the services as defense in depth.

### D17 · LOW · maintainability — AdminService duplicates helpers (ground raycast, numeric clamp) and re-requires modules inline
`ServerScriptService.Server.AdminService` ~Zeile 729 · Aufwand S
- **Problem:** C.TeleportXYZ L729-741 re-implements groundAt (L75-94) with a different origin and length. `num()` (L55-59) duplicates Validate.clampInt. `require(game:GetService("ReplicatedStorage").Modules.WarehouseConfig)` (L222, L798) and `require(RS.Modules.Luck)` (L228, L789) are required inline. C.Plaza uses `game:GetService("RunService")` although `RunService` is a local. LSP reports an unused `t` at L328.
- **Fix (gegengeprüft):** Change the signature to `groundAt(pos, up, len)`, with up defaulting to 40 and len to 160, and have it return nil when nothing is hit. Existing callers keep their behaviour with `groundAt(p) or p`. TeleportXYZ then does `local g = groundAt(Vector3.new(x,0,z), 1200, 1800); local gy = g and g.Y or 10; pos = Vector3.new(x, gy + 3.5, z)`. Move `local WCfg = require(RS.Modules.WarehouseConfig)` and `local Luck = require(RS.Modules.Luck)` to the top of the file. Replace `game:GetService("RunService")` at L339 with the local `RunService`. Only swap `num` for Validate.clampInt after checking that it has the same NaN/inf→default and floor semantics.

### D18 · LOW · maintainability — C.Staff mints cash to bypass the hire cost: cash can drift if HireCost and Hire disagree
`ServerScriptService.Server.AdminService` ~Zeile 779 · Aufwand S
- **Problem:** local cost = ctx.Staff.HireCost(t, role) or 0
d.Cash += cost
local ok, msg = ctx.Staff.Hire(t, role)
if not ok then d.Cash -= cost end
- **Fix (gegengeprüft):** In StaffService, change the signature to `S.Hire(p, role, opts)`. Replace the Spend line with: `if not (opts and opts.Free) and not ctx.Economy.Spend(p, cost) then return false, ... end`. When opts.Free is set, change the success message so it does not show '-$cost'. In AdminService C.Staff, remove the `d.Cash += cost` / `d.Cash -= cost` lines and call `return ctx.Staff.Hire(t, role, { Free = true })`. Make sure the client remote handler never forwards opts (check that it calls `S.Hire(p, role)` with exactly two arguments). Otherwise a client could hire for free.

### D19 · LOW · dead-code — Dead code / unused exports and imports in the slice
`ServerScriptService.Server.CrewService` ~Zeile 20 · Aufwand S
- **Problem:** Never referenced outside their file (grep over runtime code): CrewService.MigrateFound (L20-23, duplicates DataService.Load L111-113), StaffService S.Get (L28), PlotService P.RackStats (L315), P.Strip export (L341), WarehouseBuilder WB.BayCount (L249), WB.PLACES/LEVEL_H/FLOOR (L38-40), attributes WHFloors/WHAnnex (L737-738, never read), CrewWork C.Dims (L128). luau-lsp: PlotService unused imports G, U (L5-6), WarehouseBuilder unused ANNEX_X0 …
- **Fix (gegengeprüft):** Delete C.MigrateFound, WB.BayCount and the WHFloors/WHAnnex SetAttribute calls. Before deleting, grep ServerStorage.DevTools and the client code for each symbol. Keep P.RackStats only if a dev tool uses it, and mark it with a comment. Move the WarehouseConfig require to a module-level local. Only remove the RenderRacks call at PlotService L76 after checking that ApplyExpansions has no early return before L148 (for example when there is no profile or no model). If it can return early, keep L76 or move the call so it always runs; otherwise racks would not be rendered on claim.

### D20 · LOW · maintainability — Crew show/idle positions computed by duplicated server and client formulas with magic numbers
`ServerScriptService.Server.CrewWork` ~Zeile 352 · Aufwand S
- **Problem:** CrewWork L350-359 `-- Platz in den Bühnen-Wings ... (gleiche Formel wie im CrewDirector)` `return job.StageCF * Vector3.new(side * (15.5 + ((k - 1) % 2) * 1.8), 0, 1.5 + (k - 1) * 2.1)` is duplicated in Client.CrewDirector L380-383 (`-- gleiche Formel wie CrewWork.WingPos`). VenueIdle (L153-161, `(i - (n + 1) / 2) * 2.4`, `8 + math.ceil(i / 2) * 2.2`, threshold 160) is likewise mirrored by the CrewDirector Venue branch (L384-386, same 160 and …
- **Fix (gegengeprüft):** Move only the pure math, WingOffset(dims, i) and IdleSideOffset(dims, i), into a ReplicatedStorage module, and have it return local offsets that the caller multiplies by the stage CFrame. Keep each side's own fallback for dims (the client's `or 18` / StageDims("S")) so behaviour does not change. Move the 160 and 2.4 constants into the same module. Keep the client-only truck and cab-door logic in CrewDirector.

### D21 · LOW · maintainability — Profile migrations are spread across four places; Template.Version is unused; Crew.MigrateFound is dead code
`ServerScriptService.Server.DataService` ~Zeile 104 · Aufwand S
- **Problem:** Template L19 `Version = 1` is never read or bumped. Migrations live in D.Load L105-113 (Reconcile, then a Stats loop at L106 that Reconcile already covers because it recurses into non-empty dictionaries, sanitize, WCfg.Migrate, CrewFound loop), in newProfile L45, in Main L456 `pcall(ctx.Staff.Migrate, d)`, and in PlotService.ApplyExpansions L130 `WCfg.Migrate(d)`. CrewService L20-23 `C.MigrateFound` duplicates Load L112-113 and is never called …
- **Fix (gegengeprüft):** Add a `D.Migrate(d)` called from Load and newProfile that runs Reconcile, then the Stats backfill (keep it unless Reconcile is verified to recurse), then sanitize, WCfg.Migrate and the CrewFound loop. Keep the Staff.Migrate call in Main because it depends on ctx, but log the pcall error instead of dropping it. Delete C.MigrateFound. Use Template.Version for versioned steps only from now on.

### D22 · LOW · dead-code — Small dead code and redundancy in the data and validation layer
`ServerScriptService.Server.DataService` ~Zeile 106 · Aufwand S
- **Problem:** DataService L106 `for k, v in pairs(D.Template.Stats) do if result.Stats[k] == nil ...` duplicates U.Reconcile L59-60, which already recurses into non-empty dict templates such as Stats. L3 `local Players` is unused (luau-lsp LocalUnused). Template `Version = 1` (L19) is never read, so there is no versioned migration hook. Validate.num/str/tbl/oneOf/bool and SkillService `K.Applied` (L28) have no callers in the runtime code. The service list is …
- **Fix (gegengeprüft):** Delete DataService L106 and L3. Main: define one ordered list, e.g. `local SERVICES = {{"Economy","Economy"},{"Shop","ShopService"},...}`, require into ctx from it and call Init by looping over the same list. Keep Data required first, because it has no Init in that list. Keep the unused Validate helpers: they are the intended API for validating remote input and cost nothing. Removing them gains little. Keep `Version` in the template so existing saves stay compatible. Instead, add a small `if (result.Version or 1) < CURRENT then migrate end` step after Reconcile, or leave it as is. Do not delete the field.

### D23 · LOW · dead-code — Dead code: unused locals/exports in the jobs slice
`ServerScriptService.Server.JobService` ~Zeile 6 · Aufwand S
- **Problem:** JobService L6 `local TweenService = ...` is unused (LSP LocalUnused). `S.JobDef` (L34-36), `S.IsNight` (L340), and `S.DefSummary` (L474) have no callers outside the module (grep). JobLogic `J.MaxPhase` (L47-51) and `J.Preview` (L169-179) have no callers anywhere. TenderGen `VENUE_SCALE` (L69-70) is unused (LSP LocalUnused); material now comes from W.MaterialFor.
- **Fix (gegengeprüft):** Delete the unused TweenService local and VENUE_SCALE. Before removing the exported functions (S.JobDef/IsNight/DefSummary, J.MaxPhase/Preview), grep ServerStorage.DevTools too, because edit-time builder scripts may still use them. Otherwise keep them and add a comment marking them as public API.

### D24 · LOW · maintainability — Server re-implements shared Util helpers: fmtT == U.Tons, S.MatNeed/MatMissing == U.MatMissing
`ServerScriptService.Server.JobService` ~Zeile 26 · Aufwand S
- **Problem:** JobService L26-31 `local function fmtT(kg) ... if kg >= 9950 then return U.Comma(math.floor(kg / 1000 + 0.5)) .. " t" end ...` is byte-identical to Util L31-36 `function U.Tons(kg)`. JobService L917-927 `S.MatNeed`/`S.MatMissing` re-implements Util L39-45 `U.MatMissing`, whose comment says "gleiche Formel wie der Server". The two already differ: the server uses `m.Total <= 0`, the client uses `(m.Total or 0) <= 0`. Client.Ghosts L152 and HUD …
- **Fix (gegengeprüft):** In JobService, replace the local fmtT body with `local fmtT = U.Tons` and keep `S.FmtT = fmtT`, because about 15 call sites in the file use the local name. Replace S.MatNeed and S.MatMissing with `S.MatMissing = U.MatMissing`. MatNeed has no other users, so it can simply be deleted. Optionally, move the need calculation into Util as U.MatNeed and have U.MatMissing call it. Behaviour does not change, and the Util version is slightly more nil-safe.

### D25 · LOW · maintainability — Token-to-cash rate is still hardcoded as 100 in JobService.rentPrice (Polish F7 incomplete)
`ServerScriptService.Server.JobService` ~Zeile 110 · Aufwand S
- **Problem:** local base = it.Price > 0 and it.Price or (it.TokenPrice or 0) * 100
GameConfig L19 introduced `G.TokenCashValue = 100 -- [Polish F7] ... (war in ShopService hartkodiert)`, and ShopService L73 uses it, but rentPrice was missed.
- **Fix (gegengeprüft):** Replace `* 100` with `* G.TokenCashValue` (G is already required in JobService).

### D26 · LOW · maintainability — Magic numbers scattered through job logic (rent, distances, timings)
`ServerScriptService.Server.JobService` ~Zeile 111 · Aufwand M
- **Problem:** rentPrice `math.max(50, math.floor(base * 0.1 / 10) * 10)` (L111), LED rent `2000 * (job.LED or 4)` (L419), TruckAtDepot `< 45` (L278), inBox `h.Y + 6` (L104), auto-load `DepotTicks >= 3` (L298), Express warning `< 60` (L328), `room < 50` (L999), `S.MatFree(m) >= 2000` opens the Spedition UI (L1062), spedDockCF `CFrame.new(10, 0, 60.7 - 25)` (L1604), `ROBOT_SPEED = 24`, `corrZ = 100.3` (L1414, L1441). TenderGen `T.TierFor` hardcodes 17/10/5/3 …
- **Fix (gegengeprüft):** Change T.TierFor to read from TIER_MIN_LEVEL: `for t = #TIER_MIN_LEVEL, 1, -1 do if level >= TIER_MIN_LEVEL[t] then return t end end return 1`. This gives the same results as now. Moving the JobService magic numbers into a GameConfig section is optional cleanup and should keep the current values exactly.

### D27 · LOW · maintainability — Tender spawn errors are silently swallowed
`ServerScriptService.Server.JobService` ~Zeile 256 · Aufwand S
- **Problem:** `pcall(S.SpawnTender)` discards the error, unlike the Tick loop, which warns (L246-247).
- **Fix (gegengeprüft):** `local ok, err = pcall(S.SpawnTender) if not ok then warn("[Jobs] Tender: " .. tostring(err)) end`.

### D28 · LOW · maintainability — Night-time thresholds hardcoded in four modules, and the gameplay gate depends on them
`ServerScriptService.Server.JobService` ~Zeile 338 · Aufwand S
- **Problem:** JobService L336-339 `return ct >= 19.2 or ct < 6.3` (gates NightOnly venues L351, message "19–6 Uhr"), Client.Ambient L240 `ct >= 19.2 or ct < 6.3`, Client.Navigator L23 `(ct >= 19.2 or ct < 6.3)`, while Client.Traffic L250-252 uses `ct < 6.6 or ct > 18.4`. The JobService comment says "Nacht wie Client.Ambient", so the copies are meant to stay in sync by hand.
- **Fix (gegengeprüft):** Add `G.Night = { From = 19.2, To = 6.3 }` and `function G.IsNight(ct) return ct >= G.Night.From or ct < G.Night.To end` to GameConfig, and use it in JobService, Ambient and Navigator. Keep Traffic's earlier headlight window as an explicit `G.Night.LightsFrom/LightsTo` if that difference is intended.

### D29 · LOW · maintainability — Owner-only ProximityPrompts copy-pasted 8 times and shown to every player
`ServerScriptService.Server.JobService` ~Zeile 856 · Aufwand M
- **Problem:** The same 7-line block (Instance.new("ProximityPrompt"), ActionText, ObjectText, KeyboardKeyCode, MaxActivationDistance, RequiresLineOfSight=false, Style=Custom, Triggered + `if plr ~= p then return end`) appears at JobService L856 (staging "Aufnehmen"), L948 ("Material verladen"), L1585 (pallet "Ausladen"), PlacementService L441 ("SHOW STARTEN"), PlotService L470 (rack), VehicleService L139/L184 and InteractService L100. These prompts are …
- **Fix (gegengeprüft):** Add a helper, for example `ctx.OwnerPrompt(parent, owner, opts, onTrigger)`. It should:
- create the prompt and apply the `opts` fields as given (ActionText, ObjectText, KeyboardKeyCode defaulting to E, HoldDuration, MaxActivationDistance, Name, attributes);
- set `RequiresLineOfSight = false` and `Style = Custom`;
- call `pr:SetAttribute("OwnerId", owner.UserId)`;
- connect `Triggered` as `function(plr) if plr == owner then onTrigger(plr) elseif opts.OnForeign then opts.OnForeign(plr) end end`.

Keep each call site's current HoldDuration, distance and extra conditions exactly as they are:
- The pallet prompt keeps no HoldDuration and keeps its `s.Job == job and job.Phase == "Building"` check inside `onTrigger`.
- The VehicleService "Einsteigen" prompt passes `OnForeign` so the "Das ist nicht dein LKW." notification stays.
- Leave InteractService.Attach alone. It is not owner-gated.

On …

### D30 · LOW · maintainability — crewLoop fetch branch and robotLoop duplicate about 50 lines of route/claim/drop logic
`ServerScriptService.Server.JobService` ~Zeile 1285 · Aufwand M
- **Problem:** crewLoop L1284-1336 and robotLoop L1462-1512 repeat the same steps: `fetchBatch`, `ctx.Plots.RackPath`, `x.Spot = x.Spot or allocSpot(job)`, the `if not rp or not scf then ... x.InRack = nil ... S.SpawnStaging` fallback, the claim loop, `SpotApproach`, `ToCorridor` + `rp.Via` + `rp.Stand`, the reversed Via list, wait, unclaim, `if table.find(job.Staging, x) then x.InRack = nil`, SpawnStaging/FireRegion/RefreshRackPrompts/Push. `alive()` is also …
- **Fix (gegengeprüft):** Extract three small module-level helpers next to fetchBatch/spotCF. Keep the animation and leg construction in each loop, because that is where the real differences are (bend vs lift, walk/push vs drive, CW.Send vs RobotTask).
1) `local function isAlive(p, s, job) return p.Parent ~= nil and ctx.Sessions[p] == s and s.Job == job and job.Phase == "Packing" end`. Replace both `alive()` closures with it.
2) `local function claimBatch(p, job, batch)`. It allocates the spots, gets rp/scf, and on a missing rp or scf runs the existing fallback (InRack=nil, SpawnStaging, Push) and returns nil. Otherwise it sets Claimed, collects ids, calls RefreshRackPrompts, and returns `rp, scf, ids`.
3) `local function routeFor(p, pos, rp, scf)`. It returns `toRack, back, dropStand`, built with ToCorridor + Via + Stand and with reversed Via + dropCorr + dropStand.
4) `local function finishBatch(p, job, batch, …

### D31 · LOW · maintainability — Build-phase advance uses a hard-coded upper bound 6 although the job carries MaxPhase
`ServerScriptService.Server.PlacementService` ~Zeile 172 · Aufwand S
- **Problem:** L172 `while unplacedOfPhase(job, job.BuildPhase) == 0 and job.BuildPhase < 6 do job.BuildPhase += 1 end`; PHASE_NAMES has 4 entries (L10); startJob stores `MaxPhase = maxPhase` (JobService L597). Each iteration rescans all slots (O(phases*slots) per Put).
- **Fix (gegengeprüft):** Change the loop bound to `job.BuildPhase < (job.MaxPhase or 6)` (keep 6 as the fallback for older jobs). Do not use #PHASE_NAMES as the fallback: it is 4, which would change behaviour if any layout has phase 5 or 6.

### D32 · LOW · dead-code — Dead branch in AutoTruss: the worker list never contains 'Crew_MasterRigger'
`ServerScriptService.Server.PlacementService` ~Zeile 394 · Aufwand S
- **Problem:** L394 `local model = table.find(workers, "Crew_MasterRigger") and "Helper_3" or "Crew_MasterRigger"`. CrewWork.Workers only returns `G.Staff.Roles.Warehouse.Model` ("Crew_WarehouseWorker") and "Helper_N" strings. The string 'Crew_MasterRigger' appears nowhere else in runtime code (it dates from when pets were workers).
- **Fix (gegengeprüft):** local model = "Crew_MasterRigger"

### D33 · LOW · dead-code — Dead runtime code: RoadcaseService.RefreshSigns targets a folder that no longer exists, plus unused exports
`ServerScriptService.Server.RoadcaseService` ~Zeile 15 · Aufwand S
- **Problem:** K.RefreshSigns scans `workspace.World:FindFirstChild("RoadcaseStations")` and still runs on every boot via `task.defer(function() pcall(K.RefreshSigns) end)` (L44). In the place file Workspace.World has no RoadcaseStations (children: Ground, Roads, Plots, Props, Hub, Trading, Regions, SpawnLocation, Venues, City, Industrie, Nature, LandTracks, CaseScenes); DevTools.CaseScenes L537-538 moved it to Backups as RoadcaseStations_preO. Exported but …
- **Fix (gegengeprüft):** Delete RefreshSigns and its Init defer, C.MigrateFound (or call it from DataService instead of the inline copy), DataService L106, and the listed unused exports. Keep the Validate helpers but start using them (see the Validate finding).

### D34 · LOW · maintainability — Lead-training level requirement `10 + Tier * 2` hardcoded on server and client
`ServerScriptService.Server.StaffService` ~Zeile 123 · Aufwand S
- **Problem:** StaffService L123 `if d.Level < 10 + h.Tier * 2 then return false, "Fortbildung auf Tier " .. (h.Tier + 1) .. " ab Level " .. (10 + h.Tier * 2)` and Client.ScreensJobs L659 `local needLvl = 10 + (h.Tier or 1) * 2`. Every other staff number lives in G.Staff (LeadTrain costs L154).
- **Fix (gegengeprüft):** Add `function G.Staff.LeadTrainLevel(tier) return 10 + tier * 2 end` to GameConfig. On the server, call it with `h.Tier`. On the client, call it with `(h.Tier or 1)` so the existing nil fallback is kept.

### D35 · LOW · maintainability — Duplicated magic numbers and divergent rent formulas across slice
`ServerScriptService.Server.StaffService` ~Zeile 198 · Aufwand S
- **Problem:** StaffService.Preview: `if t == "LEDWall" then rent += 2000 * (job.LED or 4) * n else rent += math.floor((R.Items[rep] and R.Items[rep].Price or 2000) * 0.08) * n end`. JobService.Quote (L418-421) copies the LED formula but uses `rentPrice` (L107-112: 10 %, min 50, token fallback). Branch discount `freight * 0.5` (StaffService L206) is duplicated in JobService L1692. The big-item threshold `(it.Weight or 0) >= 60 or (it.Volume or 0) >= 1.2` is in …
- **Fix (gegengeprüft):** Keep two separate named functions so the result stays the same: JobLogic.ManualRentPrice(id) for 10%/min 50 and JobLogic.AutoRentPrice(id) for 8%/fallback 2000, plus a shared JobLogic.LEDRent(job, n). Do not merge them into one formula without the owner's sign-off. Point WB.PLACES at WCfg.PLACES_PER_BAY and C.MINWORKERS at G.Staff.Azubis.

### D36 · LOW · maintainability — TenderGen conditions(): second chance() roll triggers a DuplicateCondition lint; intent unclear
`ServerScriptService.Server.TenderGen` ~Zeile 227 · Aufwand S
- **Problem:** `if chance(0.25) then ... Sponsor ... elseif chance(0.25) then ... Press ...`. luau-lsp reports 'DuplicateCondition: Condition has already been checked on line 224'. Because chance() rolls the RNG, Press actually happens with 0.75 x 0.25 = 18.75 %.
- **Fix (gegengeprüft):** Behaviour-preserving rewrite: `local r2 = rng:NextNumber() if r2 < 0.25 then <Sponsor> elseif r2 < 0.4375 then <Press> end`, with a comment on the 18.75 %.

### D37 · LOW · dead-code — Dead code and unused locals in the slice
`ServerScriptService.Server.TradeService` ~Zeile 7 · Aufwand S
- **Problem:** TradeService: `local CrewR = require(RS.Modules.CrewRegistry)` is never used (LSP ImportUnused). `dA.LastTrade` is written and never read. Local count() (L90-94) and the Partners pet counter (L230-235) duplicate ctx.Crew.Count. RoadcaseService.RefreshSigns: `for id, cs in pairs(RC.Cases)` leaves `id` unused, and `require(RS.Modules.Util)` runs inside the per-sign loop (L32).
- **Fix (gegengeprüft):** Remove the unused CrewR require (L7). Hoist `local Util = require(RS.Modules.Util)` to the top of RoadcaseService and rename the unused loop variable to `_`. Only swap the local count() for ctx.Crew.Count after checking that it counts the same data table, because ctx.Crew.Count may take a player rather than a data table. The LastTrade field can stay as it is, since it does not break save compatibility. Or stop writing it.

### D38 · LOW · dead-code — Minor dead or redundant code in the slice
`ServerScriptService.Server.VehicleService` ~Zeile 121 · Aufwand S
- **Problem:** VehicleService.Spawn sets `s.Truck = m` twice (L121 and L135). `homeCF(p, def, model)` never uses `def` (L99). InteractService.Attach takes an unused `owner` parameter (L95) and calls `require(...RoadcaseRegistry)` / `require(...CaseRegistry)` on every call (L103/L105). PlotService calls `ctx.Interact.Scan(m, p)` but Scan takes one argument (L124). PlacementService.slotOf (L14-18) does a linear scan although CrewWork.SlotMap caches …
- **Fix (gegengeprüft):** Remove the duplicate assignment and unused parameters, hoist the requires to module scope, use `ctx.CrewWork.SlotMap(job)[idx]` in slotOf, fix the comment, and cache `local kg, max = C.Kg(p), C.MaxKg(p)` in CanTake.

### D39 · LOW · maintainability — Duplicated ProximityPrompt and grid code plus scattered magic numbers in the vehicle and build services
`ServerScriptService.Server.VehicleService` ~Zeile 139 · Aufwand M
- **Problem:** Prompt boilerplate is repeated in VehicleService L139-147 and L184-192, PlacementService.Ready L441-451, InteractService.Attach L100-114 and JobService.SpawnStaging. The grid maths is copied in renderCargoNow L334-344 vs L377-387. Tuning constants are inline: VehicleService 140 / 1.8 / 30 / 1.25 (L64-65), -60 (L55), 6 s (L30), 45 s / 150 studs (L418), 20 s (L233), 0.9 s (L425). CarryService 12 items (L44) and walk cap 40 (L105). Placement 24 …
- **Fix (gegengeprüft):** Do this in small steps. The PolishLog skipped it because there are no regression tests, so each step must keep every value exactly the same. Add a makePrompt helper that also takes Style and RequiresLineOfSight, since both prompts set Style=Custom and RequiresLineOfSight=false. Keep the anti-cheat speed tolerances in one G.Vehicle.AntiCheat table in GameConfig.

### D40 · LOW · maintainability — Template originals are stored as world-space positions in 7 replicated attributes per part
`ServerScriptService.Server.WarehouseBuilder` ~Zeile 339 · Aufwand S
- **Problem:** `d:SetAttribute("OX", d.Position.X) d:SetAttribute("OY", d.Position.Y) ...` and restore does `d.Position = V3(d:GetAttribute("OX"), ...)`. Absolute world coordinates are restored even though everything else in the builder is pivot-relative.
- **Fix (gegengeprüft):** Keep the originals on the server in a weak-keyed table: `local originals = setmetatable({}, {__mode="k"})`. When remembering, store the part's pivot-relative CFrame (`model:GetPivot():ToObjectSpace(d.CFrame)`) along with Size.Y, Transparency, CanCollide and CanQuery. When restoring, set `d.CFrame = model:GetPivot() * o.rel` (pass the model through remember/restore).

Two cautions for save and migration compatibility. First, if any part already has OX attributes (for example in the saved place file), use them once to seed the table so the current behaviour is kept. Second, after a server restart the in-memory table is empty, so it captures the template again from its pristine state, which is correct because Build runs on fresh templates.

### D41 · LOW · deprecated-api — Admin fly uses deprecated BodyVelocity/BodyGyro; noclip scans character every physics step
`StarterPlayer.StarterPlayerScripts.Client.AdminMoves` ~Zeile 40 · Aufwand S
- **Problem:** `bv = Instance.new("BodyVelocity")` (L40), `bg = Instance.new("BodyGyro")` (L46). Noclip: `RunService.Stepped:Connect(function() ... for _, d in ipairs(ch:GetDescendants()) do if d:IsA("BasePart") and d.CanCollide then d.CanCollide = false end end end)` (L89).
- **Fix (gegengeprüft):** Replace BodyVelocity/BodyGyro with an Attachment on the HumanoidRootPart (HRP), plus LinearVelocity (VelocityConstraintMode=Vector, RelativeTo=World, MaxForce=1e6) and AlignOrientation (Mode=OneAttachment, CFrame=lookAt). Destroy all three in stopFly. In apply(), only call startFly() when fly is not already active (check flyConn == nil), so a change to the noclip attribute does not restart fly. For noclip, save each BasePart's original CanCollide value when noclip is turned on and restore those values when it is turned off, instead of forcing true. Optionally keep a cached list of the character's parts and update it with DescendantAdded instead of calling GetDescendants every frame.

### D42 · LOW · deprecated-api — Legacy RunService events (Stepped/Heartbeat) instead of PreSimulation/PostSimulation
`StarterPlayer.StarterPlayerScripts.Client.CrewDirector` ~Zeile 778 · Aufwand S
- **Problem:** `RunService.Stepped:Connect(function() pcall(carryPose) end)` and `RunService.Heartbeat:Connect(...)` (also Traffic L870, Pedestrians L376, Robots L199, Pets L144, Ambient L225). Roblox now documents PreSimulation/PostSimulation (and PreRender for visual-only updates) as the replacements.
- **Fix (gegengeprüft):** Change RunService.Stepped to RunService.PreSimulation at L778. This is the right place for Motor6D.Transform pose overrides, and the callback arguments differ but are unused here. Heartbeat can stay, or be renamed to PostSimulation for consistency. Do not move gameplay or physics logic to PreRender. Only consider PreRender for purely visual, camera-relative updates.

### D43 · LOW · maintainability — Magic numbers and inconsistent unit conversions across client modules
`StarterPlayer.StarterPlayerScripts.Client.Effects` ~Zeile 631 · Aufwand S
- **Problem:** Studs→metres uses `3.57` three times in Effects (L631, L633, L635). The speedometer uses `math.floor(math.abs(speed) * 1.6)` as km/h (Truck L166), which does not match 3.57 studs/m (that would be ×1.008). Other unexplained literals: visibility radii 700 (Effects L167, ShowDirector L102), 600 (Effects L278), 260 (ShowDirector L18/182), 120 (Effects L581); Terminals refreshes at `NEAR + 60` (Terminals L100) although the header says 60 studs; …
- **Fix (gegengeprüft):** Add `STUDS_PER_METER = 3.57`, `KMH_PER_STUD_S = 1.6` (keeping the current display), `FX_NEAR = 700` and similar constants to WorldConfig or a GameConfig module, and reference them. Values stay unchanged, so behaviour is preserved.

### D44 · LOW · dead-code — Dead code and unused locals across the slice
`StarterPlayer.StarterPlayerScripts.Client.Ghosts` ~Zeile 5 · Aufwand S
- **Problem:** Ghosts: unused `TweenService` (L5), `RunService` (L6) and `player` (L17). Prompts: unused `UIS` (L3) and `stroke` (L33). Effects: unused `wingL`/`wingR` (L48-49), `stats` (L116) and `btn` (L127). ShowDirector: unused `T` (L50), `tilt` local in collect (L60) and `pulse` (L282). Navigator: `targetName` is written but never read (L34, L270). Hatch exposes the debug hook `H._play = play` (L589). The luau-lsp LocalUnused hints confirm these.
- **Fix (gegengeprüft):** Delete the unused locals and services; keep the expressions only where they have side effects (for example `arrowPart(...)` calls without assigning the result). Remove `H._play` or guard it with `RunService:IsStudio()`.

### D45 · LOW · dead-code — Dead code and unused locals across the slice
`StarterPlayer.StarterPlayerScripts.Client.HUD` ~Zeile 4 · Aufwand S
- **Problem:** From the LSP and manual reading. HUD: `Players` (L4), `xpBar` (L92), `ic` (L112), `prog` (L182), `b2api` (L186), `carryBar` (L206), `tenAll` (L262). UI: `Players` (L3), `local t = UI.Text(...)` in Toast (L415), `UI.Rivets` no-op (L47), `UI.Tape` unused after Polish R. ScreensCrew: `CASE_COLORS` (L14), `b` (L278). Sounds: `local cache = {}` (L36). ScreensAdmin: `State` (L16), and `local list` shadowed twice in BUILD.Jobs (L434/L444). Theme: …
- **Fix (gegengeprüft):** Remove the unused locals, rename the second `list` to `jobs`, and drop UI.Rivets/Tape once all call sites are gone.

### D46 · LOW · maintainability — Carry limit 12 is hard-coded in both HUD and CarryService
`StarterPlayer.StarterPlayerScripts.Client.HUD` ~Zeile 331 · Aufwand S
- **Problem:** HUD: `carryText.Text = string.format("📦 %d / 12 Teile auf dem Arm", n)`. Server CarryService L44: `if #list >= 12 then return false, "Mehr passt nicht in deine Arme." end`. Other UI numbers are duplicated the same way: the Spedition price formula `math.ceil(kg / 1000) * sp.PerTon`, `depotFree >= 2000` and `disc and math.floor(c2 * 0.5)` (ScreensJobs L512-519), and Daily `UDim2.new(1 / 7, -7, ...)` (L590).
- **Fix (gegengeprüft):** Add `G.MaxCarryItems = 12` to ReplicatedStorage.Modules.GameConfig. Use it in CarryService L44 (`#list >= G.MaxCarryItems`) and in HUD L331 (format it with `%d` instead of the hard-coded 12). Do not reuse `G.MaxCarryVisual`, because it is set to 6.

### D47 · LOW · maintainability — Hatch: item and pet rise animation is a verbatim duplicate block
`StarterPlayer.StarterPlayerScripts.Client.Hatch` ~Zeile 437 · Aufwand S
- **Problem:** L411-428 (`local m, off = itemProp(c.Res.Item, info.Color) if m then local P = c.Base.Position + V3(0, ITEM_Y, 0) local pr = {...} m:PivotTo(...) ... tweenNumber(0, 1, riseT, ...) task.delay(riseT + 0.05, ...) table.insert(props, pr) end`) is repeated line for line at L435-452 for pets, differing only in the itemProp arguments. play() is a ~320-line god function (L234-556).
- **Fix (gegengeprüft):** Add a local helper riseProp(m, off, base, i) that builds the pr table, does the initial PivotTo, sets m.Parent = stage, runs tweenNumber and task.delay, and inserts pr into props. It closes over stage, fast and props. Then call it as `local m, off = itemProp(...); if m then riseProp(m, off, c.Base.Position, i) end` in both branches. Splitting play() into smaller helpers is optional and should be a separate refactor.

### D48 · LOW · dead-code — Dead code in slice
`StarterPlayer.StarterPlayerScripts.Client.Pedestrians` ~Zeile 56 · Aufwand S
- **Problem:** Pedestrians L56-82: COATS, PANTS, SKIN, HAIR, HATS, BAGS and `newPart` are unused (left over from the pre-R15 peds; luau-lsp LocalUnused/FunctionUnused). `f.Scale` is always 1. Traffic: `local player` (L11), `turnSpeed` (L385-388) and the `flat` parameter of `speedLimit` are unused. Ambient: `WARM` (L6) is unused and the `A.UpdateGrade` export is never called. Crowd L96: `local parts` is unused. RigAnim: `RA.RootCF`, `RA.Reset` and `RA.CarryCF` …
- **Fix (gegengeprüft):** Delete the unused locals and functions. Keep the debug exports only if DevTools use them.

### D49 · LOW · maintainability — God functions in client UI and FX modules (Init functions of 250-546 lines)
`StarterPlayer.StarterPlayerScripts.Client.ScreensJobs` ~Zeile 243 · Aufwand L
- **Problem:** Top-level function lengths: ScreensJobs S.Init 546 lines (L243), HUD.Init 422 (L50), ScreensShop S.Init 322 (L20), Hatch play() 322 (L234), ScreensRoadcase S.Init 302 (L159), ScreensCrew S.Init 297 (L39), ShowDirector SD.Play 287 (L97), Effects E.Init 257 (L405). On the server JobService is 1853 lines with ~70 functions. Only Validate has --!strict. Strict typing would have flagged the two real bugs above (InteractService L85 unbalanced …
- **Fix (gegengeprüft):** Split each S.Init into per-tab builders (e.g. ScreensJobs: buildBoard, buildTenders, buildDispatch, buildStaff, registered via UI.Register). Enable --!strict first in the small pure modules (Util, GameConfig, JobLogic, Luck, SkillTree, CaseRegistry) and then in the leaf services (Economy, SkillService, RewardService).

### D50 · LOW · dead-code — Daily window shows no check marks after a full 7-day cycle; the computed `done` is never used
`StarterPlayer.StarterPlayerScripts.Client.ScreensJobs` ~Zeile 588 · Aufwand S
- **Problem:** `local nextDay = (streak % #G.Daily) + 1 ... local done = i < nextDay or (not ready and i == ((streak - 1) % #G.Daily) + 1)`. `done` is never read (LSP LocalUnused). The ✓ is drawn with `if i < nextDay and not isNext then`. After claiming day 7 (streak 7, ready false), nextDay = 1, so no day gets a ✓.
- **Fix (gegengeprüft):** Treat a just-finished cycle as all done: `local cycleDone = (not ready) and streak > 0 and streak % #G.Daily == 0` and `local done = cycleDone or i < nextDay`. Then draw the check mark with `if done and not isNext then UI.Text(f, "✓", ...) end`.

### D51 · LOW · maintainability — Duplicated UI helpers and roughly 76 hard-coded RichText colour literals outside Theme
`StarterPlayer.StarterPlayerScripts.Client.ScreensRoadcase` ~Zeile 256 · Aufwand M
- **Problem:** `local function rowBtn(order, text, style, fn1, fn3, enabled)` appears almost verbatim in ScreensRoadcase L256 and ScreensCrew L163. The decimal formatter `string.format("%.2f", x):gsub("0+$", ""):gsub("%.$", ""):gsub("%.", ",")` appears in ScreensRoadcase L33 and ScreensShop L310. The two-click 'armed' confirm appears in ScreensAdmin L120-140 and ScreensSkills L57-69. Wrap-row builders appear in ScreensJobs L46 and ScreensAdmin L102. The …
- **Fix (gegengeprüft):** Move rowBtn, the decimal formatter, the armed confirm button and the wrap row into Client.UI (UI.ButtonRow, UI.FormatDec, UI.ConfirmButton, UI.WrapRow). Add `T.Hex = { Sub = "#969EAC", Warn = "#E08A00", Good = "#1FA45A", ... }` and `T.Ink` to Theme and replace the literals.

### D52 · LOW · maintainability — ShowDirector: local `dimmed` shadows the module-level `dimmed` table; a failure after `running[key] = true` blocks that stage and leaves house lights dimmed
`StarterPlayer.StarterPlayerScripts.Client.ShowDirector` ~Zeile 180 · Aufwand S
- **Problem:** Module level: `local dimmed = {}` (L14, used by dimHouse/restoreHouse). Inside SD.Play: `local dimmed = false` (L180). `running[key] = true` (L106) and `dimHouse(...)` (L108) run before the laser/LED setup and the connect. Nothing between there and `conn = RunService.RenderStepped:Connect` (L235) is protected, and the RenderStepped body and finish() have no pcall.
- **Fix (gegengeprüft):** Rename the inner variable to `exposureDimmed`. Make finish() idempotent with a `done` flag. Put everything after `running[key] = true` inside `local ok, err = xpcall(setup, debug.traceback)`, and on failure call finish(). Inside RenderStepped, wrap only the per-frame body (not the time and folder checks) in pcall, and call finish() on error. Also wrap finish's own body in pcall so that `running[key] = nil` and restoreHouse(houseList) always run.
