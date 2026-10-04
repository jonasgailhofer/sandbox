# Befundliste Stufe A: Sicherheit & Daten (Exploits, Datenverlust, Käufe, Races mit Daten)

Quelle: Multi-Agent-Code-Audit von `Place1backup1_klein.rbxl` (Stand 04.10.2026). Jeder Befund wurde von mindestens einem unabhängigen Prüfer im Code gegengeprüft, kritische und hohe Befunde von zwei Prüfern.
- **Zeilennummern** beziehen sich auf diesen Stand. Suche im aktuellen Code nach dem zitierten Snippet, nicht nach der Zeilennummer.
- **Fix (gegengeprüft)** ist der vom Prüfer korrigierte Fix. Er hat Vorrang vor dem ursprünglichen Vorschlag.
- Die Befundtexte sind auf Englisch, die IDs (A01 …) dienen dem Status-Tracking in `ServerStorage.DevTools.PolishLog` (Block Z).

## Übersicht

| ID | Schwere | Datei | Titel |
|---|---|---|---|
| A01 | critical | ShopService | Rename: quadratic gsub on unbounded client string freezes the whole server (Validate.str e |
| A02 | high | WorldConfig | Tours can be started at a level below their later stops, and venues for later stops are ne |
| A03 | high | JobService | Job arrival and material logic read the raw truck position every 0.5 s, before the 1 s wat |
| A04 | high | JobService | GetBoard is an O(jobs x inventory-units x log) CPU hog that one player can spam (~8/s) |
| A05 | high | UI | Silhouette viewport assigns a Font datatype to TextLabel.Font, so it errors for every non- |
| A06 | medium | Main | Join pipeline yields after the profile is live (Monetization.Join): a leave in that window |
| A07 | medium | CaseService | Owned loot cases from the Robux VIP pass open without the ArePaidRandomItemsRestricted pol |
| A08 | medium | DataService | Lock wait gives up after about 50 s although a lock stays valid for 150 s, so a rejoin aft |
| A09 | medium | DataService | Profile sanitizer runs AFTER Reconcile and deletes NaN Stats keys, so every later AddCash/ |
| A10 | medium | DataService | D.Save takes its DeepCopy before retrying and saves are not serialised per player, so a re |
| A11 | medium | DataService | Release save on leave can be overtaken by a concurrent autosave or receipt save that write |
| A12 | medium | InteractService | No per-player debounce on hold-0 interaction prompts; spamming the Plaza portal starts sev |
| A13 | medium | JobService | The 'Unload' remote loads carried items into the truck from anywhere, with no truck-at-ram |
| A14 | medium | MonetizationService | Gamepasses are granted from the unverified PromptGamePassPurchaseFinished signal, and Game |
| A15 | medium | MonetizationService | ProcessReceipt marks a purchase as granted before the yielding save, so a concurrent call  |
| A16 | medium | MonetizationService | ProcessReceipt credits the goods before the save yields, and the rollback cannot undo good |
| A17 | medium | PlazaService | Plaza.Goto sets the Teleporting guard only after yielding MemoryStore/ReserveServer calls: |
| A18 | medium | StaffService | S.Collect credits each entry before clearing Pending: an error mid-loop re-credits the sam |
| A19 | medium | TradeService | Trade persistence is not atomic: sequential saves without reconciliation can lose or dupli |
| A20 | medium | VehicleService | Anti-teleport rollback opens a 3 s window where any truck position is accepted as the new  |
| A21 | medium | ScreensCrew | Incoming trade request force-opens a window and can be spammed to grief players in the Pla |
| A22 | medium | UI | Builders that yield inside UI.Open/refreshNow leave windows stuck open or build their cont |
| A23 | low | ItemRegistry | 'Secret' items and pets are only hidden in the UI; their names and stats ship to every cli |
| A24 | low | Net | S->C RemoteEvents have no server handler, so exploiter FireServer calls pile up in the eve |
| A25 | low | Validate | Sanitizer resets a non-finite NextCrewId to 1, so new pets overwrite existing pet uid '1', |
| A26 | low | Main | Steps in onLeave before the final save are not protected, so an error skips the save entir |
| A27 | low | AdminService | C.ClearItems ignores equipment reserved by staff auto-events |
| A28 | low | AdminService | ResetData leaves Staff migration and receipt history inconsistent |
| A29 | low | CarryService | Carry slowdown and all walking costs are enforced only by the client: the server never che |
| A30 | low | CaseService | Location gate for cases and roadcases relies on the client-owned character position |
| A31 | low | CaseService | CaseService.OpenOwned decrements before validating the case id: an unknown or legacy id th |
| A32 | low | CrewService | Crew/Pet functions crash on an unknown pet type id in a save |
| A33 | low | DataService | At shutdown every player is saved twice at once (BindToClose SaveAll plus PlayerRemoving), |
| A34 | low | FastTravel | FastTravel checks the carry rule before its yields and never checks it again |
| A35 | low | JobService | Spedition can be spammed: unbounded m.Deliveries, each firing region-wide truck FX to othe |
| A36 | low | JobService | Spedition truck split goes negative if equipment exceeds one semi (latent) |
| A37 | low | PlacementService | Proximity gates in the carry and build loop (rack prompt, Place 24 studs, Show start 80 st |
| A38 | low | ShopService | SellItem accepts the modular LED wall: the item is deleted while LEDLevel stays, so the wa |
| A39 | low | VehicleService | VehicleSeat can be entered by touching it, which bypasses the 'nothing in hand' rule; the  |
| A40 | low | VehicleService | Truck network ownership is never handed back to the server when the driver gets out, so th |

## Details

### A01 · CRITICAL · security — Rename: quadratic gsub on unbounded client string freezes the whole server (Validate.str exists but is never used)
`ServerScriptService.Server.ShopService` ~Zeile 191 · Aufwand S
- **Problem:** function S.Rename(p, name)
	if type(name) ~= "string" then return false, "Ungültiger Name." end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if #name < 3 or #name > 24 then ...
The length check runs AFTER the trim. An unanchored "%s+$" is retried at every start index and greedily scans to the end each time, so it is O(n^2) on a long run of spaces. I measured it with the bundled luau binary on "a"..(k spaces).."b": k=10,000 took 0.60 s, k=20,000 took 2.49 s, k=40,000 took 9.94 s. The router (Main L314-332) calls this inside pcall on the single server thread, and the 0.12 s / 15-per-second limiter still lets about 8 calls/s through. Validate.str(x, maxLen), the helper meant for this, has zero call sites in the runtime (grep). AdminService L834 has the same trim pattern on a.Text, but only admins can reach it.
- **Auswirkung:** One exploiter can send Request("Rename", ("a"..string.rep(" ",40000).."b")) a few times a second and freeze the server's Lua thread for every player. Heartbeat, saves and remotes all stall, which can trigger mass disconnects and the BindToClose/session-lock edge cases.
- **Fix (gegengeprüft):** In ShopService S.Rename, replace the type check and trim with:
	name = Validate.str(name, 64)
	if not name then return false, "Ungültiger Name." end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
Validate is already required at L11, and the existing 3–24 check stays. 64 bytes leaves room for padding and multi-byte UTF-8 while keeping the pattern work trivial.

In AdminService C.Announce (L834):
	local raw = type(a) == "table" and Validate.str(a.Text, 400)
	local text = raw and raw:gsub("^%s+", ""):gsub("%s+$", "") or ""
This needs a Validate require if AdminService doesn't have one; the 1–200 check after it stays. Don't rely on swapping in a different trim pattern: both gsub and match("^%s*(.-)%s*$") are O(n^2) on unbounded input.

### A02 · HIGH · correctness — Tours can be started at a level below their later stops, and venues for later stops are never checked, so the tour breaks partway through
`ReplicatedStorage.Modules.WorldConfig` ~Zeile 756 · Aufwand S
- **Problem:** W.Tours = {
  { Id = "clubtour", ..., Level = 9, Stops = { "rockhalle", "technonight", "messegala" }, ...},
  { Id = "summertour", ..., Level = 16, Stops = { "hafenfestival", "arenashow", "stadion" }, ...} }
The stop jobs are messegala Level = 10 (L483) and stadion Level = 18 (L491). JobService.StartTour (L756-766) checks only t.Level and the PreRig count, then starts stop 1. ShowService L114-118 starts the next stop with ctx.Jobs.StartJob(p, nextJob, {Tour=..., Force = job.Forced}). That call goes through S.JobAvailable (L343-349), which checks `d.Level < job.Level`, `d.Regions[v.Region]` and `d.Venues[job.Venue]`. A level-16 player who starts the summertour gets "Tournee unterbrochen: Ab Level 18" (or "Location Stadion Metropolis gesperrt") after two stops. XP is per level (Economy L110), so 16 to 18 within two stops is not guaranteed. The same applies to clubtour at level 9 (messegala needs 10, plus Portavia, ClubDock and Messehalle unlocks). ScreensJobs L280-282 shows "Benötigt: Level 9/16" and enables the button.
- **Auswirkung:** Players who meet the shown requirement lose the whole tour reward (20/60 tokens + case) and the time they spent. The tour is interrupted after they have already paid rent and driven to the earlier stops.
- **Fix (gegengeprüft):** In JobService.StartTour, after the PreRig check, pre-validate every stop using the same rules startJob will apply later. Leave out freeStage and NightOnly, because those change over time:
```lua
for _, sid in ipairs(t.Stops) do
	local j = W.JobById[sid]
	local v = j and W.Venues[j.Venue]
	if not v then return false, "Tournee fehlerhaft konfiguriert." end
	if d.Level < j.Level then return false, "Tournee: " .. j.Name .. " ab Level " .. j.Level .. "." end
	if not d.Regions[v.Region] then return false, "Tournee braucht " .. W.Regions[v.Region].Name .. "." end
	if not d.Venues[j.Venue] then return false, "Tournee braucht Location " .. v.Name .. "." end
end
```
In WorldConfig, after building W.TourById, add an assert so a typo in a stop id fails at load instead of at runtime:
`for _, t in ipairs(W.Tours) do for _, sid in ipairs(t.Stops) do assert(W.JobById[sid], "Tour stop " .. sid) end end`

Either update the advertised Level to the real minimum (clubtour 10, summertour 18), or have ScreensJobs L279-281 list the required stop venues and disable the button while any of them is locked. Updating the Level only corrects the displayed value: the venue requirement already enforces these minimums, so the actual gate does not change.

### A03 · HIGH · security — Job arrival and material logic read the raw truck position every 0.5 s, before the 1 s watchdog validates it, so a one-tick teleport into the venue zone counts
`ServerScriptService.Server.JobService` ~Zeile 288 · Aufwand S
- **Problem:** The JobService loop runs every 0.5 s (L240-246: `task.wait(0.5) ... pcall(S.Tick, p, s, s.Job, now)`). S.Tick L288: `if zone and root and inBox(zone, root.Position) then arrived = true end` -> `S.Arrive(p)`. Arrive (L1734+) sets `job.Phase = "Building"`, which cannot be undone, and unloads material. L291 `UnloadMaterial` uses the same raw position. The anti-teleport check in VehicleService runs on its own `task.wait(1)` loop (L39) and only rolls back the truck. It never tells JobService that the position was invalid, and Arrive is not reverted.
- **Auswirkung:** An exploiter who owns the truck (which is always the case while driving) can warp it into the venue zone. The 0.5 s job tick fires Arrive before or regardless of the watchdog rollback. The whole Driving phase is skipped, including Express deadlines and tender timing. The rollback only puts the truck back after arrival has already been granted.
- **Fix (gegengeprüft):** Move the watchdog body (VehicleService L60-77) into a function `S.CheckTruck(p, s, t, root)` that returns true when the position is OK. Keep the 1 s loop calling it. Also call it synchronously from JobService before it uses a truck position:

```lua
-- JobService.Tick
local truckOk = root and ctx.Vehicles.CheckTruck(p, s, truck, root)
if zone and truckOk and inBox(zone, root.Position) then arrived = true end
...
elseif (...) and zone and truckOk and inBox(zone, root.Position) then S.UnloadMaterial(p)
```

Do the same in TruckAtDepot.

In CheckTruck, do not refresh `s.TruckLastCF`/`TruckLastT` when the check was skipped because of the warp grace window (except for server warps, which already set TruckLastCF = nil). Alternatively, return false during the grace window when the grace came from a rollback rather than a server warp. Example: set `s.TruckRollbackAt` on rollback, and while `nowT - s.TruckRollbackAt < 3`, measure distance against the rollback CF instead of skipping the check.

Arrival latency stays at 0.5 s, so there is no balancing change and no save-data impact.

### A04 · HIGH · perf-server — GetBoard is an O(jobs x inventory-units x log) CPU hog that one player can spam (~8/s)
`ServerScriptService.Server.JobService` ~Zeile 484 · Aufwand S
- **Problem:** S.Board loops all W.Jobs (~33 + up to 3 tenders) and calls `S.Quote(p, job)` for each (L486-494). Quote -> `S.Plan` (L413) -> `J.Assign(job, ctx.Staff.FreeInventory(p), d.LEDLevel)` (L364). J.Assign (ReplicatedStorage.Modules.JobLogic L77-85) expands the inventory per UNIT and sorts with a comparator that calls R.Score twice per compare:
`for _ = 1, n do table.insert(byType[t], id) end` ... `table.sort(list, function(a, b) return R.Score(a) > R.Score(b) end)`.
Storage goes up to 1956 places (+150 BigWarehouse), so a late-game player has ~500-2000 units. Rough cost: 36 jobs x (2000 inserts + ~20k compares x 2 R.Score) is several million Luau ops, about 30-100 ms of blocking server time per GetBoard. Each Quote also runs J.Evaluate up to twice, plus J.TypeModelFor, which loops over all R.Items without a cache for StageSystem (JobLogic L195-202). The only limits in Main are 0.12 s per action plus a 15/s bucket (Main L313-320), so a client can invoke GetBoard about 8 times per second.
- **Auswirkung:** A heavy-inventory player who opens the job board, or an exploiter calling GetBoard in a loop, stalls the server's Lua thread (Heartbeat, every other player's requests, crew loops) for tens of ms per call. That shows up as server-wide hitching for 20 players.
- **Fix (gegengeprüft):** 1) JobLogic J.Assign (L76-85): sort unique ids with cached scores, then expand.
```lua
local byType, score = {}, {}
for id in pairs(pool) do
  local t = R.Items[id].Type
  byType[t] = byType[t] or {}
  table.insert(byType[t], id)
  score[id] = R.Score(id)
end
for t, ids in pairs(byType) do
  table.sort(ids, function(a, b) local sa, sb = score[a], score[b]; if sa ~= sb then return sa > sb end; return a < b end)
  local out = {}
  for _, id in ipairs(ids) do for _ = 1, pool[id] do out[#out + 1] = id end end
  byType[t] = out
end
```
(The pick logic below stays unchanged. The StageSystem loop with `table.remove(list, i)` still works on the expanded list.)

