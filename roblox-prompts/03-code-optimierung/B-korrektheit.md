# Befundliste Stufe B: Korrektheit (Bugs, Races, Memory-Leaks)

Quelle: Multi-Agent-Code-Audit von `Place1backup1_klein.rbxl` (Stand 04.10.2026). Jeder Befund wurde von mindestens einem unabhängigen Prüfer im Code gegengeprüft, kritische und hohe Befunde von zwei Prüfern.
- **Zeilennummern** beziehen sich auf diesen Stand. Suche im aktuellen Code nach dem zitierten Snippet, nicht nach der Zeilennummer.
- **Fix (gegengeprüft)** ist der vom Prüfer korrigierte Fix. Er hat Vorrang vor dem ursprünglichen Vorschlag.
- Die Befundtexte sind auf Englisch, die IDs (B01 …) dienen dem Status-Tracking in `ServerStorage.DevTools.PolishLog` (Block Z).

## Übersicht

| ID | Schwere | Datei | Titel |
|---|---|---|---|
| B01 | medium | CrewRegistry | Goldener Roadie-Drache is shown as '+250 % Speed', but the actual effect is +87.5 % walk s |
| B02 | medium | Main | GoHome is a second, unguarded teleport path that bypasses all FastTravel rules (streaming, |
| B03 | medium | AdminService | Admin commands fall back to the ADMIN when the selected target has left: ResetData/ClearIt |
| B04 | medium | InteractService | Portal handler uses `a and f() or g()` with a multi-value call: Goto's failure reason is d |
| B05 | medium | JobService | A rented LED wall is billed at the job's area but evaluated and weighed at the player's ow |
| B06 | medium | JobService | Cancel is allowed during Teardown, so ShowService's delayed Cleanup wipes the player's nex |
| B07 | medium | ShowService | S.Finish runs unprotected inside task.delay; any error leaves the job stuck in phase 'Show |
| B08 | medium | StaffService | Auto-event preview ignores equipment reserved by the running manual job (double-booking, r |
| B09 | medium | StaffService | Auto-event income path never calls CheckMilestones: players who level mostly through auto- |
| B10 | medium | VehicleService | Truck watchdog loop has no error protection and yields inside pairs(ctx.Sessions); one err |
| B11 | medium | Hatch | Hatch: when play() errors, its RenderStepped camera loop, pose loop, looping drum roll and |
| B12 | medium | ScreensShop | Company 'Profil' rename TextBox is wiped by State-triggered refreshes while typing |
| B13 | low | Util | U.Short produces '1000K' / '1000M' at unit boundaries; leaderstats Cash is a StringValue |
| B14 | low | WarehouseConfig | Outdoor storage level-2 text contradicts cumulative Storage values |
| B15 | low | WorldConfig | GetLayout/SizeFor index nil on an unknown venue or size instead of failing gracefully |
| B16 | low | Main | State push loop: FireClient and updateLeaderstats run outside the pcall, so one error ends |
| B17 | low | Main | AutoPreview failure is shown twice on the client |
| B18 | low | Main | Request router still accepts state-changing actions while a Plaza teleport is running, so  |
| B19 | low | Main | D.Temp entry leaks when a player leaves while Load ends on a Temp profile |
| B20 | low | Main | The Request router accepts actions before onJoin has finished (no plot, truck or passes ye |
| B21 | low | AdminService | Per-player tables are not cleared when the player leaves during join (admins, D.Temp) or e |
| B22 | low | AdminService | C.Pass toggles only the profile flag: Robux-owned passes report 'deaktiviert' but stay act |
| B23 | low | AdminService | C.Shutdown: duplicated saves, no join lock, can be scheduled multiple times |
| B24 | low | CrewWork | Crew and robot task streams are routed by the owner's current city, not by where the crew  |
| B25 | low | DataService | Rejoining the same server before the release save finishes can load stale data (own-JobId  |
| B26 | low | InteractService | InteractService.Points grows on every plot claim and is never pruned (memory leak of destr |
| B27 | low | InteractService | Interact.Scan calls kind:match on attributes without a type check; one non-string attribut |
| B28 | low | JobService | Tenders are generated and announced on the Trading Plaza server where they cannot be accep |
| B29 | low | JobService | Tender cleanup loop has no pcall: if CleanupTenders/BroadcastTenders throws once, expired  |
| B30 | low | JobService | AutoCrew delayed AutoPack checks s.Job, not the job it was scheduled for |
| B31 | low | JobService | An error inside startJob leaves the tender permanently Taken |
| B32 | low | JobService | ReturnCarried re-adds staging entries without Slot/Rent info |
| B33 | low | JobService | ForcePack while crew items are in flight duplicates cargo |
| B34 | low | JobService | S.Unload stops at the first needed item that is not on board, even if other same-phase ite |
| B35 | low | PlazaService | plazaCode is a non-atomic read-modify-write on MemoryStore: concurrent main servers reserv |
| B36 | low | PlazaService | Plaza Region attribute is immediately overwritten with 'Neustadt' by Main.onJoin |
| B37 | low | PlotService | P.Claim indexes the session without a nil check (player left during the gamepass checks) |
| B38 | low | PlotService | Rack prompts are created for everyone but work only for the owner |
| B39 | low | RoadcaseService | Roadcase storage check counts 1 slot per item, but exclusive items can occupy 2 slots: cap |
| B40 | low | ShopService | BuyLED skips the storage check although the LED wall occupies 2 slots |
| B41 | low | ShopService | Shop.Rename: byte-length check, no filter cooldown, profile accessed after yield |
| B42 | low | ShowService | Tender condition percentages are truncated with %d: Premium shows +39 % instead of +40 % |
| B43 | low | StaffService | Auto-event XP skips XPMult (2x XP pass, XP pets/skills) while its cash uses CashMult and D |
| B44 | low | TradeService | Pet Lock is only checked when offered, not at execution: locking an offered pet during the |
| B45 | low | TradeService | Traded pets are not marked as discovered for the receiver (CrewFound): a received Secret s |
| B46 | low | TradeService | Trade loop thread has no pcall: one error permanently stops all trades, countdowns and tab |
| B47 | low | VehicleService | HighwayTrigger debounce table keeps Player references forever |
| B48 | low | VehicleService | Anti-teleport rollback restores PrimaryPart.CFrame through PivotTo; the truck's PivotOffse |
| B49 | low | VehicleService | ReturnHome ejects the driver with a fixed 0.1 s wait and does not confirm the weld is gone |
| B50 | low | VehicleService | Two Travel calls overlapping the 0.9 s yield both pass the highway check |
| B51 | low | Ambient | Day/night grading and ShowDirector both write Lighting.ExposureCompensation; daytime expos |
| B52 | low | Ambient | Ambient.apply iterates windows/lights with pairs() across yields while DescendantAdded ins |
| B53 | low | Ambient | Windmill rotors: PivotTo every frame within 1800 studs, and the non-atomic rotor model can |
| B54 | low | Ambient | Ambient.Init yields during synchronous client boot; later modules start late and CrewDirec |
| B55 | low | CrewDirector | CrewDirector propCache keeps every stack template forever (unbounded keys) |
| B56 | low | CrewDirector | Client subsystems shut down permanently after a few errors |
| B57 | low | Effects | vehCache keeps destroyed vehicle models alive (strong keys) |
| B58 | low | Effects | Spedition truck: cargo-door offset is computed before the model is moved, so the door is a |
| B59 | low | Effects | GPS arrow is never hidden near the goal and freezes in place (and/or bug; fix 'Polish D' i |
| B60 | low | HUD | HUD tracker action buttons ignore their disabled state |
| B61 | low | Pets | Pets Heartbeat step is not pcall-guarded and indexes workspace.World directly |
| B62 | low | Prompts | Custom prompt UI shows a stale ActionText/ObjectText (Ghosts change ActionText while the p |
| B63 | low | Robots | Robots: idle position is set only once, so shuttles stay stranded after a missed return ta |
| B64 | low | ScreensJobs | Packliste tiles reorder randomly on every rebuild |
| B65 | low | ScreensJobs | Auto-Event list offers jobs the server always rejects, and the estimate uses a different m |
| B66 | low | Traffic | Spawn and visibility distances exceed the streaming MinRadius (224), so cars, robots and c |
| B67 | low | Traffic | Heartbeat error counters never reset; a few transient errors disable the system for the se |
| B68 | low | UI | Esc handler ignores gameProcessedEvent |
| B69 | low | UI | Window builders are not pcall-protected and several index State.Data without a nil check |
| B70 | low | UI | Scroll restore is keyed by ScrollingFrame.Name, but several scrolls share the default name |
| B71 | low | UI | Closed windows keep their full UI tree (model clones, spinning viewports) alive until reop |

## Details

### B01 · MEDIUM · correctness — Goldener Roadie-Drache is shown as '+250 % Speed', but the actual effect is +87.5 % walk speed (capped at 40) and +37.5 % crew speed
`ReplicatedStorage.Modules.CrewRegistry` ~Zeile 39 · Aufwand S
- **Problem:** GoldenRoadie = { ..., Bonus = { Speed = 2.5, ... }, Desc = "+250 % Speed, unendliche Tragkraft, goldener Trail" }
CarryService L104: `base *= 1 + (b.Speed or 0) * 0.35 + ...; hum.WalkSpeed = math.min(base, 40)`, so 2.5 × 0.35 = +87.5 %. CrewWork L43: `1 + (b.Speed or 0) * 0.15`, so +37.5 %. ScreensCrew L32 also prints `"+" .. math.floor(b.Speed * 100) .. "% Speed"`, which shows +250 %.
- **Auswirkung:** The UI states a buff 3× larger than the real effect, on the rarest pet. That pet is pursued with paid Luck/SecretFinder passes, so the gap is a player-trust and paid-random-item disclosure problem.
- **Fix (gegengeprüft):** Add to CrewRegistry: `C.SpeedWalkFactor = 0.35; C.SpeedCrewFactor = 0.15`. Use them in CarryService L104 (`(b.Speed or 0) * Crew.SpeedWalkFactor`) and CrewWork L43 (`(b.Speed or 0) * Crew.SpeedCrewFactor`). Change GoldenRoadie.Desc to "+87 % Lauftempo, +37 % Crew-Tempo, unendliche Tragkraft, goldener Trail". Replace ScreensCrew L32 with two entries: `"+" .. math.floor(b.Speed * Crew.SpeedWalkFactor * 100) .. "% Lauftempo"` and `"+" .. math.floor(b.Speed * Crew.SpeedCrewFactor * 100) .. "% Crew-Tempo"`. Optionally note that walk speed is capped at 40. The numeric values stay the same.

### B02 · MEDIUM · correctness — GoHome is a second, unguarded teleport path that bypasses all FastTravel rules (streaming, carry check, cooldown, Teleporting lock)
`ServerScriptService.Main` ~Zeile 269 · Aufwand S
- **Problem:** H.GoHome = function(p)
	local ch = p.Character
	if ch and ctx.Plots.Get(p) then
		local hum = ...
		if hum and hum.SeatPart then return false, "Steig zuerst aus." end
		ch:PivotTo(ctx.Plots.SpawnCF(p))
Compare FastTravel.Go (FastTravel L124-160), which handles Kind == "Home" (L87-90) with: Teleporting attribute check, health check, 3 s COOLDOWN, `#ctx.Carry.List(p) > 0` -> "notify.travel.carry", pcall(p.RequestStreamAroundAsync, p, pos, 3), zeroing velocities, setting the Region attribute and Stats.FastTravels. The client still uses GoHome: ScreensShop L196 `State.Request("GoHome")`. StreamingEnabled=1 in the place file (StreamingMinRadius 64), so PivotTo onto an unstreamed plot lets the client-owned character fall through.
- **Auswirkung:** Players can teleport while carrying equipment and without cooldown, and may fall through the world at the plot. Region stays stale (for example "Portavia" while standing in Neustadt), and the admin overview and FireRegion fallbacks then report the wrong city.
- **Fix (gegengeprüft):** In ServerScriptService.Main.Script.lua, replace L269-277 with:
H.GoHome = function(p) return ctx.FastTravel.Go(p, { Kind = "Home" }) end
The client already handles the { Key = ... } error tables that F.Go returns, because the TravelTo path uses them. Keep GoHome = true in PLAZA_BLOCK; F.Go also checks Plaza.IsPlaza.

### B03 · MEDIUM · correctness — Admin commands fall back to the ADMIN when the selected target has left: ResetData/ClearItems/Kill etc. hit the admin's own profile
`ServerScriptService.Server.AdminService` ~Zeile 63 · Aufwand S
- **Problem:** local function target(p, a)
	local uid = tonumber(a.Target)
	local t = (uid and Players:GetPlayerByUserId(uid)) or p
Client ScreensAdmin.act(): `if args.Target == nil then args.Target = sel end` — `sel` keeps the UserId of the selected player after that player leaves. GetPlayerByUserId then returns nil and `or p` makes the admin the target.
- **Auswirkung:** An admin selects a player, the player leaves, and the admin clicks "Spielstand zurücksetzen". C.ResetData then runs `ctx.Data.Profiles[t] = ctx.Data.NewProfile(t)` on the admin, and the autosave writes the wiped profile. ClearItems, Cash -N, SetLevel, Kill, FreezePlayer, Invisible and the rest silently apply to the admin too. The command reports success with the admin's own DisplayName.
- **Fix (gegengeprüft):** Change `target` in AdminService (L61-67) so it falls back to the caller only when no Target was sent at all. It should also reject a Target that is not a number instead of silently using the caller:

local function target(p, a)
	local t = p
	if a.Target ~= nil then
		local uid = tonumber(a.Target)
		t = uid and Players:GetPlayerByUserId(uid) or nil
		if not t then error("Ziel-Spieler ist nicht mehr auf dem Server.", 0) end
	end
	local d = ctx.Data.Profiles[t]
	if not d then error("Profil des Ziel-Spielers ist nicht geladen.", 0) end
	return t, d, ctx.Sessions[t]
end

Optional client hardening: in ScreensAdmin act(), if `data` has no entry for `sel`, show a toast and stop instead of sending the request. Calling selected() first is not enough, because it silently switches to the admin.

### B04 · MEDIUM · correctness — Portal handler uses `a and f() or g()` with a multi-value call: Goto's failure reason is dropped and Return() runs as a fallback
`ServerScriptService.Server.InteractService` ~Zeile 85 · Aufwand S
- **Problem:** L85 `local ok, why = (kind == "Plaza") and ctx.Plaza.Goto(p) or ctx.Plaza.Return(p)`; L86 `if not ok and why then ctx.Notify(p, why, "Warn") end`. The and/or expression truncates to one value, so `why` is always nil (luau-lsp: UnbalancedAssignment L85, UninitializedLocal L86). When Goto returns false ("Beende oder brich erst deinen Auftrag ab.", "Ohne gespeichertes Profil ...", "Trading Plaza gerade nicht erreichbar", "Teleport laeuft schon"), the `or` branch also calls ctx.Plaza.Return(p).
- **Auswirkung:** When a player presses the Plaza portal and the teleport is refused, nothing visible happens and they get no explanation. Return() is called by mistake. It is currently harmless only because Return returns early outside the Plaza.
- **Fix (gegengeprüft):** local ok, why
if kind == "Plaza" then ok, why = ctx.Plaza.Goto(p) else ok, why = ctx.Plaza.Return(p) end
if not ok and why then ctx.Notify(p, why, "Warn") end

### B05 · MEDIUM · correctness — A rented LED wall is billed at the job's area but evaluated and weighed at the player's own LED level (0 m² for players without a wall)
`ServerScriptService.Server.JobService` ~Zeile 418 · Aufwand M
- **Problem:** Quote L418-419: `if t == "LEDWall" then rent += 2000 * (job.LED or 4) * n`. startJob L557 assigns the rented `"PixelForge_LEDWall"`. JobLogic J.Evaluate L150: `if it.Modular then l += J.LEDArea(ledLevel) * R.LEDWall.LightPerM2 end`, and J.Load L128-131 uses the same value. ShowService L39 evaluates with `d.LEDLevel`. DataService sets `LEDLevel = 0` by default, and `R.LEDWall.Sizes[0]` is nil, so LEDArea is 0.
- **Auswirkung:** Players without an LED wall, or with one smaller than job.LED (the reason it was rented), pay 2000 x job.LED (for example $50k for 25 m²). The rented wall then adds 0 light (or only their small wall's light), so it does nothing for the stars. Truck weight and volume are also understated.
- **Fix (gegengeprüft):** 1. Add an optional last parameter `ledArea` to J.Evaluate and J.Load: `local a = ledArea or J.LEDArea(ledLevel)`. Use it in place of the direct `J.LEDArea(ledLevel)` calls. Existing callers keep working unchanged.

2. In S.Plan and S.Quote, compute the effective area once:
`local ledA = (missing.LEDWall and job.LED) and math.max(J.LEDArea(d.LEDLevel), job.LED) or nil`
Pass `ledA` to every J.Load and J.Evaluate call there (L374, L387, L432, L433, L445).

3. In startJob, after building `rent`, find the LEDWall slot and store the area on the per-session job table: `JobRec.LEDArea = math.max(J.LEDArea(d.LEDLevel), job.LED or 0)` when that slot was rented. This table is not saved, so save data is unaffected.

4. Use `job.LEDArea` in these places:
- ShowService L39: `J.Evaluate(job.Def, ids, bonus, d.LEDLevel, job.LEDArea)`
- The J.Load calls at JobService L629, L1180-1181 and L1687
- AdminService L433
- Optionally, PlacementService L143, to pick the `LED_<n>` model whose Area >= job.LED.

5. Apply the same override in the StaffService L192-198 auto-job path if it evaluates or loads the LED wall.

None of this changes rent prices or balancing.

### B06 · MEDIUM · correctness — Cancel is allowed during Teardown, so ShowService's delayed Cleanup wipes the player's next (already paid) job
`ServerScriptService.Server.JobService` ~Zeile 772 · Aufwand S
- **Problem:** JobService L768-776: `function S.Cancel(p) ... if job.Phase == "Show" then return false, "Die Show läuft gerade!" end S.Cleanup(p)`. Only "Show" is blocked. ShowService.Finish sets `job.Phase = "Teardown"`, then `task.wait(dur)` and then calls `ctx.Jobs.Cleanup(p)` (ShowService L101-112). S.Cleanup (L779-803) does not check which job it is cleaning: `local job = s and s.Job ... s.Job = nil`.
- **Auswirkung:** The reward is paid before Teardown starts, so cancelling then costs nothing. If a player clicks Cancel during teardown and accepts a new job within `dur` seconds (rent already charged through Economy.Spend), ShowService's Cleanup destroys the new job: the rent is lost and the stage, staging and yards are torn down. For a tour, the next stop still starts after the cancel.
- **Fix (gegengeprüft):** 1) JobService S.Cancel: `if job.Phase == "Show" or job.Phase == "Teardown" or job.Finished then return false, "Die Show läuft gerade!" end`
2) Make Cleanup identity-safe: `function S.Cleanup(p, expected) local s = ctx.Sessions[p]; local job = s and s.Job; if not job or (expected ~= nil and job ~= expected) then return end ...`
3) In ShowService.Finish after `task.wait(dur)`: `local s2 = ctx.Sessions[p]; if not s2 or not ctx.Data.Profiles[p] or p.Parent == nil then return end; local stillOurs = (s2.Job == job); ctx.Jobs.Cleanup(p, job); if not stillOurs then ctx.Push(p) return end`. Only then continue with tour progression and rewards, and re-read `d = ctx.Data.Profiles[p]` instead of using the stale `d` from before the yield.
This keeps behaviour the same for the normal path, needs no save-data change, and also protects against admin C.CancelJob/C.StartJob calling Cleanup mid-teardown.

### B07 · MEDIUM · correctness — S.Finish runs unprotected inside task.delay; any error leaves the job stuck in phase 'Show', which Cancel refuses
`ServerScriptService.Server.ShowService` ~Zeile 49 · Aufwand S
- **Problem:** L49-51 `task.delay(dur, function() S.Finish(p, job) end)`. Finish sets `job.Finished = true` (L58) and then calls J.Payout, Economy.Reward, FireClient, Broadcast and `ctx.Rewards.CheckMilestones(p)` (L100) before `job.Phase = "Teardown"` (L101). Only CrewWork.Teardown is wrapped in pcall (L103). JobService.Cancel L773: `if job.Phase == "Show" then return false, "Die Show läuft gerade!" end`.
- **Auswirkung:** If anything between L59 and L100 errors (bad Def data, a milestone bug, a nil field on a generated tender), the player stays in 'Show' forever. They cannot cancel, Finish will not run again (Finished=true), and they cannot accept new jobs until they rejoin.
- **Fix (gegengeprüft):** Rename the existing body to a local `finishImpl(p, job)`. Then define:

```lua
function S.Finish(p, job)
  local ok, err = pcall(finishImpl, p, job)
  if not ok then
    warn("[Show] Finish: " .. tostring(err))
    local s = ctx.Sessions[p]
    if s and s.Job == job then
      pcall(ctx.Jobs.Cleanup, p)
    end
  end
end
```

pcall can yield in Luau, so the `task.wait(dur)` inside still works. This covers both the task.delay caller (L49) and AdminService L437. A lighter alternative is to set `job.Phase = "Teardown"` right after `job.Finished = true` so Cancel is no longer blocked. Do not do that: it would let a player Cancel during the payout window.

### B08 · MEDIUM · correctness — Auto-event preview ignores equipment reserved by the running manual job (double-booking, rent avoidance)
`ServerScriptService.Server.StaffService` ~Zeile 191 · Aufwand S
- **Problem:** `function S.FreeInventory(p) local d = ... local res = S.Reserved(p) if next(res) == nil then return d.Inventory end ...` only subtracts Auto-event reservations. S.Preview (L191-192) uses it: `local inv = S.FreeInventory(p) local assign, missing = J.Assign(job, inv, d.LEDLevel)`. The manual job reserves its own pieces in `s.Job.Reserved` (JobService L565 `reserved[id] = (reserved[id] or 0) + 1`, stored L596), and only JobService.Reserved (L513-520) sums both.
- **Auswirkung:** While a manual job is packing or driving, a player with a Lead/Office can start an auto-event that 'uses' the same physical cases and LED wall. Those pieces count as owned, so the rent is not charged (Preview L196-199) and the same equipment is reserved twice. That is an economy exploit through normal play.
- **Fix (gegengeprüft):** In S.Preview, replace `local inv = S.FreeInventory(p)` with:
local res = ctx.Jobs.Reserved(p) -- manual job + auto-events
local inv = {}
for id, n in pairs(d.Inventory) do local free = n - (res[id] or 0) if free > 0 then inv[id] = free end end
Leave S.FreeInventory unchanged for JobService.Plan.

### B09 · MEDIUM · correctness — Auto-event income path never calls CheckMilestones: players who level mostly through auto-events get their milestone rewards late
`ServerScriptService.Server.StaffService` ~Zeile 291 · Aufwand S
- **Problem:** StaffService.Collect L287-298:
```
for _, e in ipairs(st.Pending) do
  ctx.Economy.AddCash(p, e.Net)
  ctx.Economy.AddXP(p, e.XP)
  d.Stats.Events = (d.Stats.Events or 0) + 1
  ...
end
...
st.Pending = {}
ctx.Push(p)
```
RewardService.CheckMilestones (L60-71) is the only code that grants G.Milestones (5/20/50/100/250 Events -> cash, tokens, TouringMaster/VIPBlack cases), and it reads `d.Stats.Events`. A grep shows one caller only: ShowService.Finish L100 (`ctx.Rewards.CheckMilestones(p)`), after a manual show. Collect runs from the CollectStaff remote and automatically from S.Tick (L275-277) whenever an Office worker is hired. So a player whose Events count crosses 5/20/50/... through auto-events sees the counter move in the Firma > Statistik screen (ScreensShop L290), but gets no milestone until the next manual show, and only if they still play manually. The other ShowService.Finish hooks do not apply to auto-events: they have no stars (Perfect, Stars), no tender and no tour, and there is no quest system. JobService.CollectDispatch (L1834) does not increment Stats.Events at all, so …
- **Auswirkung:** Milestone rewards (up to 250 tokens plus VIPBlack cases) are withheld from AFK/staff-driven players, possibly for a whole session or forever. Several thresholds then fire at once in one burst.
- **Fix (gegengeprüft):** In S.Collect, after `st.Pending = {}` and before `ctx.Push(p)`, add `ctx.Rewards.CheckMilestones(p)`. ShowService already calls it without pcall, so a pcall is optional. If you keep the pcall, log the error rather than swallowing it silently.

### B10 · MEDIUM · correctness — Truck watchdog loop has no error protection and yields inside pairs(ctx.Sessions); one error stops parking, fall rescue and anti-teleport for the whole server
`ServerScriptService.Server.VehicleService` ~Zeile 37 · Aufwand S
- **Problem:** L37-82: `task.spawn(function() while true do task.wait(1) for p, s in pairs(ctx.Sessions) do ... if root.Position.Y < -60 then S.ReturnHome(p, true) else ...` with no pcall anywhere in the loop. ReturnHome yields (L239 `task.wait(0.1)`) and then indexes without a re-check (L240 `s.Truck.PrimaryPart.Anchored = true`). If the player leaves during that 0.1 s, onLeave -> Despawn (Main L480) sets s.Truck = nil, so L240 throws 'attempt to index nil'. Because the loop is not protected, the thread dies. The yield also happens in the middle of a `pairs` traversal of ctx.Sessions while onJoin/onLeave add and remove keys (Main L424/L490). If a removal and a rehash happen together, `next` can raise 'invalid key to next'. Compare JobService.Init L244-247, which wraps each tick in pcall.
- **Auswirkung:** After one bad tick (for example a truck falls off the map and its owner leaves), no truck on the server is anchored when parked, rescued after falling, or checked for teleport/speed exploits until the server restarts. Nothing is logged after the first warn.
- **Fix (gegengeprüft):** In the watchdog loop (L37-82), iterate over a snapshot and protect each entry:

```lua
local list = {}
for p, s in pairs(ctx.Sessions) do list[#list+1] = {p, s} end
for _, e in ipairs(list) do
	local ok, err = pcall(tick, e[1], e[2])
	if not ok then warn("[Vehicles] watchdog: " .. tostring(err)) end
end
```

`tick` is the existing per-entry body moved into a local function. In that body, replace `S.ReturnHome(p, true)` with `task.spawn(S.ReturnHome, p, true)` so the loop never yields.

In ReturnHome, replace L240-241 (the lines right after `task.wait(0.1)`) with a fresh check before touching the truck:

```lua
local t = s.Truck
if ctx.Sessions[p] ~= s or not ctx.Data.Profiles[p] or not t or not t.Parent or not t.PrimaryPart then
	return false
end
t.PrimaryPart.Anchored = true
t:PivotTo(homeCF(p, S.Def(p), t))
```

### B11 · MEDIUM · memory-leak — Hatch: when play() errors, its RenderStepped camera loop, pose loop, looping drum roll and result card are never cleaned up
`StarterPlayer.StarterPlayerScripts.Client.Hatch` ~Zeile 299 · Aufwand S
- **Problem:** play() creates `local conn = RunService.RenderStepped:Connect(function(dt) ... cam.CFrame = CFrame.lookAt(C.Pos + sh, C.Look) ...)` (L299-329), `local roll = Snd.Play(Snd.DrumRoll, 0.55); if roll then roll.Looped = true end` (L336-337), `local poseConn = RunService.Heartbeat:Connect(...)` (L473) and `card = UI.Panel(UI.Overlay, ...)` (L505/530). Only close() (L541-553) disconnects or destroys them. The error path in start() (L562-573) only does `hs:Destroy()`, destroys the ColorCorrectionEffect and sets `cam.CameraType = Enum.CameraType.Custom`. conn, poseConn, roll and card are locals of play(), so the handler cannot reach them. Any error after L299 leaves them running, for example from `RA.New("Crew_" .. c.Res.Type, stage)` (L454), `R.TypeName(it.Type)` (L279), itemProp, or UI calls. The wrapper exists precisely because errors are expected here.
- **Auswirkung:** The camera keeps getting forced to the hatch stage position every frame and fights the Custom camera, so the player is effectively camera-locked until they rejoin. A Looped drum roll plays until Sounds' 15 s auto-destroy, the pose Heartbeat runs forever, and a card can stay on screen. This breaks the game for the affected player.
- **Fix (gegengeprüft):** Add at module level: `local session = nil` and
```lua
local function cleanupSession()
	local s = session
	if not s then return end
	session = nil
	s.Closed = true
	for _, c in ipairs(s.Conns) do pcall(function() c:Disconnect() end) end
	for _, i in ipairs(s.Inst) do pcall(function() i:Destroy() end) end
	local cam = workspace.CurrentCamera
	if cam then cam.CameraType = (s.OldType == Enum.CameraType.Scriptable) and Enum.CameraType.Custom or s.OldType end
end
```
In play():
- After `local oldType = cam.CameraType`, add `session = { Conns = {}, Inst = {}, OldType = oldType, Closed = false }; local mySession = session`.
- After `cc.Parent = cam`, add `table.insert(mySession.Inst, cc)`.
- Right after `local conn = RunService.RenderStepped:Connect(...)`, add `table.insert(mySession.Conns, conn)`.
- After `if roll then roll.Looped = true end`, add `if roll then table.insert(mySession.Inst, roll) end`.
- After `local poseConn = ...`, add `table.insert(mySession.Conns, poseConn)`.
- After each `card = UI.Panel(...)`, add `table.insert(mySession.Inst, card)`.
- In close(), keep `if closed then return end; closed = true`, then call `if session == mySession then cleanupSession() end` before `stage:Destroy()`. Keep the existing explicit destroys (they are idempotent) and the existing busy/queue handling.

In start()'s error branch, call `cleanupSession()` first, after `warn(...)`, then keep the existing HatchStage/ColorCorrection/camera fallback lines. Since cleanupSession already restores oldType, the hard `Custom` line can stay as a fallback for errors before the session exists. The fix doesn't change behaviour on the success path and doesn't touch save data.

### B12 · MEDIUM · correctness — Company 'Profil' rename TextBox is wiped by State-triggered refreshes while typing
`StarterPlayer.StarterPlayerScripts.Client.ScreensShop` ~Zeile 281 · Aufwand S
- **Problem:** `local box = new("TextBox", { Text = s.CompanyName, ... })` sits inside the Company builder, and ClientMain L64-67 includes `Company = true` in `refreshable`: `State.Changed:Connect(function() if UI.Current and refreshable[UI.Current.Id] then UI.Refresh(UI.Current.Id) end end)`. refreshNow destroys all Content children (UI L363).
- **Auswirkung:** Any State push while the player is typing a company name (cash from dispatch, auto-events, staff, job progress) destroys the TextBox. The typed text and focus are lost and the box resets to the old name. Staff, Skills and the other refreshable windows also lose transient state such as the armed reset button.
- **Fix (gegengeprüft):** 1) UI.ModuleScript refreshNow: right after `if w and UI.Current == w and w.Builder then`, add `local tb = game:GetService("UserInputService"):GetFocusedTextBox(); if tb and tb:IsDescendantOf(w.Content) then UI.Refresh(id) return end`. This postpones the rebuild while the player is typing, and UI.Refresh re-arms the 0.25s debounce.
2) ScreensShop: add a module-level `local companyDraft = nil`. Create the box with `Text = companyDraft or s.CompanyName`, then add `box:GetPropertyChangedSignal("Text"):Connect(function() companyDraft = box.Text end)`. In the Umbenennen callback, call `State.Request("Rename", box.Text)` and then set `companyDraft = nil`. Also reset the draft to nil when the Company window opens (UI.OnOpen) so an old draft does not come back later.

### B13 · LOW · correctness — U.Short produces '1000K' / '1000M' at unit boundaries; leaderstats Cash is a StringValue
`ReplicatedStorage.Modules.Util` ~Zeile 17 · Aufwand S
- **Problem:** L16-17: for 999,960..999,999 `a >= 1e6` is false, so `string.format("%.1fK", n/1e3)` gives "1000.0K" and the gsub turns it into "1000K". The same happens for M at 999,995,000+ ("1000.00M" -> "1000M"). Main L439 also creates `Instance.new("StringValue")` for leaderstats Cash with "$"..short(), so the player list sorts lexicographically ("$9.5K" ranks above "$1.2M").
- **Fix (gegengeprüft):** Compare against rounded thresholds: `if a >= 999.995e6 then` for the B branch, `if a >= 999.95e3 then` for the M branch, and keep the K branch at 1e4. A hidden numeric leaderstat for sorting is optional. Replacing Cash with an IntValue would change how the value is shown in the player list.

### B14 · LOW · correctness — Outdoor storage level-2 text contradicts cumulative Storage values
`ReplicatedStorage.Modules.WarehouseConfig` ~Zeile 41 · Aufwand S
- **Problem:** `{ Price = 90000, ..., Desc = "Vordach • +150 Plätze (Paletten)", Storage = 150 }, { Price = 250000, ..., Desc = "Großes Vordach • +350 Plätze (Paletten)", Storage = 350 }`. WC.Stat takes the current level's value (cumulative, as the Racks comment at L18 says), so level 2 adds +200 over level 1. The Racks descriptions state per-step increments.
- **Fix (gegengeprüft):** Text only: Desc = "Großes Vordach • +200 Plätze (gesamt 350, Paletten)"

### B15 · LOW · correctness — GetLayout/SizeFor index nil on an unknown venue or size instead of failing gracefully
`ReplicatedStorage.Modules.WorldConfig` ~Zeile 420 · Aufwand S
- **Problem:** local v = W.Venues[venueId]; local L = {}; local indoor = v.Layout == "Indoor" -- errors if v is nil
W.SizeFor L598: `if W.StageSizes[size].Rank > W.StageSizes[cap].Rank` -- errors if job.Size is not S/M/L/XL. The client calls W.GetLayout(job.Venue, job.Size) (Ghosts L107) with state pushed from the server.
- **Fix (gegengeprüft):** GetLayout: add `if not v then warn('[WorldConfig] unknown venue', venueId); return {} end` after the venue lookup, and do not cache that result. SizeFor: `if not W.StageSizes[size] then size = 'S' end` before the comparison, plus `if not W.StageSizes[cap] then cap = 'L' end`. Also use `job.Groups or {}` in the ipairs loop.

### B16 · LOW · correctness — State push loop: FireClient and updateLeaderstats run outside the pcall, so one error ends State sync for every player
`ServerScriptService.Main` ~Zeile 185 · Aufwand S
- **Problem:** L174-197: `task.spawn(function() while true do task.wait(0.2) for p in pairs(dirty) do dirty[p] = nil ... local ok, snap = pcall(snapshot, p) ... local okJ, json = pcall(HttpService.JSONEncode, HttpService, snap) ... if not okJ or json ~= lastSnapJson[p] then ... Net.Get("State"):FireClient(p, snap) updateLeaderstats(p) end`. Only snapshot() and JSONEncode are protected. `Net.Get("State")` (a WaitForChild lookup), `FireClient`, and …
- **Fix (gegengeprüft):** Move the existing per-player body (snapshot, encode, compare, FireClient, updateLeaderstats) into a local `pushOne(p)` and call `local ok, err = pcall(pushOne, p); if not ok then warn("[Main] State-Push " .. p.Name .. ": " .. tostring(err)) end` inside the `if p.Parent and ctx.Data.Profiles[p]` block. In updateLeaderstats, use `local c = ls:FindFirstChild("Cash"); if c then c.Value = "$" .. short(d.Cash) end` and do the same for Level. For consistency, also change Economy L119 to use FindFirstChild. Payload and behaviour stay the same.

### B17 · LOW · correctness — AutoPreview failure is shown twice on the client
`ServerScriptService.Main` ~Zeile 266 · Aufwand S
- **Problem:** Main H.AutoPreview L266 returns `false, why`. ScreensJobs L730-731 `local ok, pv = State.Request("AutoPreview", { Job = job.Id })` (not silent, so State.Request L32-33 already toasts `b`), then `if not ok then UI.Toast(tostring(pv), "Warn") return end` toasts the same message again. On success the handler also breaks the router's (ok, msg, data) convention by putting the data table in slot 2.
- **Fix (gegengeprüft):** Main L264-268: `if not pv then return false, why end; return true, nil, pv`. ScreensJobs L730-731: `local ok, _, pv = State.Request("AutoPreview", { Job = job.Id })` / `if not ok or type(pv) ~= "table" then return end`. Drop the second toast, because State.Request already shows `why`. This also fixes the bogus toast of the table on success and the "nil" toast when the call is rate-limited.

### B18 · LOW · race-condition — Request router still accepts state-changing actions while a Plaza teleport is running, so a job or spedition started in that window is lost along with its upfront rent and costs
`ServerScriptService.Main` ~Zeile 309 · Aufwand S
- **Problem:** Main.lua:307-310 only gates on the Plaza server:
`if ctx.Plaza.IsPlaza and PLAZA_BLOCK[action] then return false, ... end` and has no `p:GetAttribute("Teleporting")` check anywhere in the router (grep: 'Teleporting' only appears in FastTravel.lua:129 and PlazaService.lua).
PlazaService.Goto (L142-165) checks `if s and s.Job then return false ...` once, then `p:SetAttribute("Teleporting", true)`, and in a task.spawn runs `pcall(ctx.Data.Save, p, …
- **Fix (gegengeprüft):** In the router after the profile and Plaza checks (Main.lua ~L309), add a block list rather than an allow list. That way pure getters and settings keep working and the teleport UI doesn't break:
`local TELEPORT_BLOCK = { AcceptJob=true, AcceptTender=true, StartTour=true, Spedition=true, SelectVehicle=true, GoHome=true, Travel=true, BuyModule=true, Place=true, Dispatch=true, StartAuto=true }` (plus Trade* actions)
`if p:GetAttribute("Teleporting") and TELEPORT_BLOCK[action] then return false, "Teleport läuft …" end`

Optionally, for defence in depth, add the same attribute check at the top of the JobService start-job path (the `startJob` helper behind H.AcceptJob/AcceptTender/StartTour, per the claim). Attribute clearing on failure already exists (PlazaService L160/L179/L190).

### B19 · LOW · memory-leak — D.Temp entry leaks when a player leaves while Load ends on a Temp profile
`ServerScriptService.Main` ~Zeile 449 · Aufwand S
- **Problem:** DataService.Load sets `D.Temp[player] = true` on failure or lock-timeout paths (L89, L93, L101). In Main L449-453 `if not p.Parent then pcall(ctx.Data.ReleaseLock, p) ctx.Sessions[p] = nil return end` the function returns without clearing ctx.Data.Temp[p]. onLeave already ran earlier, while Profiles[p] was nil, so nothing else clears it.
- **Fix (gegengeprüft):** Add `ctx.Data.Temp[p] = nil` in that early-return branch.

### B20 · LOW · race-condition — The Request router accepts actions before onJoin has finished (no plot, truck or passes yet)
`ServerScriptService.Main` ~Zeile 455 · Aufwand S
- **Problem:** The router only checks `if not ctx.Data.Profiles[p] then return false, "Profil lädt noch …" end`. onJoin sets `ctx.Data.Profiles[p] = d` (L455) and only afterwards calls `ctx.Monetization.Join(p)` (L457). That function yields once per pass via UserOwnsGamePassAsync, up to 18 sequential calls once GamePassIds are set. Only then do `ctx.Plots.Claim(p)` and `ctx.Vehicles.Spawn(p)` run (L461-462). An AcceptJob in this window goes through …
- **Fix (gegengeprüft):** Preferred: never expose a half-initialised profile. In onJoin, run the yielding pass lookup before publishing the profile. Split MonetizationService.Join into two parts: (1) `FetchOwned(p)`, which fills s.OwnedPasses (yields) and is called right after `ctx.Data.Load(p)` and before `ctx.Data.Profiles[p] = d`; (2) `grantVIPCase(p)`, which needs the profile and runs after the assignment. Then re-check `if not p.Parent then pcall(ctx.Data.ReleaseLock, p); ctx.Sessions[p] = nil; return end` after the lookup.

As defence in depth, also set `s.Ready = true` right before `p:SetAttribute("Loaded", true)`. In the Request router (L309), use `local s = ctx.Sessions[p]; if not (ctx.Data.Profiles[p] and s and s.Ready) then return false, "Profil lädt noch …" end`, and add the same Ready check at the top of InteractService.Handle.

### B21 · LOW · memory-leak — Per-player tables are not cleared when the player leaves during join (admins, D.Temp) or ever (Vehicles deb)
`ServerScriptService.Server.AdminService` ~Zeile 47 · Aufwand S
- **Problem:** Main onJoin L426 `ctx.Admin.Join(p)` yields in `p:GetRankInGroup` (AdminService L34) before `admins[p] = true` (L47). If the player leaves during that yield, onLeave's `A.Leave` (L52) has already run, so the entry is never removed. DataService.Load sets `D.Temp[player] = true` (L89/93/101) after onLeave may have cleared it (Main L488), and the early-return path in onJoin (L449-453) does not clear it. VehicleService L19-31: `local deb = {}` ... …
- **Fix (gegengeprüft):** In onJoin's early-return path, add `ctx.Data.Temp[p] = nil; ctx.Admin.Leave(p)`. In A.Join, set `admins[p]` only `if p.Parent`. In VehicleService.Init, add `Players.PlayerRemoving:Connect(function(p) for _, deb in ipairs(debs) do deb[p] = nil end end)`, or use a single module-level `deb` keyed by player and cleared on leave.

### B22 · LOW · correctness — C.Pass toggles only the profile flag: Robux-owned passes report 'deaktiviert' but stay active
`ServerScriptService.Server.AdminService` ~Zeile 305 · Aufwand S
- **Problem:** d.Passes[id] = (not d.Passes[id]) or nil
...
return true, G.Passes[id].Name .. (d.Passes[id] and " aktiviert" or " deaktiviert")
Economy.HasPass returns `d.Passes[id] or s.OwnedPasses[id]`.
- **Fix (gegengeprüft):** After the toggle, use `local active = ctx.Economy.HasPass(t, id)`. Build the message from `active` instead of d.Passes[id]. If `not d.Passes[id] and active`, add " (per Robux gekauft – bleibt aktiv)". Do not add a separate AdminPasses table unless you also handle save migration for it.

### B23 · LOW · correctness — C.Shutdown: duplicated saves, no join lock, can be scheduled multiple times
`ServerScriptService.Server.AdminService` ~Zeile 821 · Aufwand S
- **Problem:** task.delay(10, function()
	pcall(ctx.Data.SaveAll, false)
	for _, pl in ipairs(Players:GetPlayers()) do pl:Kick("🛠 " .. reason) end
end)
- **Fix (gegengeprüft):** Add `if A._shuttingDown then return false, "Neustart läuft bereits" end; A._shuttingDown = true` to C.Shutdown. Remove the SaveAll(false) call and rely on the onLeave save with release that the kick triggers. While the flag is set, kick players who join and keep kicking late joiners for the rest of the session.

### B24 · LOW · correctness — Crew and robot task streams are routed by the owner's current city, not by where the crew works
`ServerScriptService.Server.CrewWork` ~Zeile 110 · Aufwand S
- **Problem:** C.Send: `local hrp = ch and ch:FindFirstChild("HumanoidRootPart") ctx.FireRegion("FX", hrp and ctx.RegionAt(hrp.Position) or p:GetAttribute("Region"), p, "CrewTask", msg)`. robotLoop does the same (JobService L1433-1435). The legs, however, are in the owner's warehouse (packing) or at the venue (building).
- **Fix (gegengeprüft):** local first = L[1] and L[1][1]; ctx.FireRegion("FX", (typeof(first)=="Vector3" and ctx.RegionAt(first)) or (hrp and ctx.RegionAt(hrp.Position)) or p:GetAttribute("Region"), p, "CrewTask", msg). Apply the same change in robotLoop's send().

### B25 · LOW · race-condition — Rejoining the same server before the release save finishes can load stale data (own-JobId lock is taken immediately)
`ServerScriptService.Server.DataService` ~Zeile 78 · Aufwand S
- **Problem:** L78: `if lock and lock.Job ~= game.JobId and ... then result = "LOCKED"`. A lock held by this same server is taken over at once. If the previous session's onLeave `Save(p, true)` is in retry backoff (L59), the new Player's Load UpdateAsync can run first and read the older data. The old save's retry then writes the old copy without a lock, and the new session's later autosave overwrites the final state of the previous session.
- **Fix (gegengeprüft):** Keep a module-level counter keyed by UserId. Use a count rather than a boolean so overlapping autosave and release saves don't clear each other. In D.Save, add D.SavingUid[uid] = (D.SavingUid[uid] or 0) + 1 before the retry, and decrement it on every return path; wrapping the body or using a finally-style helper ensures the decrement always runs. At the start of D.Load, wait with a bound: local t = os.clock(); while (D.SavingUid[player.UserId] or 0) > 0 and os.clock() - t < 30 and player.Parent do task.wait(0.2) end. The bound keeps Load from hanging forever.

### B26 · LOW · memory-leak — InteractService.Points grows on every plot claim and is never pruned (memory leak of destroyed warehouse parts)
`ServerScriptService.Server.InteractService` ~Zeile 116 · Aufwand S
- **Problem:** L115-116 `I.Points[kind] = I.Points[kind] or {} table.insert(I.Points[kind], target)`. PlotService.Claim L73 calls `ctx.Interact.Scan(m, p)` on each player's cloned warehouse, whose terminals carry Interaction attributes (TerminalKit: JobBoard/Shop/Crew/...). PlotService.Release L86 destroys the model, but the entries in I.Points are never removed.
- **Fix (gegengeprüft):** In I.Attach, after `table.insert(I.Points[kind], target)`, add:
```lua
local list = I.Points[kind]
target.Destroying:Once(function()
	local i = table.find(list, target)
	if i then table.remove(list, i) end
end)
```
(Alternatively, only insert when `kind:match("^Case_") or kind:match("^Roadcase_")`, since those are the only kinds Near/PlaceName ever query.) Also optional cleanup: drop the unused second argument in PlotService L73 `ctx.Interact.Scan(m, p)`.

### B27 · LOW · correctness — Interact.Scan calls kind:match on attributes without a type check; one non-string attribute aborts the whole scan
`ServerScriptService.Server.InteractService` ~Zeile 127 · Aufwand S
- **Problem:** L126-128 `local kind = d:GetAttribute("Interaction") if kind and (...) then I.Attach(d, kind) end`. Attach L102 calls `kind:match(...)`. FastTravel.Scenes (L34) already guards with `type(ia) == "string"`.
- **Fix (gegengeprüft):** In Scan, use `if type(kind) == "string" and kind ~= "" and (d:IsA("BasePart") or d:IsA("Model")) then`. You can also add a warn on the else branch for non-string values so builders see their mistake.

### B28 · LOW · correctness — Tenders are generated and announced on the Trading Plaza server where they cannot be accepted
`ServerScriptService.Server.JobService` ~Zeile 255 · Aufwand S
- **Problem:** S.Init starts `while true do pcall(S.SpawnTender) task.wait(G.TenderInterval) end` without checking `ctx.Plaza.IsPlaza`. SpawnTender sends `ctx.Notify(pl, "📢 Neue Ausschreibung ...")` to every player and a ctx.Broadcast for tier 4+. Main's PLAZA_BLOCK rejects AcceptTender there.
- **Fix (gegengeprüft):** In S.Init, wrap the three tender pieces (the SpawnTender loop, the CleanupTenders/BroadcastTenders loop and the PlayerAdded Tender push) in `if not (ctx.Plaza and ctx.Plaza.IsPlaza) then ... end`. Alternatively, put `if ctx.Plaza and ctx.Plaza.IsPlaza then return end` at the start of S.SpawnTender. Leave the job Tick loop unguarded.

### B29 · LOW · correctness — Tender cleanup loop has no pcall: if CleanupTenders/BroadcastTenders throws once, expired and taken tenders are never pruned
`ServerScriptService.Server.JobService` ~Zeile 261 · Aufwand S
- **Problem:** L261-266: `task.spawn(function() while true do task.wait(5) if S.CleanupTenders() then S.BroadcastTenders() end end end)`. BroadcastTenders -> S.TenderList (L662-673) indexes every tender's def: `t.Def.Level`, `math.floor(t.Def.Cash * (t.Boost.Cash or 1))`, `J.Payout(t.Def, 5, t.Boost)` (JobLogic L205-208: `job.Cash * m`, `job.XP * m`). CleanupTenders (L679-697) indexes `t.Def.Id`. The spawn loop just above (L255-259: `pcall(S.SpawnTender)`) and …
- **Fix (gegengeprüft):** task.spawn(function() while true do task.wait(5) local ok, err = pcall(function() if S.CleanupTenders() then S.BroadcastTenders() end end) if not ok then warn("[Tender] " .. tostring(err)) end end end)

### B30 · LOW · race-condition — AutoCrew delayed AutoPack checks s.Job, not the job it was scheduled for
`ServerScriptService.Server.JobService` ~Zeile 645 · Aufwand S
- **Problem:** `task.delay(0.5, function() if s.Job and s.Job.Phase == "Packing" and not s.Job.Packing then S.AutoPack(p) end end)`. Arrive (L1754-1756) does it correctly: `if s.Job == job and ...`.
- **Fix (gegengeprüft):** local job0 = s.Job
task.delay(0.5, function()
	if p.Parent and s.Job == job0 and job0.Phase == "Packing" and not job0.Packing then S.AutoPack(p) end
end)

### B31 · LOW · correctness — An error inside startJob leaves the tender permanently Taken
`ServerScriptService.Server.JobService` ~Zeile 743 · Aufwand S
- **Problem:** `t.Taken = p local ok, err = startJob(p, t.Def, {...}) if not ok then t.Taken = nil ...`. If startJob throws (for example `vf:FindFirstChild` on a missing venue folder at L572, or a nil-index in Plan), the router's pcall catches it and `t.Taken` stays set. CleanupTenders then removes the tender as taken.
- **Fix (gegengeprüft):** local okCall, ok, err = pcall(startJob, p, t.Def, { Boost = t.Boost, Tender = t.Title, Conditions = t.Conditions })
if not okCall or not ok then
	t.Taken = nil
	if not okCall then warn("[JobService] AcceptTender startJob error:", ok) end
	return false, okCall and err or "Fehler beim Starten des Auftrags."
end

### B32 · LOW · correctness — ReturnCarried re-adds staging entries without Slot/Rent info
`ServerScriptService.Server.JobService` ~Zeile 899 · Aufwand S
- **Problem:** `table.insert(job.Staging, { Id = e.Id })`. SpawnStaging builds the label from `job.Rent[e.Slot]` (L858), but Carry entries only store `{ Id, From }` (CarryService L48-53).
- **Fix (gegengeprüft):** Add an optional fourth parameter to C.Take: `function C.Take(p, id, from, extra)` stores `{ Id = id, From = from, Slot = extra and extra.Slot, InRack = extra and extra.InRack }`. In TakeStaged (L889), call `ctx.Carry.Take(p, e.Id, "Staging", e)`. Do the same at L1225 if it has the staging entry. In ReturnCarried, insert `{ Id = e.Id, Slot = e.Slot, InRack = e.InRack }`. Restore InRack as well as Slot so the entry keeps the same shape as at L567.

### B33 · LOW · correctness — ForcePack while crew items are in flight duplicates cargo
`ServerScriptService.Server.JobService` ~Zeile 1075 · Aufwand S
- **Problem:** ForcePack L1075-1079 inserts every Staging entry (including `x0` with `Claimed = true` that crewLoop is carrying) into s.Cargo. packingDone then refuses to switch phase because `job.InFlight > 0` (L1049). crewLoop continues (alive() is still true): `table.find(job.Staging, x0)` is nil, but it still runs `ctx.Vehicles.AddCargo(p, x0.Id)` (L1399).
- **Fix (gegengeprüft):** In the ForcePack Staging loop, skip claimed entries: `for _, e in ipairs(job.Staging) do if not e.Claimed then if e.Model then e.Model:Destroy() e.Model = nil end table.insert(s.Cargo, e.Id) end end`. Then keep only those claimed entries in Staging rather than setting `job.Staging = {}`: `local keep = {} for _, e in ipairs(job.Staging) do if e.Claimed then table.insert(keep, e) end end job.Staging = keep`. The crew loop removes each one, calls AddCargo and calls packingDone itself. Do not set Phase = "Driving" before packingDone.

### B34 · LOW · correctness — S.Unload stops at the first needed item that is not on board, even if other same-phase items are in the truck
`ServerScriptService.Server.JobService` ~Zeile 1159 · Aufwand S
- **Problem:** L1151-1160: `local id = S.NextNeeded(p) ... if table.find(s.Cargo or {}, id) then from = "Cargo" elseif table.find(job.Freight, id) then from = "Freight" else break end`. NextNeeded (L1125-1144) always returns the first unplaced slot's id after the phase sort.
- **Fix (gegengeprüft):** In NextNeeded, add an optional `avail` predicate: inside the loop, after the carriedCount check, `elseif not avail or avail(id) then return id end` (otherwise continue). In Unload, call `S.NextNeeded(p, function(id) return table.find(s.Cargo or {}, id) or table.find(job.Freight, id) end)`. Keep the existing from-detection and drop the `else break` (it can no longer be hit). Other callers of NextNeeded keep their current behaviour.

### B35 · LOW · race-condition — plazaCode is a non-atomic read-modify-write on MemoryStore: concurrent main servers reserve several Plaza codes and overwrite each other
`ServerScriptService.Server.PlazaService` ~Zeile 131 · Aufwand M
- **Problem:** local ok, rec = pcall(s.GetAsync, s, "current")
... if not (... (st.Count or 0) >= S.MaxPlayers) then return rec.Code end
local okR, code, id = pcall(TeleportService.ReserveServer, ...)
pcall(s.SetAsync, s, "current", { Code = code, ... }, 86400 * 30)
Occupancy is reported only every 20 s (L109), and S.MaxPlayers = 40 is hard-coded rather than taken from Players.MaxPlayers.
- **Fix (gegengeprüft):** The proposed fix has a problem: an UpdateAsync transform must not yield, and ReserveServer yields, so the reservation cannot happen inside the transform. The fix is to reserve first and then commit atomically, adopting the winner's code: `local okR, code, id = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId); if not okR then return nil, tostring(code) end; local final = code; pcall(s.UpdateAsync, s, "current", function(old) if type(old)=="table" and old.Code and old.Code ~= staleCode then final = old.Code; return nil end; return {Code=code, Id=id, Created=os.time()} end, 86400*30); return final`. Here staleCode is the rec.Code that was judged full or missing (nil if there was none). The transform only replaces the record if it still matches what this server saw; otherwise it uses the record another server just wrote. Wasting one reserved code is harmless. Replace the …

### B36 · LOW · correctness — Plaza Region attribute is immediately overwritten with 'Neustadt' by Main.onJoin
`ServerScriptService.Server.PlazaService` ~Zeile 468 · Aufwand S
- **Problem:** PlazaService.OnPlayer: `p:SetAttribute("Region", "Plaza")`
Main.onJoin L458-469: `if ctx.Plaza.IsPlaza then ctx.Plaza.OnPlayer(p) ... end ... p:SetAttribute("Region", "Neustadt")`
- **Fix (gegengeprüft):** In Main.onJoin, change line 468 to: `if not ctx.Plaza.IsPlaza then p:SetAttribute("Region", "Neustadt") end`

### B37 · LOW · race-condition — P.Claim indexes the session without a nil check (player left during the gamepass checks)
`ServerScriptService.Server.PlotService` ~Zeile 45 · Aufwand S
- **Problem:** `function P.Claim(p) local s = ctx.Sessions[p] if s.Plot then return s.Plot end`. Main.onJoin calls `ctx.Monetization.Join(p)` (which yields on `UserOwnsGamePassAsync` per pass, Monetization L80-89) and then `ctx.Plots.Claim(p)` (Main L459-461) without re-checking p.Parent. onLeave sets `ctx.Sessions[p] = nil` (Main L492).
- **Fix (gegengeprüft):** In Main.onJoin, add `if not p.Parent or not ctx.Sessions[p] then return end` right after `ctx.Monetization.Join(p)`. In P.Claim, add a defensive guard: `local s = ctx.Sessions[p]; if not s then return nil end`. Optionally, in Monetization.Join, add `if not ctx.Sessions[p] then return end` before grantVIPCase(p).

### B38 · LOW · correctness — Rack prompts are created for everyone but work only for the owner
`ServerScriptService.Server.PlotService` ~Zeile 476 · Aufwand S
- **Problem:** `pr.Triggered:Connect(function(plr) if plr == p and ctx.Jobs.TakeFromRack then ctx.Jobs.TakeFromRack(p, id) end end)`. The prompt is a server instance, and Client.Prompts (PromptShown, L25-30) renders every Custom prompt without an owner filter.
- **Fix (gegengeprüft):** In PlotService, call pr:SetAttribute("OwnerId", p.UserId) before parenting the prompt. Then add a client-side owner check. A check inside PromptShown alone only hides the card, while the ProximityPrompt itself still fires. It is cleaner to also disable the prompt locally: in the client, use a DescendantAdded hook or PromptShown to set prompt.Enabled = false when prompt:GetAttribute("OwnerId") is set and differs from LocalPlayer.UserId, and return early.

### B39 · LOW · correctness — Roadcase storage check counts 1 slot per item, but exclusive items can occupy 2 slots: capacity can be exceeded
`ServerScriptService.Server.RoadcaseService` ~Zeile 54 · Aufwand S
- **Problem:** local function storageFree(p, d, count)
	return ctx.Shop.StorageUsed(d) + count <= ctx.Shop.Capacity(d, p)
end
Shop.Units uses WCfg.Places(it), which returns 2 when `Weight >= 60 or Volume >= 1.2`. Exclusive items copy Weight/Volume from MODEL_REF (ItemRegistry L392), so heavy subs and line arrays count as 2. The header comment "1 Lagerplatz je Item" predates Polish K.
- **Fix (gegengeprüft):** Prefer to document rather than block: change the header comment (L3) to say the drawn item takes WarehouseConfig.Places slots (exclusive subwoofers take 2) and that one open may overshoot capacity by up to `count` slots. If a strict check is wanted, precompute per case once in Init: `maxPlaces[caseId] = max over RC.Cases[caseId] item ids of ctx.Shop.Units(id)` (only Subwoofer exclusives give 2; LineArray does not). Then use `ctx.Shop.StorageUsed(d) + count * (maxPlaces[caseId] or 1) <= ctx.Shop.Capacity(d, p)` in both Buy (L132) and OpenOwned (L159). Treat that as a deliberate gameplay change, because at 1 free slot it will refuse the N1/P1/M1/premium cases.

### B40 · LOW · correctness — BuyLED skips the storage check although the LED wall occupies 2 slots
`ServerScriptService.Server.ShopService` ~Zeile 85 · Aufwand S
- **Problem:** if d.LEDLevel == 0 then
	if not ctx.Economy.Spend(p, it.Price) then ...
	d.Inventory.PixelForge_LEDWall = 1
PixelForge_LEDWall has Weight = 60, so WCfg.Places returns 2. BuyItem checks storage (L47-50), but its Modular branch (L45) returns before that check.
- **Fix (gegengeprüft):** Inside `if d.LEDLevel == 0 then`, before the Spend call, add: `if S.StorageUsed(d) + S.Units("PixelForge_LEDWall") > S.Capacity(d, p) then return false, "Lager voll! Erweitere dein Lager oder verkaufe Equipment." end`

### B41 · LOW · correctness — Shop.Rename: byte-length check, no filter cooldown, profile accessed after yield
`ServerScriptService.Server.ShopService` ~Zeile 192 · Aufwand S
- **Problem:** if #name < 3 or #name > 24 then return false, "Name muss 3–24 Zeichen lang sein." end
local ok, filtered = pcall(function() local r = TextService:FilterStringAsync(name, p.UserId) ... end)
...
ctx.Data.Profiles[p].CompanyName = filtered
- **Fix (gegengeprüft):** Use `utf8.len(name)`, rejecting nil (invalid UTF-8). Add a per-player cooldown, e.g. `s.LastRename` of 5 s. Capture `local d = ctx.Data.Profiles[p]` before the yield and, afterwards, require `ctx.Data.Profiles[p] == d` before writing.

### B42 · LOW · correctness — Tender condition percentages are truncated with %d: Premium shows +39 % instead of +40 %
`ServerScriptService.Server.ShowService` ~Zeile 80 · Aufwand S
- **Problem:** L76/L80 `string.format(" (+%d%%)", (c.Bonus - 1) * 100)` with TenderGen L222 `Bonus = 1.4`. (1.4 - 1) * 100 = 39.99999999999999, and Luau's %d truncates, giving "+39%".
- **Fix (gegengeprüft):** At both L76 and L80, wrap the value in math.round: string.format(" (+%d%%)", math.round((c.Bonus - 1) * 100)) and string.format(" (−%d%%)", math.round((1 - c.Malus) * 100)). The Express and Premium branches build the same note, so a shared local helper is optional but safe.

### B43 · LOW · correctness — Auto-event XP skips XPMult (2x XP pass, XP pets/skills) while its cash uses CashMult and Dispatch uses both
`ServerScriptService.Server.StaffService` ~Zeile 212 · Aufwand S
- **Problem:** Preview L211-212: `local cm = ctx.Economy.CashMult(p)` ... `Net = math.floor((gross - wage) * cm), XP = math.floor(job.XP * G.Staff.AutoXP)`. Collect L290 then does `ctx.Economy.AddXP(p, e.XP)` directly. So the paid DoubleXP pass (GameConfig L47: 'Doppelte Erfahrung') and XP bonuses from pets/skills never apply to auto-events, although CashMult/DoubleCash does. Manual shows (Economy.Reward in ShowService L89) and Dispatch (JobService …
- **Fix (gegengeprüft):** In Preview, set `XP = math.floor(job.XP * G.Staff.AutoXP * ctx.Economy.XPMult(p))`, captured at start the same way Net captures CashMult. Existing in-flight Auto/Pending entries keep their stored XP, so saves stay compatible.

### B44 · LOW · correctness — Pet Lock is only checked when offered, not at execution: locking an offered pet during the countdown does not protect it
`ServerScriptService.Server.TradeService` ~Zeile 87 · Aufwand S
- **Problem:** T.Offer: `if d.Crew[uid].Lock then return false, "Gesperrte Crew kann nicht gehandelt werden." end`
execute: `for _, uid in ipairs(tr.OfferA) do if not dA.Crew[uid] then return close(tr, "Angebot ungültig.") end end` (no Lock check). Main H.LockCrew toggles c.Lock at any time and does not reset the trade's ready state.
- **Fix (gegengeprüft):** Change lines 87-88 to `if not dA.Crew[uid] or dA.Crew[uid].Lock then return close(tr, "Angebot ungültig.") end` and do the same for dB/OfferB.

### B45 · LOW · correctness — Traded pets are not marked as discovered for the receiver (CrewFound): a received Secret stays '???' until rejoin
`ServerScriptService.Server.TradeService` ~Zeile 106 · Aufwand S
- **Problem:** local nu = tostring(dTo.NextCrewId)
dTo.NextCrewId += 1
dTo.Crew[nu] = { T = c.T, At = os.time() }
CrewService.Add does `C.MarkFound(p, typeId)`. The trade path writes d.Crew directly and skips it. Only DataService.Load migrates CrewFound (L112-113).
- **Fix (gegengeprüft):** In move(), after `dTo.Crew[nu] = { T = c.T, At = os.time() }`, add `ctx.Crew.MarkFound(to, c.T)`. It must run before the ctx.OnCrewChanged loop.

### B46 · LOW · correctness — Trade loop thread has no pcall: one error permanently stops all trades, countdowns and table matching on the server
`ServerScriptService.Server.TradeService` ~Zeile 132 · Aufwand S
- **Problem:** task.spawn(function()
	while true do
		task.wait(0.3)
		for tr in pairs(active) do ... elseif tr.Table and not (onPad(tr.Table:FindFirstChild("PadA", true), tr.A.Character) ...) ... elseif tr.CountEnd and os.clock() >= tr.CountEnd then execute(tr) end
onPad(pad, ch) indexes `pad.CFrame` without a nil check (L28), so a missing or destroyed pad makes it throw. execute() calls ctx.OnCrewChanged (L116), whose Economy.Invalidate and Carry.UpdateSpeed …
- **Fix (gegengeprüft):** Move the loop body into `local function step() ... end` and run `while true do task.wait(0.3); local ok, err = pcall(step); if not ok then warn("[Trade] loop: ", err) end end`. Add `if not pad then return false end` at the top of onPad. In execute(), call close(tr, "Handel abgeschlossen! 🤝") right after setting LastTrade, then run `for _, p in ipairs({tr.A, tr.B}) do pcall(ctx.OnCrewChanged, p) end`. No other changes are needed: departure cleanup is already handled by T.Leave via Main.onLeave.

### B47 · LOW · memory-leak — HighwayTrigger debounce table keeps Player references forever
`ServerScriptService.Server.VehicleService` ~Zeile 19 · Aufwand S
- **Problem:** L19 `local deb = {}` per trigger, L31 `deb[p] = os.clock()`. Nothing clears it on PlayerRemoving (FastTravel does: L17 `PlayerRemoving:Connect(function(p) last[p] = nil end)`).
- **Fix (gegengeprüft):** Change L19 to `local deb = setmetatable({}, { __mode = "k" })`. Alternatively, key the table by `p.UserId`, or store the timestamp in the session (`s.HighwayFxAt`, guarded by `if s`) so it is removed together with the session. Behaviour stays the same either way.

### B48 · LOW · correctness — Anti-teleport rollback restores PrimaryPart.CFrame through PivotTo; the truck's PivotOffset lifts it several studs on every rollback
`ServerScriptService.Server.VehicleService` ~Zeile 70 · Aufwand S
- **Problem:** L77 stores `s.TruckLastCF = root.CFrame` (the PrimaryPart CFrame). L70 restores it with `t:PivotTo(s.TruckLastCF)`. The truck prefab root is built by BuildKit.K.root with `r.PivotOffset = CFrame.new(0, -center.Y, 0)` (BuildKit L135; PrefabsVehicle L22 `K.root(m, ..., Vector3.new(0, clear + (H - clear)/2, 0))`), so the model pivot sits about 5 studs below the root (Van: center.Y ≈ 5.1). PivotTo(rootCF) therefore puts the root about 5 studs above …
- **Fix (gegengeprüft):** Smallest change: at L70 apply the root's pivot offset so the two frames match: `t:PivotTo(s.TruckLastCF * root.PivotOffset)`. An equivalent alternative stores and compares pivots: L77 `s.TruckLastCF = t:GetPivot()`, L66/67 compare against `t:GetPivot().Position` (also set `pos = t:GetPivot().Position` at L60/L74). If you use the alternative, update every comparison site together, because the 'allowed' threshold is the same either way.

### B49 · LOW · correctness — ReturnHome ejects the driver with a fixed 0.1 s wait and does not confirm the weld is gone
`ServerScriptService.Server.VehicleService` ~Zeile 238 · Aufwand S
- **Problem:** L238-241 `if seat and seat.Occupant then seat.Occupant.Sit = false end task.wait(0.1) s.Truck.PrimaryPart.Anchored = true s.Truck:PivotTo(homeCF(...))`. The Humanoid is client-owned, so Sit=false is applied with latency. FastTravel (L141-145) correctly polls `hum.SeatPart` for up to 0.8 s and aborts if still seated.
- **Fix (gegengeprüft):** local seat = s.Truck:FindFirstChild("DriverSeat")
if seat and seat.Occupant then
  seat.Occupant.Sit = false
  local w = seat:FindFirstChild("SeatWeld"); if w then w:Destroy() end
end
task.wait(0.1)
if ctx.Sessions[p] ~= s or not s.Truck or not s.Truck.Parent or not s.Truck.PrimaryPart then return false, "LKW nicht verfügbar." end
s.Truck.PrimaryPart.Anchored = true
...

### B50 · LOW · race-condition — Two Travel calls overlapping the 0.9 s yield both pass the highway check
`ServerScriptService.Server.VehicleService` ~Zeile 418 · Aufwand S
- **Problem:** The guard `hw and os.clock() - hw.Time < 45 ...` is checked, then the function yields (`pcall(p.RequestStreamAroundAsync, ...)` plus `task.wait(rest)`). `s.HighwayAt` is cleared only after the PivotTo (L436). The driver is not re-checked after the yield (only `if not t.Parent`).
- **Fix (gegengeprüft):** Right after the guard passes, before FireClient and the yield, add `s.HighwayAt = nil`. This consumes the highway token so a second call fails the check. After the yield, change the check to `if not t.Parent or s.Truck ~= t or S.Driver(p) ~= p then return false end`. Keep the existing clear at L437.

### B51 · LOW · correctness — Day/night grading and ShowDirector both write Lighting.ExposureCompensation; daytime exposure is left at 0 after every show
`StarterPlayer.StarterPlayerScripts.Client.Ambient` ~Zeile 47 · Aufwand S
- **Problem:** Ambient: `if math.abs(d - lastDayness) < 0.004 then return end ... Lighting.ExposureCompensation = GRADE_NIGHT.Exposure + (GRADE_DAY.Exposure - GRADE_NIGHT.Exposure) * d` with `GRADE_DAY.Exposure = 0.2`. ShowDirector L184 tweens to `{ ExposureCompensation = -0.9 }` and L219 restores with `{ ExposureCompensation = 0 }`. Between 8 and 17 h dayness stays at 1, so updateGrade returns early and never rewrites exposure. After a show the world stays at …
- **Fix (gegengeprüft):** In Ambient, add `A.ExposureOffset = 0` and change L52 to `Lighting.ExposureCompensation = GRADE_NIGHT.Exposure + (GRADE_DAY.Exposure - GRADE_NIGHT.Exposure) * d + A.ExposureOffset`. Add `function A.Refresh() lastDayness = -1 updateGrade() end`. In ShowDirector, keep a module-level counter `dimCount`. At show start, if dimmed, do `dimCount += 1; Ambient.ExposureOffset = -0.9; Ambient.Refresh()`. In finish(), if dimmed, do `dimCount -= 1; if dimCount == 0 then Ambient.ExposureOffset = 0 end; Ambient.Refresh()`. If a fade is wanted, tween a NumberValue and set the offset and call Refresh from its Changed event. This removes the direct tweens on Lighting.ExposureCompensation at L184 and L219.

### B52 · LOW · correctness — Ambient.apply iterates windows/lights with pairs() across yields while DescendantAdded inserts into the same tables
`StarterPlayer.StarterPlayerScripts.Client.Ambient` ~Zeile 166 · Aufwand S
- **Problem:** `for p, o in pairs(windows) do ... step() end` where step calls `task.wait()` every 300 parts (L162-179). The same is done for `lights` (L180-189). Meanwhile `workspace.DescendantAdded:Connect(register)` (L223) does `windows[d] = {...}` / `lights[d] = {...}`. Under StreamingEnabled parts stream in constantly, so new keys are added to the table being traversed while the traversal is suspended. Adding keys during pairs() is undefined in Luau: a …
- **Fix (gegengeprüft):** Snapshot the keys before the yielding loops. Re-read the entry for each key, because forget() may have removed it during a yield:
local wl = {} for p in pairs(windows) do wl[#wl+1] = p end
for _, p in ipairs(wl) do local o = windows[p]; if o then if p.Parent then (existing body) step() else windows[p] = nil end end end
Do the same for lights (ll / lights[p]). Optionally wrap the body in pcall (`local ok, err = pcall(body); applying = false; if not ok then warn(err) end`) so `applying` can never stay true. As an optional extra, after the loops check `if isNight ~= night then` and re-apply, because a check() that fires while applying is true returns early (L159) after updating isNight. Parts processed before that change would otherwise keep the old state.

### B53 · LOW · correctness — Windmill rotors: PivotTo every frame within 1800 studs, and the non-atomic rotor model can desync blades under streaming
`StarterPlayer.StarterPlayerScripts.Client.Ambient` ~Zeile 233 · Aufwand S
- **Problem:** `elseif not cp or (r:GetPivot().Position - cp).Magnitude < 1800 then r:PivotTo(r:GetPivot() * rot) end` runs every Heartbeat. The rotor is a plain Model of 4 parts (BuildOutskirts L530-541, `rotor:SetAttribute("Windmill", true)`). If a single blade streams out and back in, it reappears at its server (unrotated) CFrame while the others have been rotated on the client.
- **Fix (gegengeprüft):** Set the rotor's ModelStreamingMode to Atomic. This must be applied in the saved place, because BuildOutskirts is an edit-time DevTools script, and also added to BuildOutskirts for later rebuilds. Optionally, also check the distance against the squared value instead of taking a Magnitude.

### B54 · LOW · race-condition — Ambient.Init yields during synchronous client boot; later modules start late and CrewDirector/Robots drop FX events
`StarterPlayer.StarterPlayerScripts.Client.Ambient` ~Zeile 243 · Aufwand S
- **Problem:** A.Init calls `check()` synchronously (L238-243). `isNight` starts as nil, so `apply(night)` always runs at join, and apply yields: `local function step() n += 1 if n % 300 == 0 then task.wait() end end` (L162-165), over all windows and lights collected from `workspace:GetDescendants()`. ClientMain calls the inits back to back: `safe("Ambient", Ambient.Init)` then Traffic, Pedestrians, ..., `safe("CrewDirector", CrewDirector.Init)`, ..., …
- **Fix (gegengeprüft):** In A.Init replace `check()` with `task.spawn(check)`. Optionally also move `safe("Ambient", Ambient.Init)` to the end of the init list in ClientMain so that no yielding init comes before the FX listeners.

### B55 · LOW · memory-leak — CrewDirector propCache keeps every stack template forever (unbounded keys)
`StarterPlayer.StarterPlayerScripts.Client.CrewDirector` ~Zeile 190 · Aufwand S
- **Problem:** `local key = "stack:" .. table.concat(ids, "+") local t = propCache[key] if t then return t end ... propCache[key] = t`. Each distinct ordered item combination (from crew and robot tasks of every player in the region) builds a full multi-layer model with welds and caches it with no limit. Each layer also keeps its inner PropRoot and welds, which rootAt then welds again to the new root.
- **Fix (gegengeprüft):** Keep a separate FIFO only for keys starting with "stack:" and evict when it holds more than about 32 entries: `propCache[old].Model:Destroy(); propCache[old]=nil`. This is safe because ensureProp and MakeProp clone t.Model right away and never keep the template itself. A simpler option is to change the key to the id and the count when every id in the stack is the same.

### B56 · LOW · correctness — Client subsystems shut down permanently after a few errors
`StarterPlayer.StarterPlayerScripts.Client.CrewDirector` ~Zeile 783 · Aufwand S
- **Problem:** CrewDirector: `if failed > 5 then return end`. Traffic (L871) `if failed > 3 then return end`. Pedestrians (L377) and Robots (L200) have the same pattern. The counter never decays, so a few transient errors (for example a streamed-out anchor during a teleport) disable crews, traffic or robots for the whole session, with only an early warn.
- **Fix (gegengeprüft):** Count errors that happen in quick succession, not errors over the whole session. Add `local lastFail = 0`. On each error, run `if os.clock() - lastFail > 30 then failed = 0 end`, then `failed += 1; lastFail = os.clock()`. Keep the guard as `if failed > N and os.clock() - lastFail < 10 then return end`, so after a cooldown the system tries again instead of staying off for good. Apply this to all four files (CrewDirector, Pedestrians, Robots, Traffic).

### B57 · LOW · memory-leak — vehCache keeps destroyed vehicle models alive (strong keys)
`StarterPlayer.StarterPlayerScripts.Client.Effects` ~Zeile 36 · Aufwand S
- **Problem:** `local vehCache = {} -- [Model] = Size.Y`, filled by `vehCache[veh] = h` in the RenderStepped loop (L613-617) and never cleared. VehicleService destroys and re-clones the truck on every vehicle switch or respawn (`if s.Truck then s.Truck:Destroy() ...`).
- **Fix (gegengeprüft):** local vehCache = setmetatable({}, { __mode = "k" }) -- or, alternatively, cache only the current vehicle: `if veh ~= lastVeh then lastVeh = veh; lastH = select(2, veh:GetBoundingBox()).Y end`. The single-entry version is deterministic and does not depend on the GC collecting Instance keys.

### B58 · LOW · correctness — Spedition truck: cargo-door offset is computed before the model is moved, so the door is animated at the template's world position near the map origin
`StarterPlayer.StarterPlayerScripts.Client.Effects` ~Zeile 217 · Aufwand S
- **Problem:** In spedTruck, `local door = m:FindFirstChild("CargoDoor"); local doorRel = door and parkCF:ToObjectSpace(door.CFrame)` (L216-217) runs while the clone is still at its RS.Assets position. `m:PivotTo(startCF)` only happens at L224. Then `door.CFrame = parkCF * doorRel * CFrame.new(0, door.Size.Y * 0.85 * a, 0)` (L259) equals the template's own CFrame plus a lift. The templates sit at the origin (Truck_Titan40.CargoDoor ≈ (0, 8.08, 23.05), …
- **Fix (gegengeprüft):** L217: `local doorRel = door and m:GetPivot():ToObjectSpace(door.CFrame)` (computed before PivotTo, like spedPickup L319). This fixes both L259 and L265, because m's pivot equals parkCF once move(startCF, parkCF) has finished.

### B59 · LOW · correctness — GPS arrow is never hidden near the goal and freezes in place (and/or bug; fix 'Polish D' is incomplete)
`StarterPlayer.StarterPlayerScripts.Client.Effects` ~Zeile 644 · Aufwand S
- **Problem:** `local nearGoal = dist < 12; if nearGoal ~= hidden then hidden = nearGoal; for _, e in ipairs(arrowParts) do e[1].Parent = hidden and nil or arrow end end; if hidden or flat.Magnitude < 0.5 then return end`. `hidden and nil or arrow` always evaluates to `arrow`: `true and nil` gives nil, then `nil or arrow` gives arrow. luau-lsp reports the same thing: 'MisleadingAndOr ... always evaluates to the second alternative' at Effects L644.
- **Fix (gegengeprüft):** Line 644 only: `for _, e in ipairs(arrowParts) do e[1].Parent = if hidden then nil else arrow end`. Optionally, to keep the distance label visible near the goal, toggle only Transparency or LocalTransparencyModifier on the non-Core parts instead of re-parenting them. That changes behaviour, so it is not required. Drop the proposed `hidden = false` in E.SetTarget: `hidden` is a closure local (L600) that SetTarget cannot reach, and the per-frame nearGoal ~= hidden comparison already restores visibility when a new target is far away. If a reset is wanted anyway, move `hidden` to module scope next to `gps`/`smoothDir` and reset it where SetTarget sets `smoothDir = nil`, and also re-parent the parts there.

### B60 · LOW · correctness — HUD tracker action buttons ignore their disabled state
`StarterPlayer.StarterPlayerScripts.Client.HUD` ~Zeile 196 · Aufwand S
- **Problem:** b1 and b2 are created without onClick (`UI.Button(btnRow, "", "primary", {...})`) and wired manually: `b1.Activated:Connect(function() if act1 then UI.Click() act1() end end)`. UI.Button's `enabled` and `UI.OpenedAt` guards (UI L169-171) only wrap the onClick that is passed in. So `b1api.SetEnabled(not job.Packing)` (L409) and `b1api.SetEnabled(miss <= 0)` (L443) change only the look.
- **Fix (gegengeprüft):** Pass the handler as onClick for b1, and for b2 to keep them consistent: `UI.Button(btnRow, "", "primary", {...}, function() if act1 then act1() end end)` (UI.Button already calls UI.Click). Then remove the manual Activated connections at L196-197. Side effect: the 0.25s OpenedAt guard now also applies to these buttons, which matches every other button.

### B61 · LOW · correctness — Pets Heartbeat step is not pcall-guarded and indexes workspace.World directly
`StarterPlayer.StarterPlayerScripts.Client.Pets` ~Zeile 107 · Aufwand S
- **Problem:** `RunService.Heartbeat:Connect(step)` (L144), unlike Traffic, Peds, Crew and Robots, which all wrap update in pcall. Inside: `local veh = workspace.World and workspace.World:FindFirstChild("Vehicles")` (L107). Indexing a missing child throws, and so would any bad pet model (PivotTo/GetBoundingBox).
- **Fix (gegengeprüft):** Change L107 to `local world = workspace:FindFirstChild("World"); local veh = world and world:FindFirstChild("Vehicles")`. At L144, connect a guarded wrapper instead of `step`: `local errs = 0; RunService.Heartbeat:Connect(function(dt) local ok, err = pcall(step, dt); if not ok then errs += 1; if errs <= 3 then warn("[Pets]", err) end else errs = math.max(0, errs - 0.01) end end)`.

### B62 · LOW · correctness — Custom prompt UI shows a stale ActionText/ObjectText (Ghosts change ActionText while the prompt is visible)
`StarterPlayer.StarterPlayerScripts.Client.Prompts` ~Zeile 41 · Aufwand S
- **Problem:** Prompts copies the text once in PromptShown: `UI.Text(f, prompt.ActionText, ...)` (L41) and `UI.Text(f, prompt.ObjectText, ...)` (L42), with no property-change listener. Ghosts.Recolor changes it live: `g.Prompt.ActionText = noMat and "Material fehlt" or (match and "Platzieren" or "Platzieren?")` (Ghosts L157). Recolor runs on every State.Changed, for example when the player picks up the matching case or material arrives.
- **Fix (gegengeprüft):** local aL = UI.Text(f, prompt.ActionText, ...) ; local oL = UI.Text(f, prompt.ObjectText, ...) ; local c4 = prompt:GetPropertyChangedSignal("ActionText"):Connect(function() aL.Text = prompt.ActionText end) ; local c5 = prompt:GetPropertyChangedSignal("ObjectText"):Connect(function() oL.Text = prompt.ObjectText end) ; in PromptHidden:Once add c4:Disconnect(); c5:Disconnect(); if holdTween then holdTween:Cancel() end before bb:Destroy(). Check that UI.Text returns the TextLabel (L37 already uses its return value `kt`, so it does).

### B63 · LOW · correctness — Robots: idle position is set only once, so shuttles stay stranded after a missed return task or a plot rebuild
`StarterPlayer.StarterPlayerScripts.Client.Robots` ~Zeile 110 · Aufwand S
- **Problem:** scanDocks: `local rb = robotAt(uid, d:GetAttribute("Index") or 1) if not rb.Pos then rb.Pos = (d.CFrame * CFrame.new(0, -0.06, 0)).Position rb.Dir = d.CFrame.LookVector end`. Tasks arrive through `ctx.FireRegion` (server JobService L1435), which only reaches players in the owner's region. A client that leaves the region during a run never receives the 'return to dock' task and keeps `rb.Pos = last[2]` (staging zone) forever. When a warehouse is …
- **Fix (gegengeprüft):** Client, Robots.lua L110: replace `if not rb.Pos then` with `if not rb.Task then` (keep the two assignments). It runs every 3 s, so idle shuttles always snap back to their dock. Optional on the server (JobService robotLoop): when `alive()` turns false and `not atHome`, send one last return task to `home` the same way L1446-1453 does, so all clients get the return animation. Optional cleanup: in scanDocks, collect the (uid, index) pairs that have a dock, and destroy any idle rb entries that have no matching dock.

### B64 · LOW · correctness — Packliste tiles reorder randomly on every rebuild
`StarterPlayer.StarterPlayerScripts.Client.ScreensJobs` ~Zeile 374 · Aufwand S
- **Problem:** `for id, n in pairs(counts) do tile(id, n, "zone") end for id, n in pairs(rack) do tile(id, n, "rack") end for id, n in pairs(loaded) do ...`. LayoutOrder is the running index `i`, so the order follows hash iteration. Packing is in ClientMain's refreshable list and is rebuilt on every State push.
- **Fix (gegengeprüft):** local function sortedKeys(t) local ks = {} for k in pairs(t) do table.insert(ks, k) end table.sort(ks, function(a, b) local na = R.Items[a] and R.Items[a].Name or tostring(a) local nb = R.Items[b] and R.Items[b].Name or tostring(b) if na == nb then return tostring(a) < tostring(b) end return na < nb end) return ks end
for _, id in ipairs(sortedKeys(counts)) do tile(id, counts[id], "zone") end
for _, id in ipairs(sortedKeys(rack)) do tile(id, rack[id], "rack") end
for _, id in ipairs(sortedKeys(loaded)) do tile(id, loaded[id], "done") end

### B65 · LOW · correctness — Auto-Event list offers jobs the server always rejects, and the estimate uses a different multiplier than the server
`StarterPlayer.StarterPlayerScripts.Client.ScreensJobs` ~Zeile 722 · Aufwand S
- **Problem:** The client filters only on `job.Level <= s.Level and regionOk and venueOk` and estimates `est = math.floor(job.Cash * G.Staff.AutoPayout * (1 - G.Staff.LeadWage) * ((s.Bonuses and (1 + (s.Bonuses.Cash or 0))) or 1))`. The server StaffService.Preview L188-189 rejects `vdef.SelfBuild or vdef.NoSpedition` ('Selbstaufbau – nur persönlich') and computes Net with `ctx.Economy.CashMult(p)`. The snapshot already carries `CashMult`, which the Dispatch …
- **Fix (gegengeprüft):** Add `and not (v.SelfBuild or v.NoSpedition)` to the condition at L722. Replace the multiplier factor at L724 with `(s.CashMult or 1)`, keeping a fallback to `1 + s.Bonuses.Cash` if CashMult is missing from the snapshot.

### B66 · LOW · correctness — Spawn and visibility distances exceed the streaming MinRadius (224), so cars, robots and crew can render over unloaded ground
`StarterPlayer.StarterPlayerScripts.Client.Traffic` ~Zeile 26 · Aufwand S
- **Problem:** Traffic: `local SPAWN_MIN, SPAWN_MAX, DESPAWN = 110, 430, 540`. Robots: `local VIS_DIST = 320`. CrewDirector: `local VIS_DIST = 300`. The PolishLog says 'Streaming (MinRadius 224) haelt den Client bei ~33k Instanzen'. On low-memory devices only MinRadius is guaranteed to be loaded, and Traffic does not check whether road geometry exists when it spawns.
- **Fix (gegengeprüft):** Read `workspace.StreamingMinRadius` at runtime instead of hardcoding it. If `workspace.StreamingEnabled` is on, clamp SPAWN_MAX to roughly min(430, StreamingMinRadius) and DESPAWN to roughly SPAWN_MAX+40. A cheaper option is a downward raycast at the spawn point (Include filter on the roads folder) that rejects any spawn point that gets no hit. Apply the same clamp to VIS_DIST in Robots and CrewDirector.

### B67 · LOW · correctness — Heartbeat error counters never reset; a few transient errors disable the system for the session and leave collidable cars frozen on the road
`StarterPlayer.StarterPlayerScripts.Client.Traffic` ~Zeile 871 · Aufwand S
- **Problem:** Traffic L869-877: `local failed = 0 ... if failed > 3 then return end local ok2, err = pcall(update, dt) if not ok2 then failed += 1 ...`. Pedestrians L375-383 does the same (>3), as do CrewDirector L781-789 (>5) and Robots L198-206 (>5). The counter only goes up, and nothing parks or hides the entities on the last failure. Traffic body parts use `p.CanCollide = shadow == true -- Karosserie fest`, so cars frozen mid-street block players and the …
- **Fix (gegengeprüft):** local failed, lastErr = 0, 0
RunService.Heartbeat:Connect(function(dt)
	if failed > 3 then return end
	local ok2, err = pcall(update, dt)
	if not ok2 then
		local now = os.clock()
		if now - lastErr > 10 then failed = 0 end
		lastErr = now
		failed += 1
		warn("[Traffic] " .. tostring(err))
		if failed > 3 then
			for _, c in ipairs(cars) do c.Active = false end
			folder.Parent = nil -- remove frozen collidable cars
		end
	end
end)
-- same pattern for Pedestrians (also table.clear(P.Positions)), CrewDirector, Robots (hide their folders)

### B68 · LOW · correctness — Esc handler ignores gameProcessedEvent
`StarterPlayer.StarterPlayerScripts.Client.UI` ~Zeile 303 · Aufwand S
- **Problem:** `UIS.InputBegan:Connect(function(inp, gp) if inp.KeyCode == Enum.KeyCode.Escape and UI.Current then UI.Close() end end)`. The `gp` argument is unused. UI.Confirm overlays are not handled either: Esc closes the window underneath while the modal stays.
- **Fix (gegengeprüft):** Instead of returning on every gp, use `if UIS:GetFocusedTextBox() then return end`. Then close the newest Confirm first: `local c = UI.Overlay:FindFirstChild("Confirm"); if c then c:Destroy() (or call its onNo) return end`. Only then do `if UI.Current then UI.Close() end`.

### B69 · LOW · correctness — Window builders are not pcall-protected and several index State.Data without a nil check
`StarterPlayer.StarterPlayerScripts.Client.UI` ~Zeile 346 · Aufwand S
- **Problem:** `w.Builder(w.Content, w, arg)` runs unprotected in both UI.Open and refreshNow (L364). The builders for Garage (ScreensShop L168 `s.ActiveVehicle`), Company (L261 `s.Level`), Premium (L317 `s.Passes[pid]`), Staff (ScreensJobs L611 `s.Staff`), Dispatch (L773 `s.Level`), Crew (ScreensCrew L48 `#s.Equipped`) and Cases (L129) dereference `State.Data` with no `if not s then return end`. Unlike Shop, Skills and Roadcases, which do check.
- **Fix (gegengeprüft):** Wrap the builder call in UI.Open and refreshNow: `local ok, err = pcall(w.Builder, w.Content, w, arg); if not ok then warn("[UI] "..id..": "..tostring(err)); UI.Text(w.Content, "Fehler beim Laden – bitte erneut öffnen.", 14, { Color = T.Bad }) end`, as ScreensAdmin already does per tab. Add `if not s then return end` to the listed builders.

### B70 · LOW · correctness — Scroll restore is keyed by ScrollingFrame.Name, but several scrolls share the default name 'Scroll'
`StarterPlayer.StarterPlayerScripts.Client.UI` ~Zeile 361 · Aufwand S
- **Problem:** `if d:IsA("ScrollingFrame") then scrolls[d.Name] = d.CanvasPosition end` and restore by name. UI.Scroll defaults `Name = props.Name or "Scroll"`. FastTravel creates two unnamed scrolls, `local left = UI.Scroll(body, {...})` and `local right = UI.Scroll(body, {...})` (ScreensTravel L77/L79). The Admin item picker (ScreensAdmin L332) is also unnamed.
- **Fix (gegengeprüft):** Pass unique names: UI.Scroll(body, {Name="TravelLeft", ...}) and UI.Scroll(body, {Name="TravelRight", ...}), and do the same for the unnamed Admin picker. Another option is to key the saved positions by d:GetFullName() relative to Content plus an occurrence counter. Sibling scrolls with the same name would still collide, so a counter per name is the more robust choice.

### B71 · LOW · memory-leak — Closed windows keep their full UI tree (model clones, spinning viewports) alive until reopened
`StarterPlayer.StarterPlayerScripts.Client.UI` ~Zeile 389 · Aufwand S
- **Problem:** UI.Close only hides the window: `task.delay(0.12, function() if UI.Current ~= w then w.Frame.Visible = false end end)`. The content is destroyed only on the next UI.Open (`for _, c in ipairs(w.Content:GetChildren()) do c:Destroy() end`). Spinning viewports check only their own flags: `if not vp.Parent then conn:Disconnect() return end if vp.Visible then a += dt * 0.6 place(a) end`. A viewport inside a hidden window still has Parent set and …
- **Fix (gegengeprüft):** In UI.Close: `task.delay(0.12, function() if UI.Current ~= w then w.Frame.Visible = false if w.Builder then w.Content:ClearAllChildren() end end end)`. In UI.Open: `if UI.Current and UI.Current ~= w then UI.Current.Frame.Visible = false if UI.Current.Builder then UI.Current.Content:ClearAllChildren() end end`. Optionally, also make the spin loop in UI.Viewport stop when the viewport is not actually on screen, e.g. `if vp.Visible and vp:FindFirstAncestorWhichIsA("GuiObject") and vp.AbsoluteSize.X > 0` (or check that the window frame is visible). This is optional, because once Content is cleared on close the loop disconnects itself.