2) JobLogic J.TypeModelFor: memoise per (t, job.System) in a local table, e.g. `local key = t .. "|" .. job.System; if sysRepCache[key] ~= nil then return sysRepCache[key] end ... sysRepCache[key] = best or J.TypeModel(t)`. R.Items is static at runtime, so this is safe.

3) Main: cache the GetBoard result per player for about 1 s and return the cached table, not false, when the call comes too soon:
```lua
local boardCache = {}
H.GetBoard = function(p)
  local c, now = boardCache[p], os.clock()
  if c and now - c.At < 1 then return true, nil, c.Board end
  local ok, why, board = ctx.Jobs.Board(p)
  boardCache[p] = { At = now, Board = board }
  return ok, why, board
end
```
Add `boardCache[p] = nil` in the existing PlayerRemoving cleanup (next to `bucket[p] = nil`, L493). Also clear `boardCache[p]` in the AcceptJob/AcceptTender/CancelJob/BuyItem/Sell handlers, or simply clear it after every non-GetBoard action in the router, so the board is never stale after a state change.

### A05 · HIGH · correctness — Silhouette viewport assigns a Font datatype to TextLabel.Font, so it errors for every non-admin player
`StarterPlayer.StarterPlayerScripts.Client.UI` ~Zeile 250 · Aufwand S
- **Problem:** UI.Viewport: `if props.Silhouette then ... new("TextLabel", { ..., Font = T.FontTitle, TextScaled = true, ... })`. Theme.lua:42 defines `T.FontTitle = Font.new("rbxasset://fonts/families/FredokaOne.json", ...)`, which is a Font datatype. TextLabel.Font takes an Enum.Font, so UI.new's `i[k] = v` (UI.lua:17) throws on this assignment. This is the only raw `Font =` assignment on the client; every other place uses FontFace through UI.Text. The developer would not have seen it: ItemRegistry.R.IsHidden L412 `if state and state.Admin then return false end` (and CrewR.IsHidden works the same way) means admins never get Silhouette=true, so admin Play tests never reach this line.
- **Auswirkung:** Normal players who have not found every Secret item hit the error when the Shop opens the '🧰 Roadcase' tab (ScreensShop L73: all 45 exclusives, undiscovered Secrets with Silhouette=true). The builder aborts partway: the grid stops at the first hidden Secret and the detail panel is never built. The same crash happens when an undiscovered Secret row is selected in the Roadcases window (ScreensRoadcase L311) and when a trade partner offers a Secret pet you have not found yet (ScreensCrew L230), …
- **Fix (gegengeprüft):** In StarterPlayer.StarterPlayerScripts.Client.UI L250, replace `Font = T.FontTitle` with `FontFace = T.FontTitle`. To make sure no other raw TextLabel uses the enum property, grep the runtime code for `Font = T.Font` passed to `new("Text...` calls; UI.Text callers are fine because UI.Text maps props.Font to FontFace.

### A06 · MEDIUM · race-condition — Join pipeline yields after the profile is live (Monetization.Join): a leave in that window leaks the claimed plot and spawned truck, and early requests see no Robux passes
`ServerScriptService.Main` ~Zeile 457 · Aufwand M
- **Problem:** Main.onJoin L455 `ctx.Data.Profiles[p] = d` then L457 `ctx.Monetization.Join(p)`, which calls `pcall(MarketplaceService.UserOwnsGamePassAsync, ...)` sequentially for every pass (Monetization L83-87). It then continues to L461-462 `ctx.Plots.Claim(p)` / `ctx.Vehicles.Spawn(p)`. The `if not p.Parent` check exists only after Data.Load (L449). If the player leaves during the pass checks, onLeave runs Plots.Release/Vehicles.Despawn first (nothing to release yet) and then yields in Data.Save while Sessions[p] still exists. onJoin resumes and PlotService.Claim (L43-77) clones a warehouse, sets P.Owners[plot] = p, and spawns a truck that nobody ever releases. The Request router also accepts actions as soon as Profiles[p] is set, so BuyPassTokens (Monetization L96 `HasPass`) can charge tokens for a pass the player already owns for Robux but that has not loaded yet. A failed UserOwnsGamePassAsync is not retried, so a paying player loses the pass for the whole session. This is latent today (every GamePassId = 0, so there is no yield) and goes live as soon as the pass IDs are entered.
- **Auswirkung:** After launch: plots stay occupied for the lifetime of the server ('Alle Firmengelände sind belegt'), warehouse and truck models leak, paying players randomly lose their passes for a session, joins are 18 web calls slower, and tokens can be spent twice on a pass the player already owns.
- **Fix (gegengeprüft):** Simplest fix that keeps current behaviour: in onJoin, move the pass lookup to before `ctx.Data.Profiles[p] = d`. Have Monetization.Join start one task.spawn per pass whose GamePassId is not 0. Each task retries pcall once (task.wait(1) before the retry) and writes into a local table; wait for all tasks with a deadline of about 5 s; then set `s.OwnedPasses` from that table. Move grantVIPCase into a separate function (for example M.AfterProfile(p)) that runs after the profile is set. Directly after the pass lookup, repeat the existing guard: `if not p.Parent or ctx.Sessions[p] ~= s then pcall(ctx.Data.ReleaseLock, p); if ctx.Sessions[p] == s then ctx.Sessions[p] = nil end; return end`, then set `Profiles[p] = d`. As defense in depth, also put `if not p.Parent or ctx.Sessions[p] ~= s then return end` immediately before Plots.Claim/Vehicles.Spawn. Do not call ReleaseLock at that point: onLeave already saves with release=true once Profiles[p] is set.

### A07 · MEDIUM · security — Owned loot cases from the Robux VIP pass open without the ArePaidRandomItemsRestricted policy check
`ServerScriptService.Server.CaseService` ~Zeile 14 · Aufwand S
- **Problem:** function K.OpenOwned(p, arg)
	local d = ctx.Data.Profiles[p]
	local caseId = ...
	if type(caseId) ~= "string" or (d.Cases[caseId] or 0) <= 0 then ...
	-- no Policy check
MonetizationService.grantVIPCase: `ctx.Cases.Give(p, "VIPBlack", 1)` when the VIP pass is owned (bought with Robux or with Tokens, which are Robux-bought). K.Buy checks `pol.ArePaidRandomItemsRestricted` only on the token path (L72-75).
- **Auswirkung:** In regions where paid random items are restricted, a Robux gamepass still delivers a random-pet case that the player can open. This is a policy-compliance risk that the Buy path guards against and the OpenOwned path does not.
- **Fix (gegengeprüft):** Gate the paid grant in MonetizationService.grantVIPCase instead of OpenOwned, so cases earned through gameplay stay openable:

local function grantVIPCase(p)
	local d = ctx.Data.Profiles[p]
	if d and not d.FreeVIPCase and ctx.Economy.HasPass(p, "VIP") then
		local s = ctx.Sessions[p]
		local pol = s and s.Policy
		if pol and pol.ArePaidRandomItemsRestricted then return end -- keep FreeVIPCase=false so it can be granted later if policy allows (e.g. PolicyFailed fallback)
		d.FreeVIPCase = true
		ctx.Cases.Give(p, "VIPBlack", 1)
		ctx.Notify(p, "👑 VIP aktiv! Dein gratis VIP Black Case liegt im Inventar.", "Gold")
	end
end

Optionally also update the VIP pass description or UI so restricted players don't see the free case advertised. Cases that were already granted before this fix are left as they are (save-compatible).

### A08 · MEDIUM · data-integrity — Lock wait gives up after about 50 s although a lock stays valid for 150 s, so a rejoin after a server crash gives a whole session without saving
`ServerScriptService.Server.DataService` ~Zeile 16 · Aufwand M
- **Problem:** L15 `LOCK_TIMEOUT = 150`, L16 `LOAD_ATTEMPTS = 12 -- ~50 s`. After the loop, L100-102: `D.Temp[player] = true return newProfile(player), "Profil ist noch auf einem anderen Server aktiv – bitte in 1–2 Minuten neu beitreten. Bis dahin wird nichts gespeichert."`. A server crash or a failed final save leaves a lock that is up to 60 s old (the autosave refresh), so it can stay valid for up to 150 s.
- **Auswirkung:** Players who rejoin immediately after a crash (the usual reaction) get a fresh starter profile. Nothing they do in that session is saved unless they notice the warning and rejoin again. Receipts and trades are blocked for that session.
- **Fix (gegengeprüft):** Make the wait cover the lock's remaining lifetime, with a hard cap. Keep the rule that a fresh lock is never stolen:

1. Inside the UpdateAsync transform, when the lock is foreign and fresh, record its age: `lockAge = os.time() - (lock.Time or 0)`.
2. Replace the fixed `for attempt = 1, LOAD_ATTEMPTS` loop with a deadline: `local deadline = os.clock() + LOCK_TIMEOUT + 10`. Loop while `result == "LOCKED" and os.clock() < deadline`. Between tries, wait `math.clamp(LOCK_TIMEOUT - lockAge + 1, 4, 15)` seconds so the DataStore isn't hit needlessly. Keep the existing `if not player.Parent then return ... end` exit.
3. Leave the L100-102 fallback in place for the case where the cap is reached. That happens when the other server is genuinely alive and keeps refreshing the lock.
4. During the wait, Main should show the player a "Profil wird geladen…" status, for example via the existing notify path before calling ctx.Data.Load. Profiles[p] stays unset until Load returns.

Only timing changes. Save data, lock semantics and balancing are untouched.

### A09 · MEDIUM · data-integrity — Profile sanitizer runs AFTER Reconcile and deletes NaN Stats keys, so every later AddCash/stat update errors for the rest of the session
`ServerScriptService.Server.DataService` ~Zeile 108 · Aufwand S
- **Problem:** DataService.Load L105-108:
  U.Reconcile(result, D.Template)
  for k, v in pairs(D.Template.Stats) do if result.Stats[k] == nil then result.Stats[k] = v end end
  local fixed = Validate.sanitizeProfile(result, D.Template)
Validate.sanitizeProfile L87-95 handles NUMERIC_MAPS (which includes "Stats"):
  if type(v) == "number" and not V.isFinite(v) then m[k] = nil
The old NaN exploit went through Economy.AddCash, which writes both d.Cash and d.Stats.CashEarned (Economy L78-79). So the profiles this migration is meant to repair are exactly the ones with Stats.CashEarned = NaN. The sanitizer sets it to nil, and Reconcile has already run, so nothing refills it. Economy.AddCash L79 `d.Stats.CashEarned += math.floor(n)` then throws 'arithmetic on nil' AFTER L78 has already added the cash. Every payout path (show reward, dispatch, daily) aborts halfway. The same happens for Stats.Events (Rewards.CheckMilestones L64 compares nil >= number) and for the other Stats keys.
- **Auswirkung:** Players whose saves were hit by the old NaN exploit get broken payouts for a whole session: the error propagates through the router pcall, XP/tokens after the cash are skipped, and job/show completion code aborts halfway. The next load fixes it only because Reconcile refills the missing key then.
- **Fix (gegengeprüft):** In DataService.Load, run the sanitizer before reconciling so that keys it removes get the template defaults back:
  result.Lock = nil
  local fixed = Validate.sanitizeProfile(result, D.Template)
  if #fixed > 0 then warn(...) end
  U.Reconcile(result, D.Template)
  for k, v in pairs(D.Template.Stats) do if result.Stats[k] == nil then result.Stats[k] = v end end
  WCfg.Migrate(result) ...
sanitizeProfile already handles a missing map through `type(m) == "table"`, and NUMERIC_TOP falls back to defaults, so this order is safe. Optional hardening: in onLeave, wrap the PlayTime update so it can never block the save: `pcall(function() d.Stats.PlayTime = (tonumber(d.Stats.PlayTime) or 0) + os.time() - s.Joined end)`.

### A10 · MEDIUM · data-integrity — D.Save takes its DeepCopy before retrying and saves are not serialised per player, so a retried stale copy can overwrite a newer save (including a granted receipt)
`ServerScriptService.Server.DataService` ~Zeile 141 · Aufwand M
- **Problem:** L141 `local copy = U.DeepCopy(d)` runs once. Then L143-153 `retry(function() return s:UpdateAsync(key, function(old) ... return copy end) end, 4)` can retry with task.wait(1.5*i) (up to about 9 s). In the meantime another save can commit: ProcessReceipt's `ctx.Data.Save(p, false)` (Monetization L59), the trade saves, or the leave save. When the stale autosave copy then succeeds, it overwrites that newer state: the Purchases key and the tokens, or the trade result. Nothing tracks in-flight saves per player.
- **Auswirkung:** In the window until the next autosave (60 s), the DataStore holds an older state than one that was confirmed to Roblox with PurchaseGranted. A server crash or shutdown in that window loses paid tokens or roadcases, or reverts a trade on one side (possible duplication).
- **Fix (gegengeprüft):** Build the snapshot inside the transform: `local cur = D.Profiles[player] or d; local copy = U.DeepCopy(cur); copy.Lock = (not release) and {Job=game.JobId, Time=os.time()} or nil; written = true; return copy`. Serialise per player: keep `inflight[player]`. If a save is already running, set `pending[player] = {release = (pending.release or release)}` and wait (poll or BindableEvent) until a save that started after this call finishes, then return that save's result. That way ProcessReceipt and Trade still get a truthful success or failure for data that includes their change. When the running save finishes and pending is set, run one more save with the merged release flag. Never let a release=false save start after a release=true save has completed for the same player (drop it if D.Profiles[player] is nil and the release already succeeded).

### A11 · MEDIUM · race-condition — Release save on leave can be overtaken by a concurrent autosave or receipt save that writes the session lock again, so a teleport to the Plaza or a rejoin gets a Temp profile
`ServerScriptService.Server.DataService` ~Zeile 149 · Aufwand S
- **Problem:** Main.onLeave L485-487: `ctx.Data.Save(p, true)` yields, and only afterwards does `ctx.Data.Profiles[p] = nil` run. During that yield the profile is still in D.Profiles, so the autosave loop (DataService L182-183 `for p in pairs(D.Profiles) do task.spawn(D.Save, p, false)`) or a ProcessReceipt Save(p,false) can start too. In D.Save L149 `copy.Lock = (not release) and { Job = game.JobId, Time = os.time() } or nil`, the non-release save writes the lock back after the release save cleared it. The target server's D.Load (L78) then sees a fresh foreign lock (< LOCK_TIMEOUT 150 s), waits LOAD_ATTEMPTS 12 x 4 s (~50 s), and returns a Temp profile: 'Profil ist noch auf einem anderen Server aktiv'. The Plaza teleport (PlazaService) causes a PlayerRemoving on every hop, so this window opens often.
- **Auswirkung:** About one leave in 60-100 that lines up with the 60 s autosave tick leaves the profile locked for 150 s. The player then lands in the Plaza or a new server on a fresh unsaved Temp profile, cannot trade, and anything they do there is not saved.
- **Fix (gegengeprüft):** DataService:
1. Add the state tables:
   `D.Releasing = {}`
   `D.Closing = false`
2. In D.Save, after `local d = D.Profiles[player]` and its guard, add:
   `if not release and (D.Releasing[player] or D.Closing) then return false, "releasing" end`
   `if release then D.Releasing[player] = true end`
3. In the UpdateAsync transform, before L149, add:
   `if not release and (D.Releasing[player] or D.Closing or D.Profiles[player] ~= d) then written = false; return nil end`
   The `D.Profiles[player] ~= d` check also covers a save that is still in flight or retrying after onLeave has cleared the profile.
4. In the BindToClose handler, set `D.Closing = true` before `D.SaveAll(true)`. In the autosave loop, add `if D.Closing then break end`.

Main.onLeave:
- After `ctx.Data.Profiles[p] = nil`, add `ctx.Data.Releasing[p] = nil`. The Profiles identity check keeps any late non-release transform from writing.

TradeService:
- No change is needed. Its `Save(tr.B,false)` returns "releasing", and the release save already contains the traded state, because the trade is applied in memory before close().

Save data and gameplay are unchanged: only redundant non-release writes during or after the release are dropped.

### A12 · MEDIUM · security — No per-player debounce on hold-0 interaction prompts; spamming the Plaza portal starts several Plaza.Goto calls at once
`ServerScriptService.Server.InteractService` ~Zeile 148 · Aufwand S
- **Problem:** L109 `pr.HoldDuration = 0`; L117-119 `pr.Triggered:Connect(function(p) I.Handle(p, kind, inst) end)`. There is no rate limit, unlike the Request router's 0.12 s per action plus token bucket in Main L311-320. I.Handle -> ctx.Plaza.Goto checks `p:GetAttribute("Teleporting")` but only sets it after `plazaCode()` yields on MemoryStore GetAsync x2 and possibly ReserveServer (PlazaService L149-151). Every Triggered fired during that yield passes the check and spawns its own `Data.Save` + `TeleportAsync`.
- **Auswirkung:** An exploiter using fireproximityprompt, or a fast clicker, can trigger parallel DataStore saves, MemoryStore reads and ReserveServer calls for one player. This uses up per-server request budgets and duplicates teleports. Case/Roadcase prompts can also be spammed to flood the Open remote.
- **Fix (gegengeprüft):** In PlazaService.Goto, set the flag right after the guard, before the yield:
```
if p:GetAttribute("Teleporting") then return false, "Teleport laeuft schon." end
p:SetAttribute("Teleporting", true)
local code, why = plazaCode()
if not code then
    if p.Parent then p:SetAttribute("Teleporting", nil) end
    return false, "Trading Plaza gerade nicht erreichbar (" .. tostring(why) .. ")."
end
```
Remove the later `p:SetAttribute("Teleporting", true)` at L151. Keep the existing reset in the TeleportAsync failure branch and the one in TeleportInitFailed.

Optional: add a debounce in I.Handle, `local lastUse = setmetatable({}, {__mode = "k"})`, and at the top of Handle: `local t = os.clock(); if lastUse[p] and t - lastUse[p] < 0.3 then return end; lastUse[p] = t`. The weak keys mean no PlayerRemoving hook is needed.

### A13 · MEDIUM · security — The 'Unload' remote loads carried items into the truck from anywhere, with no truck-at-ramp or distance check
`ServerScriptService.Server.JobService` ~Zeile 1088 · Aufwand S
- **Problem:** Main L233: `H.Unload = function(p) ctx.Jobs.CargoInteract(p) return true end`. CargoInteract L1088-1110: `if #carried > 0 then ... ctx.Vehicles.CanLoad(p, e.Id) ... ctx.Vehicles.AddCargo(p, e.Id) ... packingDone(p)`. There is no S.TruckAtDepot(p) check and no distance check between the character and the truck. The ProximityPrompt path (VehicleService L182-196, MaxActivationDistance 12) is the only intended entry. AutoPack (L1552) and LoadMaterial (L997) both require TruckAtDepot.
- **Auswirkung:** Exploit with nothing more than firing the existing remote: park the empty truck in the venue's Unload zone, GoHome (teleport), pick up staged items, then fire Request('Unload'). Everything lands in the far-away truck, packingDone switches to Driving, and the next Tick (L288 inBox(zone, root.Position)) calls Arrive at once. This skips the loaded drive, the core gameplay loop.
- **Fix (gegengeprüft):** Put the distance check on the remote path only. The prompt path is already limited to 12 studs, and the unload-only HUD button must keep working from anywhere. Add the depot check to the Packing load branch.

1) Main L233:
```lua
H.Unload = function(p)
	if #ctx.Carry.List(p) > 0 then
		local s = ctx.Sessions[p]
		local door = s and s.Truck and s.Truck:FindFirstChild("CargoDoor")
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not (door and root and (root.Position - door.Position).Magnitude <= 16) then
			return false, "Geh zum LKW-Heck, um einzuladen."
		end
	end
	ctx.Jobs.CargoInteract(p)
	return true
end
```

2) JobService S.CargoInteract, at the top of the `if #carried > 0 then` branch:
```lua
if job and job.Phase == "Packing" and not S.TruckAtDepot(p) then
	ctx.Notify(p, "Stell den LKW an deine Laderampe, um einzuladen.", "Warn")
	return
end
```
TruckAtDepot already uses a 45-stud XZ radius, which covers normal parking at the ramp.

### A14 · MEDIUM · security — Gamepasses are granted from the unverified PromptGamePassPurchaseFinished signal, and GamePassId 0 matches every pass
`ServerScriptService.Server.MonetizationService` ~Zeile 21 · Aufwand S
- **Problem:** MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p, passId, bought)
	if not bought then return end
	for id, pass in pairs(G.Passes) do
		if pass.GamePassId == passId and ctx.Sessions[p] then
			ctx.Sessions[p].OwnedPasses[id] = true ...
The passId/bought values come from the client's purchase prompt flow. Nothing checks them against UserOwnsGamePassAsync. All 18 entries in GameConfig.G.Passes currently have GamePassId = 0, so one spoofed signal with passId 0 matches every pass in the loop. That includes DoubleCash, VIP, InfiniteTruck, SecretFinder, UltraLucky and TripleHatch. M.Join and ProcessReceipt both skip id 0, but this handler does not.
- **Auswirkung:** An exploiter can unlock all paid gamepass perks for the session. Money, XP, pets and items earned with those perks are saved, so the gain is permanent. Real buyers are unaffected, but the paid-pass economy is bypassed.
- **Fix (gegengeprüft):** MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p, passId, bought)
	if not bought or type(passId) ~= "number" or passId == 0 then return end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, p.UserId, passId)
	if not (ok and owns) then return end
	local s = ctx.Sessions[p]           -- re-check after the yield (player may have left)
	if not s or not p.Parent then return end
	for id, pass in pairs(G.Passes) do
		if pass.GamePassId ~= 0 and pass.GamePassId == passId then
			s.OwnedPasses[id] = true
			ctx.Notify(p, pass.Name .. " aktiviert!", "Gold")
			grantVIPCase(p)
			ctx.OnPassesChanged(p)
			ctx.Push(p)
		end
	end
end)

### A15 · MEDIUM · data-integrity — ProcessReceipt marks a purchase as granted before the yielding save, so a concurrent call can acknowledge a purchase that is later rolled back
`ServerScriptService.Server.MonetizationService` ~Zeile 40 · Aufwand S
- **Problem:** `table.insert(d.Purchases, key)` (L57), then `local saved, why = ctx.Data.Save(p, false)` (L59, yields up to about 15 s with retries). On failure it rolls back: `table.remove(d.Purchases, idx)` and NotProcessedYet. A second ProcessReceipt for the same PurchaseId during the yield hits `if table.find(d.Purchases, key) then return Enum.ProductPurchaseDecision.PurchaseGranted end` (L40). That acknowledges the receipt to Roblox even though the first call then rolls back and nothing is persisted.
- **Auswirkung:** In rare cases (DataStore outage plus a receipt retry or rejoin during the save), the player pays Robux and receives nothing, because Roblox will not redeliver an acknowledged receipt.
- **Fix (gegengeprüft):** Add a module-level `local inFlight = {}`. Rename the current callback body to `local function processReceipt(info)`, then set:
MarketplaceService.ProcessReceipt = function(info)
  local key = tostring(info.PurchaseId)
  if inFlight[key] then return Enum.ProductPurchaseDecision.NotProcessedYet end
  inFlight[key] = true
  local ok, res = pcall(processReceipt, info)
  inFlight[key] = nil
  if not ok then warn("[Monetization] ProcessReceipt error: " .. tostring(res)); return Enum.ProductPurchaseDecision.NotProcessedYet end
  return res
end
Use pcall so that an error cannot leave the key locked for good.

### A16 · MEDIUM · security — ProcessReceipt credits the goods before the save yields, and the rollback cannot undo goods spent or opened in that window, so a failed save plus re-delivery duplicates them
`ServerScriptService.Server.MonetizationService` ~Zeile 59 · Aufwand S
- **Problem:** L45 `ctx.Economy.AddTokens(p, pack.Tokens)` and L53 `ctx.Roadcases.Grant(p, rcCase, 1)` (Grant also calls ctx.Push, so the client sees the case immediately). Then L59 `local saved, why = ctx.Data.Save(p, false)` yields, for up to ~10 s on retries. During that time the router keeps accepting OpenRoadcase/BuyPassTokens/BuyCase. On failure the rollback is L65 `d.Tokens = math.max(0, d.Tokens - tokensGiven)`, which clamps to 0 if the tokens were spent, and L66 `if rcCase and (d.Roadcases[rcCase] or 0) > 0 then`, which is skipped if the case was opened. L71 then returns NotProcessedYet, so Roblox delivers the receipt again and the goods are granted a second time.
- **Auswirkung:** Each time a DataStore save fails while a purchase is processed, the player gets a free premium roadcase or free token purchases. A player can make this more likely by spamming purchases during DataStore degradation.
- **Fix (gegengeprüft):** The proposed router-wide ReceiptBusy gate is fine, but it has two gaps, so the corrected fix has three parts.

(1) Clear the flag on every return path, including Luau errors. Use a wrapper: `MarketplaceService.ProcessReceipt = function(info) local p = Players:GetPlayerByUserId(info.PlayerId); local s = p and ctx.Sessions[p]; if s then s.ReceiptBusy = (s.ReceiptBusy or 0) + 1 end; local ok, res = pcall(processReceipt, info); if s then s.ReceiptBusy -= 1 end; if not ok then warn(res) return Enum.ProductPurchaseDecision.NotProcessedYet end; return res end`. Use a counter instead of a boolean, because receipts can overlap.

(2) In the Main router, after the profile check: `local s = ctx.Sessions[p]; if s and (s.ReceiptBusy or 0) > 0 then return false, "Kauf wird verarbeitet …" end`.

(3) Close the same-PurchaseId race with a module-level `local inFlight = {}`. At the top of processReceipt: `if inFlight[key] then return Enum.ProductPurchaseDecision.NotProcessedYet end; inFlight[key] = true`. Clear it on every exit, for example in the wrapper. Keep the L40 table.find check after this, so a receipt that is already saved still returns PurchaseGranted. None of this changes save data.

### A17 · MEDIUM · race-condition — Plaza.Goto sets the Teleporting guard only after yielding MemoryStore/ReserveServer calls: concurrent calls double-reserve, double-save and double-teleport
`ServerScriptService.Server.PlazaService` ~Zeile 148 · Aufwand S
- **Problem:** if p:GetAttribute("Teleporting") then return false, "Teleport laeuft schon." end
local code, why = plazaCode()   -- 2x MemoryStore GetAsync, maybe ReserveServer + SetAsync (yields)
...
p:SetAttribute("Teleporting", true)
Goto is reachable through 4 entry points with separate rate-limit keys: Request "GotoPlaza" (Main L250), "TravelTo" with Kind="Plaza" (FastTravel L127), the portal prompt (InteractService L85) and admin Teleport Dest="Plaza". The per-action 0.12 s limiter in Main therefore does not serialise them.
- **Auswirkung:** Two or three overlapping calls each pass the guard and run plazaCode(). When the Plaza is full they each call ReserveServer and overwrite "current", which orphans codes. Each one also starts its own Data.Save and TeleportAsync, wasting DataStore and Teleport budget and producing conflicting failure toasts.
- **Fix (gegengeprüft):** In S.Goto replace L148-151 with:
  if p:GetAttribute("Teleporting") then return false, "Teleport laeuft schon." end
  p:SetAttribute("Teleporting", true)
  local code, why = plazaCode()
  if not code then
      if p.Parent then p:SetAttribute("Teleporting", nil) end
      return false, "Trading Plaza gerade nicht erreichbar (" .. tostring(why) .. ")."
  end
plazaCode() only uses pcall'd calls, so it cannot throw and leave the flag stuck. Optionally re-check `ctx.Sessions[p] and ctx.Sessions[p].Job` after the yield, because a job could have been accepted during the wait.

### A18 · MEDIUM · data-integrity — S.Collect credits each entry before clearing Pending: an error mid-loop re-credits the same auto-events every second (cash dupe)
`ServerScriptService.Server.StaffService` ~Zeile 287 · Aufwand S
- **Problem:** Collect L287-297 credits each Pending entry and clears `st.Pending = {}` only after the loop finishes. S.Tick runs Collect inside `pcall(S.Tick, p)` every 1 s whenever Office > 0 (L51, L275-277). Economy.AddCash (Economy L78-79) does `d.Cash += math.floor(n)` and then `d.Stats.CashEarned += math.floor(n)`. If the second line throws, for example in the already-known state where the sanitizer deleted a NaN Stats key (DataService L108), the cash is already credited, Pending stays full, and the next Tick 1 s later credits the same entries again. The same happens if AddXP, `table.insert(st.Log, 1, ...)` or the Stats.Events line throws. Without an Office worker, each click on 'Abrechnen' (CollectStaff remote) repeats it.
- **Auswirkung:** With one corrupted stat key plus an Office worker, Cash grows by the pending Net every second without limit until the player leaves. Through the manual button it grows per click. A non-transactional reward loop turns a one-off error into an economy exploit that persists in saves.
- **Fix (gegengeprüft):** 1) StaffService S.Collect: detach the list before crediting it.
```lua
local list = st.Pending
st.Pending = {}
for _, e in ipairs(list) do
    local ok, err = pcall(function()
        ctx.Economy.AddCash(p, e.Net)
        ctx.Economy.AddXP(p, e.XP)
    end)
    if not ok then warn("[Staff] Collect: " .. tostring(err)) end
    ...
end
```
2) Fix the root cause. In DataService, move the Stats back-fill (L106) after `Validate.sanitizeProfile` (L108), or repeat it after sanitize. Also make Economy.AddCash nil-safe: `d.Stats.CashEarned = (d.Stats.CashEarned or 0) + math.floor(n)`. The save format stays the same and the happy path behaves the same.

### A19 · MEDIUM · data-integrity — Trade persistence is not atomic: sequential saves without reconciliation can lose or duplicate pets; LastTrade is write-only
`ServerScriptService.Server.TradeService` ~Zeile 113 · Aufwand M
- **Problem:** move(tr.A, tr.B, dA, dB, tr.OfferA)
move(tr.B, tr.A, dB, dA, tr.OfferB)
dA.LastTrade, dB.LastTrade = tradeId, tradeId
...
task.spawn(function()
	local okA, whyA = ctx.Data.Save(tr.A, false)
	local okB, whyB = ctx.Data.Save(tr.B, false)
	if not okA or not okB then warn(... "Autosave holt es nach")
A grep shows `LastTrade` is never read anywhere, so the comment "damit ein wiederholter Lauf erkennbar wäre" has no code behind it.
- **Auswirkung:** If A's save succeeds and B's fails, a crash or a lost lock before the next successful B save destroys A's pets: they are gone from A and never stored for B. If A's save fails and B's succeeds, the DataStore holds the pets in both profiles, which is a duplication. A previous fix in the log describes the trade as "atomar genug", but nothing retries or reconciles a half-saved trade.
- **Fix (gegengeprüft):** Minimal and behaviour-preserving. Inside the existing task.spawn:
1. Start both saves at the same time and wait for both:
   local okA, whyA; local done = false
   task.spawn(function() okA, whyA = ctx.Data.Save(tr.A, false); done = true end)
   local okB, whyB = ctx.Data.Save(tr.B, false)
   while not done do task.wait() end
2. Retry any side that returned false, up to 3 times with backoff (2s, 4s, 8s), and only while that player's profile still exists. Skip the retry if the reason is "locked", since the lock belongs to another server.
3. While those retries run, set a tradeSaving[p] flag. Have canTrade return false when it is set, so the player cannot start a chained trade on unsaved state. Clear the flag at the end, and also on PlayerRemoving.
4. Remove LastTrade, or replace it with a real ledger: before the swap, write {A=userIdA, B=userIdB, offers, state="pending"} to a separate TradeLog DataStore key, and mark it "done" once both saves succeed. A load-time check per profile alone cannot detect a half-applied trade. Without a ledger, keep the narrowed window from steps 1-3 and update the comment so it no longer claims the trade is detectable.

### A20 · MEDIUM · security — Anti-teleport rollback opens a 3 s window where any truck position is accepted as the new 'last valid' position
`ServerScriptService.Server.VehicleService` ~Zeile 71 · Aufwand S
- **Problem:** L62: `if s.TruckLastCF and (not s.TruckWarpAt or nowT - s.TruckWarpAt > 3) and ... then` (check). Rollback branch L70-71: `t:PivotTo(s.TruckLastCF)` then `s.TruckWarpAt = nowT`. L77 runs unconditionally: `s.TruckLastCF, s.TruckLastT = root.CFrame, nowT`. So for 3 s after a rollback, the distance check is skipped and TruckLastCF is overwritten each tick with wherever the client-owned truck is. Travel (L436), ReturnHome (L242), Spawn (L130) and the Admin warps do the same: they set `TruckWarpAt = os.clock(), TruckLastCF = nil`. After Travel the driver is still seated and owns the truck, so the next ~3 s of movement are unchecked.
- **Auswirkung:** The speed/teleport check can be bypassed completely. The exploiter teleports once on purpose (rolled back), then teleports again within the next 3 s, and that position becomes the new baseline. Every highway Travel gives the same free 3 s window, enough to warp from the Arrival point straight into the venue zone in the new city. Combined with the known client ownership, the check only stops honest lag spikes.
- **Fix (gegengeprüft):** 1) Watchdog (VehicleService L62-77): drop the grace term from the condition and do not touch the baseline when rolling back:
   if s.TruckLastCF and not s.AdminSpeed and not ctx.Admin.IsAdmin(p) then
     ...
     if (pos - s.TruckLastCF.Position).Magnitude > allowed then
       warn(...); root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
       t:PivotTo(s.TruckLastCF)
       s.TeleportFlags = (s.TeleportFlags or 0) + 1
       ctx.Notify(p, "LKW wurde zurückgesetzt.", "Warn")
       s.TruckLastT = nowT          -- keep TruckLastCF unchanged
       rolledBack = true
     end
   end
   if not rolledBack then s.TruckLastCF, s.TruckLastT = root.CFrame, nowT end
   (Remove `s.TruckWarpAt = nowT` from the rollback branch.)
2) At every server warp, set the baseline to the warp target instead of nil. Keep TruckWarpAt only if something else reads it.
   Spawn L130: s.TruckWarpAt, s.TruckLastCF, s.TruckLastT = os.clock(), m.PrimaryPart.CFrame, os.clock()
   ReturnHome L242: s.TruckWarpAt, s.TruckLastCF, s.TruckLastT = os.clock(), s.Truck.PrimaryPart.CFrame, os.clock()
   Travel L436: s.TruckWarpAt, s.TruckLastCF, s.TruckLastT, s.HighwayAt = os.clock(), root.CFrame, os.clock(), nil
   AdminService L403/L590: the same pattern with the truck's PrimaryPart.CFrame after its PivotTo.
This changes no balancing or save data. On its own the fix still leaves the ~170 studs/s per-second allowance, which the separate ownership/anchoring finding covers.

### A21 · MEDIUM · security — Incoming trade request force-opens a window and can be spammed to grief players in the Plaza
`StarterPlayer.StarterPlayerScripts.Client.ScreensCrew` ~Zeile 316 · Aufwand S
- **Problem:** Client: `elseif msg.Action == "Request" then incoming = {...} UI.Open("TradeRequest")`. UI.Open hides whatever window is current. Server TradeService.Request L183 only blocks requests from a different sender (`if pr and pr.From ~= p and ...`), so the same player can re-request without limit, bounded only by the global 15/s token bucket. Each request fires `{ Action = "Request" }` again.
- **Auswirkung:** In the Trading Plaza, any player can repeatedly close another player's open windows (shop, pets, a running trade setup) by spamming trade requests, which makes the UI unusable for the victim.
- **Fix (gegengeprüft):** Server (TradeService): add a per-pair cooldown that survives a decline, e.g. `local lastReq = {}` keyed `lastReq[p]` = { [t] = os.clock() }. In T.Request, after the canTrade checks: `local lr = lastReq[p] and lastReq[p][t]; if lr and os.clock() - lr < 5 then return false, "Bitte kurz warten." end`, then set `lastReq[p] = lastReq[p] or {}; lastReq[p][t] = os.clock()`. Clear lastReq[p] (and entries for p as target) in PlayerRemoving. Client (ScreensCrew L315): `local same = incoming and incoming.FromId == msg.FromId; incoming = {...}; if same and UI.Current and UI.Current.Id == "TradeRequest" then UI.Refresh("TradeRequest") elseif UI.Current and UI.Current.Id ~= "TradeRequest" then UI.Toast("Handelsanfrage von " .. tostring(msg.From), "Info") else UI.Open("TradeRequest") end`. Also give the user a way to open the pending request, e.g. from the toast or a HUD badge.

### A22 · MEDIUM · race-condition — Builders that yield inside UI.Open/refreshNow leave windows stuck open or build their content twice
`StarterPlayer.StarterPlayerScripts.Client.UI` ~Zeile 344 · Aufwand S
- **Problem:** UI.Open sets `UI.Current = w` and then calls `w.Builder(w.Content, w, arg)` synchronously, followed by `w.Frame.Visible = true`. Two builders yield inside that call. TradeFind runs `local ok, _, data = State.Request("TradePartners", nil, true)` (ScreensCrew L261, an InvokeServer call). FastTravel calls `S.Data(...)`, which runs `State.Request("TravelList" ...)` when the 10 s cache is stale (ScreensTravel L26/L46). If the player presses T again, presses Esc or clicks another dock button during that round trip, UI.Close sets `UI.Current = nil`. Its delayed hide sees a frame that is still invisible. Then the builder resumes and Open sets Visible = true while UI.Current is nil. After that, `UI.Close()` returns early (`if not w then return end`), so the close button and Esc do nothing. If another window was opened instead, both windows are visible at once. refreshNow (L363-364) has the same problem: two region-tab clicks during a stale-cache fetch run two builders into the same Content, and both append.
- **Auswirkung:** A ghost window can neither be closed nor dismissed with Esc, windows can overlap, and FastTravel content can be duplicated or overlap. All of this happens just by double-pressing a hotkey.
- **Fix (gegengeprüft):** In UI.Open:
```lua
w.BuildToken = (w.BuildToken or 0) + 1
local tok = w.BuildToken
-- clear Content
w.Builder(w.Content, w, arg)
if UI.Current ~= w or w.BuildToken ~= tok then return end
-- then set Visible = true, start the tweens, call OnOpen
```

In refreshNow, bump the token the same way before the build. After the builder returns, if `w.BuildToken ~= tok`, return without restoring the scroll positions.

In the TradeFind and FastTravel builders:
1. Capture `local tok = w.BuildToken` before the yielding `State.Request` or `S.Data` call. For TradeFind, add `w` to the builder's parameters first.
2. After the call returns, `if w.BuildToken ~= tok or UI.Current ~= w then return end`, before creating any instances.

As an alternative, use the Jobs pattern: build a 'Lade …' placeholder synchronously, `task.spawn` the request, and fill the content only if the token still matches and `content.Parent` exists. Server behaviour and save data are unaffected.

### A23 · LOW · security — 'Secret' items and pets are only hidden in the UI; their names and stats ship to every client
`ReplicatedStorage.Modules.ItemRegistry` ~Zeile 408 · Aufwand M
- **Problem:** R.IsHidden / R.Display (L408-428) and C.IsHidden / C.Display (CrewRegistry L76-90) mask secret names in windows. The full definitions (e.g. EXCL L308 "Auraline Rathaus-Array", CrewRegistry L39 "Goldener Roadie-Drache") live in ReplicatedStorage modules that every client requires. R.Display also returns `Item = it` for hidden items (L421).
- **Fix (gegengeprüft):** Accept as cosmetic and document it. If real secrecy matters, move the Secret entries' Name/Desc/Brand to a ServerStorage table and send them to a client only after RCFound/CrewFound, and drop `Item = it` from the hidden Display result.

### A24 · LOW · security — S->C RemoteEvents have no server handler, so exploiter FireServer calls pile up in the event queue
`ReplicatedStorage.Modules.Net` ~Zeile 14 · Aufwand S
- **Problem:** `Net.Events = { "State", "Notify", "Broadcast", "FX", "Show", "Hatch", "Open", "Tender", "Trade", "Build", "Carry" }`. A grep for OnServerEvent across all runtime scripts returns nothing. Roblox queues server-side invocations of a RemoteEvent with no OnServerEvent connection until its queue limit, then drops them with warnings.
- **Fix (gegengeprüft):** In Net.Init, for each name in Net.Events: local r = folder:FindFirstChild(n) or create it as now; then r.OnServerEvent:Connect(function() end). This also covers events that already existed in the folder.

### A25 · LOW · data-integrity — Sanitizer resets a non-finite NextCrewId to 1, so new pets overwrite existing pet uid '1', '2', ...
`ReplicatedStorage.Modules.Validate` ~Zeile 83 · Aufwand S
- **Problem:** NUMERIC_TOP contains "NextCrewId" (L75), and L83 `d[k] = (type(def) == "number") and def or 0` resets it to the Template value 1. CrewService L73-74 `local uid = tostring(d.NextCrewId); d.NextCrewId += 1` then writes d.Crew[uid], which overwrites the existing pet with uid "1" (TradeService L104 does the same).
- **Fix (gegengeprüft):** Put the repair inside V.sanitizeProfile, after the NUMERIC_TOP loop, so every caller gets it. The repair always runs, not only when the value was non-finite, which also catches a counter that is finite but too low: `if type(d.Crew)=="table" then local mx=0 for uid in pairs(d.Crew) do local n=tonumber(uid) if n and n==n and n<math.huge then mx=math.max(mx,n) end end if type(d.NextCrewId)~="number" or d.NextCrewId<=mx then d.NextCrewId=mx+1 table.insert(fixed,"NextCrewId") end end`

### A26 · LOW · data-integrity — Steps in onLeave before the final save are not protected, so an error skips the save entirely
`ServerScriptService.Main` ~Zeile 477 · Aufwand S
- **Problem:** L477 `ctx.Admin.Leave(p)` (no pcall) and L484 `if s and s.Joined then d.Stats.PlayTime += os.time() - s.Joined end` both run before L485 `ctx.Data.Save(p, true)`. If either throws (for example Stats.PlayTime is nil after the sanitizer bug above, or a future change to Admin.Leave), the connection handler aborts. There is no save, and the Profiles, Sessions, dirty, lastCall and bucket entries are never cleared, so the Player is leaked.
- **Fix (gegengeprüft):** pcall(ctx.Admin.Leave, p)  -- L477
...
if s and s.Joined then pcall(function() d.Stats = d.Stats or {}; d.Stats.PlayTime = (tonumber(d.Stats.PlayTime) or 0) + (os.time() - s.Joined) end) end
local ok, err = pcall(ctx.Data.Save, p, true); if not ok then warn("[Leave] save failed", p.UserId, err) end
-- the cleanup that clears Profiles, Sessions, dirty and the other tables then always runs

### A27 · LOW · data-integrity — C.ClearItems ignores equipment reserved by staff auto-events
`ServerScriptService.Server.AdminService` ~Zeile 251 · Aufwand S
- **Problem:** if s and s.Job then return false, "Erst den laufenden Auftrag beenden." end
local led = d.Inventory.PixelForge_LEDWall
d.Inventory = {}
JobService.Reserved also adds `ctx.Staff.Reserved(p)` ("Equipment, das Auto-Events gerade unterwegs haben").
- **Fix (gegengeprüft):** In C.ClearItems, after the Job check, add: `if next(ctx.Staff.Reserved(t)) ~= nil then return false, "Erst laufende Auto-Events abwarten." end` (or clear `staff(d).Auto` reservations explicitly). Low priority.

### A28 · LOW · data-integrity — ResetData leaves Staff migration and receipt history inconsistent
`ServerScriptService.Server.AdminService` ~Zeile 348 · Aufwand S
- **Problem:** ctx.Data.Profiles[t] = ctx.Data.NewProfile(t)
onJoin runs `pcall(ctx.Staff.Migrate, d)` after loading. ResetData does not. NewProfile also empties `Purchases`, the ProcessReceipt idempotency list, and resets `FreeVIPCase`.
- **Fix (gegengeprüft):** local old = ctx.Data.Profiles[t]; local nd = ctx.Data.NewProfile(t); if old then nd.Purchases = old.Purchases end; pcall(ctx.Staff.Migrate, nd); ctx.Data.Profiles[t] = nd  -- carrying FreeVIPCase over is optional (a design choice)

### A29 · LOW · security — Carry slowdown and all walking costs are enforced only by the client: the server never checks character movement
`ServerScriptService.Server.CarryService` ~Zeile 105 · Aufwand M
- **Problem:** CarryService.UpdateSpeed L97-105: `base = (G.BaseWalkSpeed - (G.BaseWalkSpeed - G.CarryWalkSpeed) * load) * (1 + (b.CarrySpeed or 0))` ... `hum.WalkSpeed = math.min(base, 40)`. This is the only place where the carry balance takes effect. The client owns its character's physics, so a WalkSpeed change made in a local script never replicates and the server never sees it. A CFrame teleport also replicates through the client-owned HumanoidRootPart …
- **Fix (gegengeprüft):** If anything is added, make it log-only first. Use a 1 Hz loop that measures horizontal displacement against max(hum.WalkSpeed, 16) * 2 * dt + 20. Reset the baseline in these cases:
- SeatPart is set, or the seat was left within the last 3 seconds (record s.SeatLeftAt from hum:GetPropertyChangedSignal('SeatPart')).
- s.AdminSpeed is set, or the AdminFly or AdminNoclip attribute is set.
- A server warp happened within the last 3 seconds (s.CharWarpAt).
- After a respawn.

On a violation, only increment s.CharFlags and warn(). Only consider rubberbanding with PivotTo after telemetry shows there are no false positives. Do not kick. Keep math.min(base, 40) and the existing distance checks (InteractService, PlacementService, ShowService); those checks are the actual security boundary.

### A30 · LOW · security — Location gate for cases and roadcases relies on the client-owned character position
`ServerScriptService.Server.CaseService` ~Zeile 65 · Aufwand M
- **Problem:** if not ctx.Interact.Near(p, "Case_" .. caseId, 90) then
InteractService.Near compares `hrp.Position`. The HRP is network-owned by the client, and AdminService's comment notes "der Server kennt keine Charakter-Speed-Checks".
- **Fix (gegengeprüft):** If the gate matters, keep a lightweight server-side character teleport check (as VehicleService does for trucks) or require a recent ProximityPrompt trigger at that scene: store `s.LastScene = {Id, At}` in the Interact handler and accept the purchase within N seconds.

### A31 · LOW · data-integrity — CaseService.OpenOwned decrements before validating the case id: an unknown or legacy id throws in roll() and the case is consumed
`ServerScriptService.Server.CaseService` ~Zeile 98 · Aufwand S
- **Problem:** if type(caseId) ~= "string" or (d.Cases[caseId] or 0) <= 0 then ... end
...
d.Cases[caseId] -= 1
local res, err = open(p, caseId)   -- roll -> CR.Roll -> `CR.Cases[caseId].Odds` errors if id unknown
RoadcaseService.OpenOwned validates `RC.Cases[caseId]` (L155). CaseService does not.
- **Fix (gegengeprüft):** if type(caseId) ~= "string" or not CR.Cases[caseId] or (d.Cases[caseId] or 0) <= 0 then return false, "Kein Case dieses Typs im Inventar." end

### A32 · LOW · data-integrity — Crew/Pet functions crash on an unknown pet type id in a save
`ServerScriptService.Server.CrewService` ~Zeile 106 · Aufwand S
- **Problem:** EquipBest: `table.insert(list, { uid, CrewR.RarityInfo[CrewR.Types[c.T].Rarity].Order, c.T })`. Recycle L133: `local r = CrewR.Types[c.T].Rarity` and L139 `CrewR.Types[c.T].Name`. DataService.Load (L104-114) reconciles and sanitizes numbers but never validates `d.Crew[*].T`.
- **Fix (gegengeprüft):** Apply the guards that were proposed. A safer alternative is to filter in DataService.Load: entries whose T is missing from CrewR.Types are left in d.Crew but kept out of d.Equipped. That way the save is not changed, and every caller that looks up CrewR.Types[c.T] is protected.

### A33 · LOW · data-integrity — At shutdown every player is saved twice at once (BindToClose SaveAll plus PlayerRemoving), which doubles writes against the 6 s per-key limit inside the 30 s budget
`ServerScriptService.Server.DataService` ~Zeile 187 · Aufwand M
- **Problem:** L187-189 `game:BindToClose(function() D.SaveAll(true) end)` saves every profile. When the server closes, players are kicked, which fires Main.onLeave L485 `ctx.Data.Save(p, true)` for the same keys at the same moment. The Admin 'Shutdown' command does the same: SaveAll, then a kick after 10 s. Each Save can retry 4 times with waits of 1.5/3/4.5 s. SaveAll only waits for its own `pending` counter (L175, 25 s cap), not for the onLeave saves.
- **Fix (gegengeprüft):** Dedupe inside D.Save so that every caller (autosave, SaveAll, onLeave, Admin) shares one in-flight write per player:

local inflight = {} -- [player] = {done=false, release=bool}
function D.Save(player, release)
  local cur = inflight[player]
  if cur then
    -- wait for the running write; if it did not release but we must, fall through and write again
    while not cur.done do task.wait(0.1) end
    if cur.release or not release then return cur.ok, cur.err end
  end
  local entry = {done=false, release=release}
  inflight[player] = entry
  local ok, err = <existing body of Save, with DeepCopy taken here>
  entry.ok, entry.err, entry.done = ok, err, true
  if inflight[player] == entry then inflight[player] = nil end
  return ok, err
end

With this in place, SaveAll's per-player task waits for the save onLeave already started instead of starting a second UpdateAsync, so SaveAll's …

### A34 · LOW · security — FastTravel checks the carry rule before its yields and never checks it again
`ServerScriptService.Server.FastTravel` ~Zeile 152 · Aufwand S
- **Problem:** L136 `if #ctx.Carry.List(p) > 0 then return false, { Key = "notify.travel.carry" } end`, then L144 `repeat task.wait(0.05) until not hum.SeatPart or ... > 0.8` and L149-151 `RequestStreamAroundAsync` plus `task.wait(rest)` (about 0.7 s), then L155 `ch:PivotTo(...)` with no second carry check. The header (L3) says the rule exists so players cannot 'Equipment am LKW vorbei zur Location tragen'.
- **Fix (gegengeprüft):** After L152 (`if not (ch.Parent and hrp.Parent and p.Parent) then return false end`), add: `if hum.Health <= 0 or #ctx.Carry.List(p) > 0 then return false, { Key = "notify.travel.carry" } end`. This is a consistency fix only, with no exploit impact.

### A35 · LOW · security — Spedition can be spammed: unbounded m.Deliveries, each firing region-wide truck FX to other players
`ServerScriptService.Server.JobService` ~Zeile 1683 · Aufwand S
- **Problem:** L1683-1686: `matKg = Validate.clampInt(arg.Kg, 0, free, free)` accepts Kg = 1. Every call appends at least one entry: `table.insert(m.Deliveries, { PickAt = pick, ... })` (L1723), with no cap. Minimum cost is `max(1, ceil(1/1000)) * PerTon` (1050) x 0.5 (Branch) x 0.7 (SpedDiscount 5x6 %) x 0.5 (FleetPass), about $184. Each delivery later triggers `ctx.Notify` (L1616, N == 1 for every booking), `FireClient SpedPickup`, and `ctx.FireRegion("FX", …
- **Fix (gegengeprüft):** Enforce a per-booking minimum instead of a small hard cap. After L1685, add `if matKg > 0 and matKg < math.min(free, 1000) then matKg = math.min(free, 1000) end`, which means at least 1 t or all the remaining material. Pricing already charges per started ton, so legitimate users pay the same. Optionally add a generous safety cap that counts the new trucks, such as `if #m.Deliveries + trucks > 40 then return false, "Es sind schon genug Sattelzüge unterwegs." end`, placed after `trucks` is computed and before Economy.Spend, so a single large legitimate booking is never rejected.

### A36 · LOW · data-integrity — Spedition truck split goes negative if equipment exceeds one semi (latent)
`ServerScriptService.Server.JobService` ~Zeile 1719 · Aufwand S
- **Problem:** `local load = math.min(SEMI - ((i == 1) and eqKg or 0), left)`. With eqKg > SEMI (24,000), truck 1 gets a negative Kg and `left` grows. SpedLoaded then runs `m.Depot = math.max(0, m.Depot - kg)` with kg < 0, which raises Depot above Total and Reserved, and Deliver lowers m.Venue below 0.
- **Fix (gegengeprüft):** `local load = math.min(math.max(0, SEMI - ((i == 1) and eqKg or 0)), left)`. Optionally spread eqKg across trucks with `eqLeft`.

### A37 · LOW · security — Proximity gates in the carry and build loop (rack prompt, Place 24 studs, Show start 80 studs) are satisfied by a teleported HRP
`ServerScriptService.Server.PlacementService` ~Zeile 224 · Aufwand S
- **Problem:** PlacementService.Place L222-224: `local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")` ... `if not hrp or ((hrp.Position - wpos) * Vector3.new(1, 0, 1)).Magnitude > 24 then return false, "Geh näher ran." end`. ShowService.Start L23-24 uses the same pattern: `(hrp.Position - job.StageCF.Position).Magnitude > 80`. The rack pickup in PlotService L470-477 is a hold-0 ProximityPrompt (`pr.MaxActivationDistance = 9`, …
- **Fix (gegengeprüft):** Add no per-gate logic. After adding the character watchdog, make the gates reject a position the watchdog has not confirmed. Add a helper `ctx.TrustedPos(p)` that returns s.CharLastCF.Position, the last position the watchdog accepted, and fall back to the HRP only right after a server warp. Use it in Place L224, Show.Start L24, Interact.Near L28-33 and the JobService L289 on-foot arrival instead of reading hrp.Position directly. That way a single-frame teleport cannot pass a gate before the next watchdog tick rolls it back.

### A38 · LOW · data-integrity — SellItem accepts the modular LED wall: the item is deleted while LEDLevel stays, so the wall is lost permanently
`ServerScriptService.Server.ShopService` ~Zeile 69 · Aufwand S
- **Problem:** local id = Validate.key(type(arg) == "table" and arg.Id or arg, R.Items)
local it = id and R.Items[id]
if not it or (d.Inventory[id] or 0) <= 0 then return false, "Nicht im Lager." end
...
d.Inventory[id] -= 1
There is no `it.Modular`/`it.Unique` check. BuyLED (L85-96) only re-adds `d.Inventory.PixelForge_LEDWall = 1` when `d.LEDLevel == 0`. The client hides the sell button for Modular items (ScreensShop L138-146), but the server does not …
- **Fix (gegengeprüft):** In S.SellItem, add `if it.Modular then return false, "Die LED-Wand kann nicht verkauft werden." end` directly after the `if not it or ...` line. Checking `it.Modular or it.Unique` also works, because the LED wall is the only item with either flag.

### A39 · LOW · security — VehicleSeat can be entered by touching it, which bypasses the 'nothing in hand' rule; the owner Occupant path does not check it
`ServerScriptService.Server.VehicleService` ~Zeile 166 · Aufwand S
- **Problem:** The carry check exists only in the prompt (L155 `if #ctx.Carry.List(plr) > 0 then ... return end`). The seat is a normal VehicleSeat (PrefabsVehicle L59-68, L114-115: CanCollide=false, but CanTouch and Disabled are not changed), so touching it seats the character. The Occupant handler L166-175 only rejects non-owners and then unanchors and gives network ownership to the owner.
- **Fix (gegengeprüft):** In the Occupant handler, after the owner check: `if #ctx.Carry.List(p) > 0 then occ.Sit = false; ctx.Notify(p, "Lade zuerst ein, was du trägst.", "Warn"); return end` (place it before `m.PrimaryPart.Anchored = false`). Optionally also set `seat.CanTouch = false` in the prefab; seat:Sit() still works when CanTouch is false.

### A40 · LOW · security — Truck network ownership is never handed back to the server when the driver gets out, so the empty truck stays under client physics
`ServerScriptService.Server.VehicleService` ~Zeile 176 · Aufwand S
- **Problem:** Occupant handler, L171-178:
```lua
m.PrimaryPart.Anchored = false
pcall(function() m.PrimaryPart:SetNetworkOwner(p) end)
ctx.Jobs.OnDrive(p, true)
else
	ctx.Jobs.OnDrive(p, false)
end
```
This is the only SetNetworkOwner call in runtime code. Nothing calls SetNetworkOwner(nil) or SetNetworkOwnershipAuto. The only thing that stops a client-owned empty truck is the watchdog at L46-49: `if root.AssemblyLinearVelocity.Magnitude < 2 then s.ParkTicks …
- **Fix (gegengeprüft):** In the Occupant `else` branch (L176), add before `ctx.Jobs.OnDrive(p, false)`:
```lua
local root = m.PrimaryPart
if root and root:IsDescendantOf(workspace) and not root.Anchored then
	pcall(function() root:SetNetworkOwner(nil) end)
end
```
Optional: in the rollback branch (L67-70), when `seat.Occupant == nil`, also call `pcall(function() root:SetNetworkOwner(nil) end)` before PivotTo. Do not anchor the truck there while someone is driving.
