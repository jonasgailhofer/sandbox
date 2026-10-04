# Befundliste Stufe C: Performance & Netzwerk (Server, Client, Replikation)

Quelle: Multi-Agent-Code-Audit von `Place1backup1_klein.rbxl` (Stand 04.10.2026). Jeder Befund wurde von mindestens einem unabhängigen Prüfer im Code gegengeprüft, kritische und hohe Befunde von zwei Prüfern.
- **Zeilennummern** beziehen sich auf diesen Stand. Suche im aktuellen Code nach dem zitierten Snippet, nicht nach der Zeilennummer.
- **Fix (gegengeprüft)** ist der vom Prüfer korrigierte Fix. Er hat Vorrang vor dem ursprünglichen Vorschlag.
- Die Befundtexte sind auf Englisch, die IDs (C01 …) dienen dem Status-Tracking in `ServerStorage.DevTools.PolishLog` (Block Z).

## Übersicht

| ID | Schwere | Datei | Titel |
|---|---|---|---|
| C01 | medium | ItemRegistry | R.Score is recomputed inside sort comparators for every inventory unit; GetBoard runs this |
| C02 | medium | Main | Full State snapshot (~10-20 KB) re-sent on every change instead of deltas |
| C03 | medium | CarryService | CarryService.Refresh rebuilds the whole hand-carried visual on every single Take/Pop (up t |
| C04 | medium | PlotService | RenderRacks tears down and rebuilds the whole rack display on every inventory change |
| C05 | medium | ShopService | SelectVehicle always destroys and re-clones the truck, even for the already active vehicle |
| C06 | medium | Crowd | Crowd.Spawn does all its work in one frame: up to 1840 raycasts, an O(n²) spacing check an |
| C07 | medium | Pets | Pets: per-pet, per-frame raycast with a freshly built exclude list |
| C08 | medium | ScreensCrew | Whole window is rebuilt on every selection click, re-cloning every 3D preview (up to 100 p |
| C09 | medium | ScreensJobs | Jobs board refetches GetBoard (a quote for every job on the server) on each expand/collaps |
| C10 | medium | ScreensJobs | Spedition window starts a new self-rescheduling refresh chain on every build |
| C11 | medium | ClientMain | Refreshable windows rebuild completely on every State push, including Garage which re-clon |
| C12 | low | JobLogic | J.TypeModelFor is uncached and called inside per-copy loops |
| C13 | low | Loc | Loc.T can yield (GetTranslatorForPlayerAsync) inside every Toast/Banner and retries every  |
| C14 | low | NavGraph | NavGraph builds all region graphs lazily on the first navigation frame; Project() scans fu |
| C15 | low | Net | Purely cosmetic FX are sent on the reliable FX remote; no UnreliableRemoteEvent exists |
| C16 | low | Net | Net.Get calls WaitForChild on every send (ctx.Notify/FX/FireRegion) |
| C17 | low | Sounds | Sounds.At creates a Part in workspace for every positional sound |
| C18 | low | WorldConfig | WorldConfig.ComputeReq scans the full item table for every slot × 3 keys at module load, o |
| C19 | low | Main | The snapshot dedupe is defeated during jobs by per-second countdown fields, so every Push  |
| C20 | low | Main | Read-only requests still mark the player dirty and trigger a full snapshot build and encod |
| C21 | low | Main | Join latency: PolicyService (with a 1 s retry) and Admin rank checks run serially before D |
| C22 | low | DataService | Autosave fires all profile saves in the same frame |
| C23 | low | JobService | stageCount scans all venue children on every JobAvailable/freeStage call |
| C24 | low | PlazaService | Plaza mode scans the entire workspace (~383k instances) synchronously |
| C25 | low | PlazaService | Pre-teleport Save(p,false) in Goto/Return duplicates the release-save that onLeave does se |
| C26 | low | PlazaService | Plaza teleport saves with the lock kept, so the destination's first Load is always LOCKED  |
| C27 | low | PlotService | Prompt fallbacks: missing markers are re-searched recursively on every call; UpdateSign sc |
| C28 | low | PlotService | rackLayout re-sorts the inventory with table.find inside the comparator on every RackPath/ |
| C29 | low | PlotService | RefreshRackPrompts scans every case part and calls RackNeed per tag on every pick |
| C30 | low | ShowService | Show start, teardown and cleanup are broadcast to every client in all three cities |
| C31 | low | TradeService | Trade loop does recursive FindFirstChild over every child of World.Trading (including the  |
| C32 | low | VehicleService | renderCargoNow destroys and recreates every cargo box and weld on each change |
| C33 | low | VehicleService | Cargo Case/Edge parts keep CanTouch=true, so HighwayTrigger.Touched fires once per cargo p |
| C34 | low | WarehouseBuilder | Any module upgrade rebuilds the entire warehouse (up to ~2250 instances) and invalidates a |
| C35 | low | Ambient | Ambient probes attributes on every descendant added anywhere in workspace (plus a full Get |
| C36 | low | CrewDirector | CrewDirector: recursive FindFirstChild('Staging', true) on the whole company model every 0 |
| C37 | low | Crowd | Per-frame redundant property writes (crowd phone lights) |
| C38 | low | Effects | Teardown animation runs on every client in the server regardless of distance (FireAllClien |
| C39 | low | Effects | GPS RenderStepped rebuilds label strings and sets Text every frame |
| C40 | low | Ghosts | Ghosts.Recolor walks every ghost's full descendant tree on every State push |
| C41 | low | Navigator | Navigation visuals: ~41 individual part CFrame writes per frame, ClockTime re-read per che |
| C42 | low | RigAnim | RigAnim.SetAlpha walks GetDescendants on every call, and callers use it per frame during f |
| C43 | low | Robots | Robots: idle shuttles are PivotTo'd, searched with FindFirstChild and recoloured every fra |
| C44 | low | ScreensAdmin | Admin panel rebuilds a button for every item on every action, plus an Overview poll every  |
| C45 | low | ShowDirector | ShowDirector writes every light, beam and LED property every frame, including constants, a |
| C46 | low | State | Client State.Changed is a BindableEvent fired with (s, prev): Roblox deep-copies both full |
| C47 | low | Traffic | Traffic obstacles(): GetBoundingBox on every vehicle model on the server every 0.25 s, wit |
| C48 | low | UI | UI.Bar creates a new Tween on every call, and the HUD's 1 s loop re-runs the full update |
| C49 | low | UI | Spinning viewports keep a RenderStepped connection running after their window is closed |
| C50 | low | UI | Banners have no cap and Toast rebuilds its icon table on every call |

## Details

### C01 · MEDIUM · perf-server — R.Score is recomputed inside sort comparators for every inventory unit; GetBoard runs this for about 36 jobs per request
`ReplicatedStorage.Modules.ItemRegistry` ~Zeile 447 · Aufwand S
- **Problem:** function R.Score(id)
  local it = I[id] ... local v = (p.Audio or 0) + (p.Light or 0) / 10 + (p.FX or 0) * 400 + (p.Stage or 0) * 40 + (p.Power or 0) * 5
  return v * 100 + (R.QualityRank[it.Quality] or 0)
JobLogic.Assign L77-84 expands the inventory into one entry per unit (`for _ = 1, n do table.insert(byType[t], id) end`) and then `table.sort(list, function(a, b) return R.Score(a) > R.Score(b) end)`. That is two table lookups plus arithmetic per comparison. JobService.Board (L484-509) calls S.Quote, then S.Plan, then J.Assign for all W.Jobs (33) plus every open tender. H.GetBoard is a client remote (Main L222), and the token bucket allows 15 calls per second. With storage capacity up to roughly 2000 units, one GetBoard costs about 36 × 2000·log2(2000)·2 ≈ 1.6M Score calls.
- **Auswirkung:** Measurable server CPU per GetBoard. A client that spams GetBoard at the allowed 15/s can cause server-wide frame drops.
- **Fix (gegengeprüft):** ItemRegistry: after the item table is built, add `for _, it in pairs(I) do local p = it.Points or {}; local v = (p.Audio or 0) + (p.Light or 0)/10 + (p.FX or 0)*400 + (p.Stage or 0)*40 + (p.Power or 0)*5; it._Score = v*100 + (R.QualityRank[it.Quality] or 0) end` and change it to `function R.Score(id) local it = I[id]; return it and it._Score or 0 end`. This keeps the same formula and adds nothing to the saved data. JobLogic.Assign: group the unique ids per type, sort each group once with `table.sort(ids, function(a,b) return R.Items[a]._Score > R.Items[b]._Score end)`, and only then expand them into per-unit copies, or better, keep a cursor and remaining count per id instead of using table.remove(list, 1). Optionally cache the Board result per player for about 1 s, and invalidate the cache when inventory or level changes. Note that the per-action limit is 0.12 s (about 8/s), not 15/s.

### C02 · MEDIUM · network — Full State snapshot (~10-20 KB) re-sent on every change instead of deltas
`ServerScriptService.Main` ~Zeile 188 · Aufwand M
- **Problem:** snapshot() (L141-170) bundles Inventory, Crew (up to 100 pets), Staff (Hired/Auto/Pending/Log), Job.Public (one entry per slot plus staging/rack lists), Stats, Milestones, Roadcases, Bonuses and more into one table. The push loop compares the JSON of the whole snapshot and then sends all of it:
`if not okJ or json ~= lastSnapJson[p] then ... Net.Get("State"):FireClient(p, snap)`.
During packing and building, every crew step really changes state (crewLoop calls ctx.Push at L1294/1334/1393/1403, B.Put at L204, SpawnStaging, AddCargo). So the dedupe rarely helps and the whole snapshot goes out 1-5 times/s per active player (the loop runs at 5 Hz). PolishLog lists state deltas under 'BEWUSST NICHT'.
- **Auswirkung:** Estimated at 20 players with active jobs: 20-80 full snapshots/s. Server CPU for snapshot + JSONEncode is about 10-40 ms/s. Egress is about 15-60 KB/s per player, roughly 0.3-1.2 MB/s total, which is at or above Roblox's comfortable per-client budget and competes with physics and instance replication. The client also re-runs every State.Changed listener (HUD, ScreensCrew, Effects, Ghosts...) on a full table.
- **Fix (gegengeprüft):** Server (Main, replace L173-195 body; keep pcall around snapshot):
```lua
local lastPart = {} -- [p] = {[key]=json}
...
if ok and snap then
  local prev = lastPart[p]
  local full = prev == nil
  prev = prev or {}
  local delta, gone, any = {}, {}, full
  for k, v in pairs(snap) do
    if k ~= "ServerTime" then
      local j
      if type(v) == "table" then
        local okJ, enc = pcall(HttpService.JSONEncode, HttpService, v)
        j = okJ and enc or nil -- encode failure => always treat as changed
      else
        j = typeof(v) .. ":" .. tostring(v)
      end
      if full or j == nil or j ~= prev[k] then delta[k] = v; prev[k] = j; any = true end
    end
  end
  for k in pairs(prev) do if snap[k] == nil then gone[k] = true; prev[k] = nil; any = true end end
  lastPart[p] = prev
  if any then
    delta.ServerTime = snap.ServerTime
    Net.Get("State"):FireClient(p, { D = delta, R = gone, Full = full })
    updateLeaderstats(p)
  end
end
```
Set `lastPart[p] = nil` in the leave handler (where lastSnapJson[p] is cleared now, L494). To force a resync anywhere, set lastPart[p] = nil and ctx.Push(p).
Client State.lua:
```lua
Net.Get("State").OnClientEvent:Connect(function(msg)
  local prev = State.Data
  local s = (msg.Full or not prev) and {} or table.clone(prev)
  for k, v in pairs(msg.D) do s[k] = v end
  for k in pairs(msg.R) do s[k] = nil end
  State.Data = s
  changed:Fire(s, prev)
end)
```
Ship the server and client changes together. Save data is not affected.

### C03 · MEDIUM · perf-server — CarryService.Refresh rebuilds the whole hand-carried visual on every single Take/Pop (up to 12 rebuilds per click)
`ServerScriptService.Server.CarryService` ~Zeile 109 · Aufwand S
- **Problem:** Take (L52) and Pop (L63) each call `C.Refresh(p)` synchronously. Refresh destroys CarryVisual and creates up to 11 Case+Edge parts with welds plus an ItemVisual clone (L114-163). JobService.Unload loops `for _ = 1, 12 do ... ctx.Carry.Take(p, id, from)` (JobService L1150-1167), and CargoInteract pops in a while loop (JobService L1095-1104), so about 12 full rebuilds (more than 150 Instance.new/Destroy calls, all replicated to everyone near the character) happen in one frame. VehicleService already solved the same problem with a deferred dirty flag (L301-313).
- **Auswirkung:** Server CPU spikes and replication bursts on every load or unload click, multiplied by player count. Clients near busy players get a visible hitch.
- **Fix (gegengeprüft):** Split C.Refresh into an immediate part and a deferred part.

The immediate part runs C.UpdateSpeed(p) and sets the CarryCount and CarryTop attributes. Move those two SetAttribute calls before the hrp check so they also apply when there is no character.

Then schedule the rebuild the same way VehicleService.RenderCargo does:

```lua
local s = ctx.Sessions[p]
if not s or s.CarryDirty then return end
s.CarryDirty = true
task.defer(function()
  s.CarryDirty = nil
  if p.Parent and ctx.Sessions[p] == s then
    local ok, err = pcall(buildCarryVisual, p)
    if not ok then warn("[Carry] Refresh: " .. tostring(err)) end
  end
end)
```

buildCarryVisual is the current L111-163 body without the attribute lines. It reads C.List(p) at run time, so it always draws the final state.

In the stack loop, create the edge with `local edge = box:Clone()` before calling `weld(box)`, or build the edge with Instance.new. Then the clone carries no WeldConstraint and the GetChildren/Destroy loop at L150 can be removed.

Optional: limit the stack loop to math.min(#list-1, G.MaxCarryVisual). This changes the visuals, so treat it as a design decision rather than part of this fix.

### C04 · MEDIUM · perf-server — RenderRacks tears down and rebuilds the whole rack display on every inventory change
`ServerScriptService.Server.PlotService` ~Zeile 377 · Aufwand M
- **Problem:** renderRacksNow (L377-454): `local f = m:FindFirstChild("RackItems") if f then f:Destroy() end f = Instance.new("Folder") ...` and then for every unit `local case = Instance.new("Part") ...` plus a Part + SurfaceGui + TextLabel per item type per bay, plus a cloned Equipment model per type (`P.ItemVisual(u.Id, ...)`), then `P.RefreshRackPrompts(p)` recreates the prompts. Capacity at max level is 1956 places (PolishLog K: 326 bays), so this can be ~2000 Parts and a few hundred GUIs. ctx.OnInventoryChanged (Main L101-104) triggers it on every ShopService.BuyItem/SellItem (L61/L76/L89/L98), roadcase open and admin change. The 0.15 s debounce (L490-501) still allows about 6 full rebuilds per second, and the token bucket allows 15 remotes/s. The model is PersistentPerPlayer for the owner (L61-63), so every rebuild replicates fully to the owner plus streaming visitors.
- **Auswirkung:** Selling or buying single items in a row destroys and recreates thousands of instances each time. That causes server CPU spikes, a replication burst (destroy and create all instances) and client hitches. It scales with warehouse size, so late-game players are hit hardest, and several of them in one server stack up.
- **Fix (gegengeprüft):** Reconcile into reused instances instead of rebuilding per bay or from scratch. Same visuals, save data untouched:

1. Skip identical layouts. Have rackLayout return the cache table, or compare `pl.RackLayout`. Keep `pl.RackRendered`. At the top of renderRacksNow, after rackLayout: `if pl.RackRendered == pl.RackLayout and m:FindFirstChild("RackItems") then P.RefreshRackPrompts(p) return end`. At the end, set `pl.RackRendered = pl.RackLayout`.

2. Reuse the folder: create RackItems only if it is missing.

3. Pool the case Parts by index. Walk the units in bay order and keep a counter `ci` for the non-detail units. `local case = pl.RackCases[ci]`; if it is nil, create it with the static props (Anchored/CanCollide/CanQuery/CanTouch/CastShadow/Name) and store it. Then set Size, CFrame, Color and Material, assigning each only when it differs from the current value. After the loop, destroy and drop `pl.RackCases[ci+1..#pool]`.

4. Key the detail visuals by item id in `pl.RackVisuals[id] = {Model=vis, W=w}`. Reuse and just `vis:PivotTo(base)` when `w` is unchanged. Clone again only when the type is new or `w` changed. Destroy the entries for ids no longer shown.

5. Key the tags as `pl.RackTagsByKey[bi..":"..id]`. Reuse each tag and update its Size, CFrame and TextLabel.Text/TextColor3. Create a tag only for a new key and destroy tags whose key disappeared. Existing ProximityPrompts survive because their Triggered closure captures the same id. Keep the live tags in a list and iterate that list in RefreshRackPrompts.

6. In ApplyExpansions, where it already sets `pl.RackSlots = nil; pl.RackLayout = nil`, also destroy RackItems and clear `pl.RackCases`, `pl.RackVisuals`, `pl.RackTagsByKey` and `pl.RackRendered`, because the slot parts were rebuilt. Release/model destroy then drops them with the session.

With this, selling one item changes only properties, mostly CFrames of the shifted cases, plus one Part destroy. That replicates as small property deltas instead of thousands of instance creates and destroys.

### C05 · MEDIUM · perf-server — SelectVehicle always destroys and re-clones the truck, even for the already active vehicle: a cheap remote for heavy server work
`ServerScriptService.Server.ShopService` ~Zeile 119 · Aufwand S
- **Problem:** if ctx.Sessions[p].Job then return false, ... end
d.ActiveVehicle = id
ctx.Vehicles.Spawn(p)
VehicleService.Spawn: `if s.Truck then s.Truck:Destroy() ... local m = src:Clone() ... m.ModelStreamingMode = PersistentPerPlayer ... ProximityPrompt + 2 connections ... m.Parent = folder`
- **Auswirkung:** An exploiter, or a player clicking repeatedly, can call SelectVehicle about 8 times per second (0.12 s per-action limit) with the same id. Each call clones a full vehicle model, replicates it, creates a prompt and connections, and destroys the previous truck, which costs server time and network bandwidth for every client in range. It also resets any truck the player is standing next to.
- **Fix (gegengeprüft):** In ShopService.SelectVehicle, after the Job check:
local s = ctx.Sessions[p]
if d.ActiveVehicle == id and s.Truck and s.Truck.Parent then return true, V.Vehicles[id].Name .. " ist bereits aktiv." end
local now = os.clock()
if s.LastVehicleSelectAt and now - s.LastVehicleSelectAt < 2 then return false, "Bitte kurz warten." end
s.LastVehicleSelectAt = now
d.ActiveVehicle = id
ctx.Vehicles.Spawn(p)
(Put the cooldown in SelectVehicle, not in Spawn, so that admin and internal respawns are not throttled.)

### C06 · MEDIUM · perf-client — Crowd.Spawn does all its work in one frame: up to 1840 raycasts, an O(n²) spacing check and ~1600 parts parented into a live folder
`StarterPlayer.StarterPlayerScripts.Client.Crowd` ~Zeile 49 · Aufwand S
- **Problem:** `folder.Parent = workspace` (L49) happens before parts are created. Then `while #people < n and tries < n * 8 do ... workspace:Raycast(...) ... for _, o in ipairs(people) do local d = o.Pos - hit.Position ...` (L74-94) with n up to 230 (countFor clamps to 230), followed by 5-7 `newPart(folder, ...)` per person (L108-120). Each newPart sets `p.Parent = folder` while the folder is already in workspace. Every insertion is a separate scene and Ambient.DescendantAdded event (Ambient L223 register runs 4 GetAttribute calls per part).
- **Auswirkung:** A visible hitch when a show starts on a large stage (Stadion/Arena, big stage size), especially on mobile. That is exactly when the player is watching.
- **Fix (gegengeprüft):** Remove `folder.Parent = workspace` at L49 and put it right before `local crowd = { Folder = folder, People = list }` (after the person loop at L122). Then all ~1,500 parts enter workspace in one ancestry change, and the DescendantAdded handlers still fire, but in one batch after the parts are built rather than interleaved with part creation. Keep `folder` in the raycast exclude list (harmless). Optional: replace the linear spacing scan with a hash grid keyed by math.floor(x/2.2), math.floor(z/2.2), checking the 3x3 neighbouring cells, which gives the same result because 2.2^2 > 4.6. If creation is spread over frames (task.wait every ~40 people), build into a local list and return the crowd only when finished, or make ShowDirector call Spawn inside task.spawn and assign `crowd` when it completes, checking that the show has not already ended (`running[key]`) so it doesn't leak a folder.

### C07 · MEDIUM · perf-client — Pets: per-pet, per-frame raycast with a freshly built exclude list
`StarterPlayer.StarterPlayerScripts.Client.Pets` ~Zeile 105 · Aufwand S
- **Problem:** Inside `for _, e in ipairs(st.Pets)` within `for pl, st in pairs(state)` (Heartbeat):
```
local ex = { folder }
for _, other in ipairs(Players:GetPlayers()) do if other.Character then table.insert(ex, other.Character) end end
local veh = workspace.World and workspace.World:FindFirstChild("Vehicles")
if veh then table.insert(ex, veh) end
rayParams.FilterDescendantsInstances = ex
local hit = workspace:Raycast(target + V3(0, 6, 0), V3(0, -14, 0), rayParams)
```
For every visible pet on every frame, this allocates a new table, walks all players, sets FilterDescendantsInstances (which copies the array into the engine) and casts a ray. With N players in range and 4 pets each, that is about 4·N table builds, 4·N filter assignments and 4·N raycasts per frame, and each build is O(N), so cost grows as O(N²). The Plaza trading hub is where everyone gathers with their pets, so it is the worst case.
- **Auswirkung:** Noticeable frame time on mobile in crowded areas such as the Plaza and depots. With 15 players nearby that is 60 raycasts and 60 filter rebuilds of about 16 entries every frame, plus GC churn.
- **Fix (gegengeprüft):** This fix keeps behaviour the same and needs no save-data change: build the filter once per frame, outside both loops, and only when at least one pet is visible.

At the top of step(dt), after `local now = os.clock()`:
```lua
local filterReady = false
local function ensureFilter()
	if filterReady then return end
	filterReady = true
	local ex = { folder }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then ex[#ex + 1] = other.Character end
	end
	local world = workspace:FindFirstChild("World")
	local veh = world and world:FindFirstChild("Vehicles")
	if veh then ex[#ex + 1] = veh end
	rayParams.FilterDescendantsInstances = ex
end
```
Replace L105-109 with a single line, `ensureFilter()`, and keep the Raycast on L110 unchanged.

You can go further and throttle the ground ray per pet, for example by re-casting only when `not e.GroundT or now - e.GroundT > 0.15 or (target - e.GroundAt).Magnitude > 1` and caching `e.GroundY`. This changes visuals only slightly and is optional; the per-frame filter build above removes the O(N²) part.

Also consider wrapping the body of `step` in pcall, or guarding it, so one error does not repeat every frame.

### C08 · MEDIUM · perf-client — Whole window is rebuilt on every selection click, re-cloning every 3D preview (up to 100 pets)
`StarterPlayer.StarterPlayerScripts.Client.ScreensCrew` ~Zeile 100 · Aufwand M
- **Problem:** The Crew grid builds one `UI.Viewport(f, crewModel(cm.T), ...)` per pet (L95). G.CrewInventoryMax = 100. Each card has `f.Activated:Connect(function() ... sel = uid UI.Refresh("Crew") end)`. refreshNow (UI L363-364) destroys all content and calls the builder again, so every viewport runs `model:Clone()`, a GetDescendants sweep, a WorldModel and a Camera again (UI L236-258). The same pattern exists in the Shop grid (ScreensShop L84-88 `sel = id UI.Refresh("Shop")`, 45 viewports on the Roadcase tab), the Roadcases item rows (ScreensRoadcase L244-249, 3 spinning case viewports plus the detail viewport rebuilt on every row click) and the Trade window (ScreensCrew L333-335, which rebuilds every pet viewport on every State push and every trade message).
- **Auswirkung:** Picking a pet or item clones up to roughly 100 models and creates about 100 ViewportFrames and WorldModels plus around 1,000 GUI instances. This causes visible frame hitches, worst on mobile, and memory churn on the most-used collection screens.
- **Fix (gegengeprüft):** In the Crew builder, keep a `cards = {}` table that maps uid to `{f = f, stroke = stroke}`; `UI.Stroke` returns the stroke, or you can find it with `f:FindFirstChildOfClass("UIStroke")`. Move the detail-panel drawing (L108-123) into a local `drawDetail()` that runs `for _, ch in ipairs(d:GetChildren()) do ch:Destroy() end` and then redraws the panel. Destroying the spin viewport is safe: its RenderStepped handler checks `vp.Parent` and disconnects itself. Change the card click handler to `if sel == uid then return end; local old = cards[sel]; if old then old.f.BackgroundColor3 = T.Panel; old.stroke.Thickness = 1; old.stroke.Transparency = 0.3 end; sel = uid; local nw = cards[uid]; nw.f.BackgroundColor3 = Color3.fromRGB(208,230,255); nw.stroke.Thickness = 2; nw.stroke.Transparency = 0; drawDetail()`. Keep `UI.Refresh("Crew")` in the Equip, Lock and Recycle buttons, because they change data. Apply the same pattern to the ScreensShop grid (L84-88: restore the stroke colour `qc` vs `T.Primary` and redraw only `detail`). For the Trade window, only rebuild the offer lists when the trade message or the relevant State fields actually change. This is optional and can be done separately. No save or behaviour changes.

### C09 · MEDIUM · network — Jobs board refetches GetBoard (a quote for every job on the server) on each expand/collapse, and the scroll position jumps to the top
`StarterPlayer.StarterPlayerScripts.Client.ScreensJobs` ~Zeile 204 · Aufwand M
- **Problem:** The 'Bedarf zeigen' button runs `expanded[key] = not isOpen UI.RefreshNow("Jobs")`. The locked toggle (L323-324) and the tab buttons (L255) do the same. Each build does `task.spawn(function() local ok, _, board = State.Request("GetBoard", nil, true) ...`. Server-side, JobService.Board L484-509 runs `S.JobAvailable` + `S.Quote` + `S.EquipCheck` for every W.Jobs entry and every tender. refreshNow restores scroll with `task.defer(function() d.CanvasPosition = pos end)` (UI L368), but the list is still empty at that point because it is filled asynchronously after the InvokeServer returns, so the restored position clamps to 0.
- **Auswirkung:** Every expand or collapse costs a full server round trip and a quote computation for all jobs, which adds server load from a pure UI toggle. The player also loses their scroll position: expanding a card near the bottom jumps the list back to the top.
- **Fix (gegengeprüft):** Keep the cache, but add these safeguards:
1. Add `local lastBoard, lastBoardAt` at module scope.
2. Move the card-filling code into a local `render(board)`.
3. In the builder, if `lastBoard` exists, `os.clock() - lastBoardAt < 5` and `UI.Current.Arg` (or a `forceFetch` flag) does not ask for a refetch, call `render(lastBoard)` synchronously and remove the loading label. Then refreshNow's deferred CanvasPosition restore works.
4. Otherwise fetch as today, then set `lastBoard = board; lastBoardAt = os.clock()`.
5. Invalidate the cache (`lastBoard = nil`):
   - in UI.OnOpen / UI.Open for "Jobs", so every window open gets a fresh board;
   - after AcceptJob or AcceptTender succeeds;
   - when a State push changes Level, Job or Inventory, so the Ok/Why/Quote values are never shown stale.

A smaller alternative that fixes only the scroll jump: in the async branch, save `local pos = list.CanvasPosition` before the fetch, or read it from a module upvalue set by the toggles, and set `list.CanvasPosition = pos` after the cards are created.

### C10 · MEDIUM · perf-client — Spedition window starts a new self-rescheduling refresh chain on every build
`StarterPlayer.StarterPlayerScripts.Client.ScreensJobs` ~Zeile 464 · Aufwand S
- **Problem:** In the Spedition builder: `task.delay(1, function() if UI.Current and UI.Current.Id == "Spedition" then UI.Refresh("Spedition") end end)`. Every build schedules another build. Spedition is also in ClientMain's `refreshable` list, and during jobs the snapshot changes about once per second because JobService.Public sends `DeadlineIn = math.floor(job.Deadline - os.clock())` and per-truck `In` values. So each State push adds another independent 1 s chain. Chains only merge when two requests fall into the same 0.25 s debounce window.
- **Auswirkung:** While trucks are booked, the Logistik window settles at roughly 4 full rebuilds per second (panels, J.Load, chips). This costs CPU and garbage collection and causes flicker.
- **Fix (gegengeprüft):** At module scope in ScreensJobs, add `local spedTimer = nil`. In the builder, replace the task.delay with:

```lua
if not spedTimer then
  spedTimer = task.delay(1, function()
    spedTimer = nil
    if UI.Current and UI.Current.Id == "Spedition" then UI.Refresh("Spedition") end
  end)
end
```

### C11 · MEDIUM · perf-client — Refreshable windows rebuild completely on every State push, including Garage which re-clones 4 truck models into ViewportFrames
`StarterPlayer.StarterPlayerScripts.ClientMain` ~Zeile 66 · Aufwand M
- **Problem:** ClientMain L64-67: `local refreshable = { Packing = true, Daily = true, Garage = true, Company = true, Premium = true, Spedition = true, Skills = true, Staff = true, Dispatch = true }` / `State.Changed:Connect(function() if UI.Current and refreshable[UI.Current.Id] then UI.Refresh(UI.Current.Id) end end)`. UI.refreshNow (UI L356-372) then does `for _, c in ipairs(w.Content:GetChildren()) do c:Destroy() end; w.Builder(...)` plus two full `GetDescendants()` scans to save and restore scroll positions. The Garage builder (ScreensShop L174) calls `UI.Viewport(f, RS.Assets.Vehicles:FindFirstChild(v.Model), ...)` for all 4 vehicles. In the place file Truck_Van/Box75/Heavy18/Titan40 have 111/127/155/207 descendants. UI.Viewport clones each one and walks GetDescendants twice. So any snapshot change (Cash, Carry, staff income, job countdowns such as DeadlineIn/In, which change every second) destroys and rebuilds roughly 600 parts plus about 100 GUI instances, up to 4 times per second given the 0.25 s debounce. The fields that changed usually have nothing to do with the open window. …
- **Auswirkung:** Visible hitches and GC pressure while a menu is open during a job, worst on mobile. Garage, Company and Staff are the heaviest. Buttons the user is hovering are recreated, so hover/press tweens restart and clicks can land in the 0.25 s window guard.
- **Fix (gegengeprüft):** Add an optional `w.Sig` per window and keep today's behaviour as the default. In ClientMain: `State.Changed:Connect(function(s) local w = UI.Current; if not (w and refreshable[w.Id]) then return end; if w.Sig then local sig = w.Sig(s); if sig == w.LastSig then return end; w.LastSig = sig end; UI.Refresh(w.Id) end)`. In UI.Open, after the builder runs, set `w.LastSig = w.Sig and State.Data and w.Sig(State.Data)` (or set it in the builder itself, as ScreensRoadcase L171 does). Explicit UI.Refresh calls from buttons stay as they are. Only give a Sig to windows whose rendered inputs are fully known. Garage: `(s.ActiveVehicle or '')..'|'..s.Level..'|'..table.concat(sortedKeys(s.Vehicles), ',')`, where the keys must be sorted because pairs order is not stable. Daily: `tostring(s.Daily.Ready)..'|'..s.Daily.Streak..'|'..tostring(s.Daily.Last)`. Skills: SkillPoints, SkillResets, SkillTotal, plus a sorted serialization of s.Skills levels, not `#s.Skills` (s.Skills is likely a map, so # is unreliable). Leave Company, Staff, Dispatch, Spedition and Packing without a Sig unless their builders are audited, since they show Cash, timers and job material that do change per push.

### C12 · LOW · perf-server — J.TypeModelFor is uncached and called inside per-copy loops
`ReplicatedStorage.Modules.JobLogic` ~Zeile 195 · Aufwand S
- **Problem:** `for id, it in pairs(R.Items) do if it.Type == t and not it.Exclusive and J.SystemOK(id, job) ...` runs on every call (J.TypeModel above is cached in repCache). JobService calls it as `for _ = 1, n do table.insert(ids, J.TypeModelFor(t, job)) end` at L372, L428, and L443, and once more at L417, for every job in Board.
- **Fix (gegengeprüft):** First, hoist the call out of the loops in JobService at L372, L428 and L443: `local rep = J.TypeModelFor(t, job); for _ = 1, n do table.insert(ids, rep) end`. Only if you want a cache too, key it on every field that J.SystemOK(id, job) reads, for example `t .. "|" .. tostring(job.System)`. Store `false` when nothing matches, so a miss is cached as well and the TypeModel fallback still applies.

### C13 · LOW · perf-client — Loc.T can yield (GetTranslatorForPlayerAsync) inside every Toast/Banner and retries every 5 s on failure
`ReplicatedStorage.Modules.Loc` ~Zeile 23 · Aufwand S
- **Problem:** getTranslator(), called from Loc.T, which UI.Toast and UI.Banner call: `local ok, tr = pcall(LS.GetTranslatorForPlayerAsync, LS, p)`. That is a web-backed, yielding call. Failure is cached only for 5 s (`if triedAt and os.clock() - triedAt < 5 then return nil end`). While a call is in flight, a second caller sees triedAt and gets nil, so its text is untranslated.
- **Fix (gegengeprüft):** When the client starts, set translator synchronously from pcall(t.GetTranslator, t, Loc.Locale()). Then run task.spawn(function() local ok,tr=pcall(LS.GetTranslatorForPlayerAsync,LS,Players.LocalPlayer) if ok and tr then translator=tr end end) so the player translator replaces it later. In getTranslator(), never call the Async API inline. Keep the 5 s retry only for the case where the Localization table is missing.

### C14 · LOW · perf-client — NavGraph builds all region graphs lazily on the first navigation frame; Project() scans full squares per ring
`ReplicatedStorage.Modules.NavGraph` ~Zeile 115 · Aufwand S
- **Problem:** `function G.Regions(baseOnly) ... if not regions then regions = {} for _, rd in ipairs(ND) do regions[rd.Name] = build(rd, EXTRA[rd.Name]) end end` (L115-118). The first caller is `NG.RegionAt(pos)` in Navigator.step on Heartbeat (Navigator L228), so all three cities (about 90 KB of NavData: nodes, adjacency, segments, spatial grid, and an O(baseN) Join scan per extra line, L68-71) are built in a single frame. In Project: `for ring = 0, maxRing …
- **Fix (gegengeprüft):** Prewarm with `task.defer(function() NG.Regions() end)` rather than `task.defer(NG.Regions)`. Passing the function directly is equivalent today, but the wrapper makes it explicit that baseOnly is nil. In Project, visit only the ring's edge cells: when ring == 0, check only the single cell (0,0). Otherwise, check rows dz = -ring and dz = ring for dx from -ring to ring, then columns dx = -ring and dx = ring for dz from -ring+1 to ring-1. Put the segment test in a local helper so each edge cell is tested once.

### C15 · LOW · network — Purely cosmetic FX are sent on the reliable FX remote; no UnreliableRemoteEvent exists
`ReplicatedStorage.Modules.Net` ~Zeile 5 · Aufwand S
- **Problem:** `Net.Events = { "State", "Notify", "Broadcast", "FX", "Show", ... }` contains only RemoteEvents. Cosmetic one-shots such as `ctx.FireRegion("FX", ..., "CrewDrop", { Pos = ..., Big = big })` (JobService L1332, L1400, L1509) and `FireClient(p, "Loaded", ...)` share the reliable, ordered channel with Route/Rating/LevelUp.
- **Fix (gegengeprüft):** Add an UnreliableRemoteEvent named "FXU" in Net.Init, alongside the existing remotes. Before moving "Loaded" to FXU, check the client handler: it may update a counter or UI and not just play an effect. If so, a dropped packet would lose state, and "Loaded" must stay on the reliable FX remote. Only CrewDrop (dust and pop) is clearly safe to send unreliably. Keep each payload under the roughly 900-byte limit for unreliable remotes. On the client, use WaitForChild("FXU") and connect it to the same dispatcher.

### C16 · LOW · perf-server — Net.Get calls WaitForChild on every send (ctx.Notify/FX/FireRegion)
`ReplicatedStorage.Modules.Net` ~Zeile 32 · Aufwand S
- **Problem:** L30-33 `function Net.Get(name) folder = folder or RS:WaitForChild("Remotes") return folder:WaitForChild(name) end`. Main L44-46 calls it for every Notify, FX and Broadcast, and FireRegion L55 for every world effect.
- **Fix (gegengeprüft):** Cache the result, but do not hard-error after 10 seconds on the client: slow joins or StreamingEnabled-style loading could make the error fire on remotes that do exist. Use this instead:
local cache = {}
function Net.Get(name)
	local r = cache[name]
	if r then return r end
	folder = folder or RS:WaitForChild("Remotes")
	r = folder:WaitForChild(name, 10)
	if not r then
		warn("[Net] Remote fehlt/langsam: " .. tostring(name))
		r = folder:WaitForChild(name)
	end
	cache[name] = r
	return r
end

### C17 · LOW · perf-client — Sounds.At creates a Part in workspace for every positional sound
`ReplicatedStorage.Modules.Sounds` ~Zeile 53 · Aufwand S
- **Problem:** `local p = Instance.new("Part") p.Anchored = true ... p.Parent = workspace ... task.delay(12, function() p:Destroy() end)`. Separately, UI.Init hard-codes `SoundId = "rbxasset://sounds/electronicpingshort.wav"` (UI L302), duplicating `S.Click`.
- **Fix (gegengeprüft):** local a = Instance.new("Attachment"); a.WorldPosition = pos; a.Parent = workspace.Terrain; parent the sound to a; snd.Ended:Once(function() a:Destroy() end); task.delay(12, function() if a.Parent then a:Destroy() end end). Pointing UI.ClickSound at the S.Click id is optional cosmetic dedup.

### C18 · LOW · perf-client — WorldConfig.ComputeReq scans the full item table for every slot × 3 keys at module load, on every client and the server
`ReplicatedStorage.Modules.WorldConfig` ~Zeile 524 · Aufwand S
- **Problem:** local function minFor(typ, lvl, key)
  for _, it in pairs(R.Items) do if it.Type == typ and it.Level <= lvl and not it.Exclusive then ...
function W.ComputeReq(job) for _, s in ipairs(W.ReqSlots(job)) do a += minFor(s.Type, job.Level, "Audio"); l += minFor(..."Light"); stage += minFor(..."Stage") end
L681-684 calls W.NormalizeJob for all 33 jobs at require time. With about 133 items (70 shop + 63 exclusive) and 50-110 required slots per job, …
- **Fix (gegengeprüft):** Memoize per (typ, lvl), computing all three keys in one scan: local minCache = {}; local function minFor(typ, lvl, key) local k = typ .. "|" .. lvl; local c = minCache[k]; if not c then c = {}; for _, it in pairs(R.Items) do if it.Type == typ and it.Level <= lvl and not it.Exclusive then for _, kk in ipairs({"Audio","Light","Stage"}) do local v = it.Points[kk] or 0; if c[kk] == nil or v < c[kk] then c[kk] = v end end end end; minCache[k] = c end; return c[key] or 0 end. When nothing matches, c[key] is nil and the function returns 0, as before.

### C19 · LOW · network — The snapshot dedupe is defeated during jobs by per-second countdown fields, so every Push sends the full state (Inventory, 100 pets, Staff, Stats) again
`ServerScriptService.Main` ~Zeile 182 · Aufwand M
- **Problem:** Main L182-188 only hides ServerTime: `snap.ServerTime = 0 ... if not okJ or json ~= lastSnapJson[p] then ... FireClient(p, snap)`. But Job = ctx.Jobs.Public(p) contains relative countdowns that change every second: JobService L1806 `DeadlineIn = math.floor(job.Deadline - os.clock())`, L1803 `NextIn = ... math.floor(nextIn)`, L1794 `In = math.max(0, math.floor(t + 0.5))`. While a job is active, any ctx.Push (every request, 27 Push sites in …
- **Fix (gegengeprüft):** Leave the countdowns out of the comparison, the same way ServerTime already is, instead of sending partial snapshots. In Main's push loop, before JSONEncode:
```lua
local st = snap.ServerTime; snap.ServerTime = 0
local j = snap.Job; local dl, ni, ins
if j then
  dl = j.DeadlineIn; j.DeadlineIn = nil
  if j.Mat then
    ni = j.Mat.NextIn; j.Mat.NextIn = nil
    ins = {}
    for i, t in ipairs(j.Mat.List or {}) do ins[i] = t.In; t.In = nil end
  end
end
local okJ, json = pcall(HttpService.JSONEncode, HttpService, snap)
snap.ServerTime = st
if j then
  j.DeadlineIn = dl
  if j.Mat then
    j.Mat.NextIn = ni
    for i, t in ipairs(j.Mat.List or {}) do t.In = ins[i] end
  end
end
```
Status changes (truck S field, deliveries added or removed, deadline appearing or clearing) still trigger a push. Only pure countdown ticks are suppressed. A fuller long-term option: also send absolute times …

### C20 · LOW · perf-server — Read-only requests still mark the player dirty and trigger a full snapshot build and encode
`ServerScriptService.Main` ~Zeile 326 · Aufwand S
- **Problem:** Router L326 calls `ctx.Push(p)` unconditionally after every handler, including pure reads: H.GetBoard (L222, polled by ScreensJobs L291), H.TravelList (L253), H.TradePartners (L249), H.AutoPreview (L264). It also pushes for rate-limited/failed actions that returned early. H.LockCrew (L218) pushes a second time on its own.
- **Fix (gegengeprüft):** Skip the push for read-only actions: `local NO_PUSH = { GetBoard = true, TravelList = true, TradePartners = true, AutoPreview = true }` and `if not NO_PUSH[action] then ctx.Push(p) end`. Before adding an action to this list, check that its handler really does not change the profile (for example, that Jobs.Board does not regenerate or store the board in the profile). Removing the extra Push in LockCrew is optional cleanup, because it does nothing.

### C21 · LOW · perf-server — Join latency: PolicyService (with a 1 s retry) and Admin rank checks run serially before Data.Load
`ServerScriptService.Main` ~Zeile 428 · Aufwand S
- **Problem:** L426 `ctx.Admin.Join(p)` (GetRankInGroup for group games), L428-436 GetPolicyInfoForPlayerAsync plus `task.wait(1)` retry, and only then L448 `ctx.Data.Load(p)`, which itself can take seconds. None of these depend on each other.
- **Fix (gegengeprüft):** Set s.Policy = { ArePaidRandomItemsRestricted = true, PolicyFailed = true } right away (fail-closed). Then task.spawn the existing lookup-and-retry logic, and assign s.Policy only on success and only if ctx.Sessions[p] == s still holds (the player may have left). Call Data.Load without waiting for it. Note: anything that reads s.Policy during join (e.g. Monetization.Join) will briefly see the restricted default. That is safe because it fails closed, but if a UI flag is sent once at join, push the state again after the policy arrives.

### C22 · LOW · perf-server — Autosave fires all profile saves in the same frame
`ServerScriptService.Server.DataService` ~Zeile 182 · Aufwand S
- **Problem:** `task.wait(G.AutoSaveInterval) for p in pairs(D.Profiles) do task.spawn(D.Save, p, false) end`. Each D.Save does `U.DeepCopy(d)` plus UpdateAsync. Trades and the Plaza teleport also call D.Save ad hoc (TradeService L119-120, PlazaService L154), which can collide with the burst on the same key (6 s per-key write limit).
- **Fix (gegengeprüft):** Stagger the saves, and skip the save if the player has left by then. Use: local list = {} for p in pairs(D.Profiles) do table.insert(list, p) end; local step = G.AutoSaveInterval / math.max(1, #list) * 0.5; for i, p in ipairs(list) do task.delay((i-1)*step, function() if D.Profiles[p] and p.Parent then D.Save(p, false) end end) end. Spreading the saves over half the interval keeps them from overlapping the next cycle. The `D.Profiles[p]` check stops a delayed save from running on a profile that PlayerRemoving has already released.

### C23 · LOW · perf-server — stageCount scans all venue children on every JobAvailable/freeStage call
`ServerScriptService.Server.JobService` ~Zeile 42 · Aufwand S
- **Problem:** `for _, c in ipairs(f:GetChildren()) do if c.Name:match("^Stage%d+$") then n += 1 end end`. This runs via freeStage inside JobAvailable for every job and tender in S.Board, and again in startJob.
- **Fix (gegengeprüft):** Cache the count only when it is positive, so a venue folder that is missing or not loaded yet gets scanned again next time: `local stageCounts = {}` and in stageCount: `local c = stageCounts[venueId]; if c then return c end; ...scan...; if n > 0 then stageCounts[venueId] = n end; return n`. This assumes Stage parts are static at runtime, and the code shows no runtime creation of Stage parts.

### C24 · LOW · perf-server — Plaza mode scans the entire workspace (~383k instances) synchronously
`ServerScriptService.Server.PlazaService` ~Zeile 87 · Aufwand S
- **Problem:** `for _, sl in ipairs(workspace:GetDescendants()) do if sl:IsA("SpawnLocation") then sl.Enabled = false end end`. PolishLog notes `game:GetDescendants() = 383.424`.
- **Fix (gegengeprüft):** Keep the behaviour the same. Either iterate the known spawn container (for example workspace.World or the hub folder) instead of all of workspace, or tag the hub SpawnLocations in Studio and use CollectionService:GetTagged. If the tag approach is used, keep the full-workspace scan as a fallback for when no tagged spawns are found, so that an untagged spawn is never left enabled.

### C25 · LOW · perf-server — Pre-teleport Save(p,false) in Goto/Return duplicates the release-save that onLeave does seconds later
`ServerScriptService.Server.PlazaService` ~Zeile 153 · Aufwand S
- **Problem:** task.spawn(function()
	pcall(ctx.Data.Save, p, false)
	...TeleportAsync...
Main.onLeave L485: `ctx.Data.Save(p, true)` runs as soon as the teleport completes.
- **Fix (gegengeprüft):** Do not simply delete the pre-save. It protects against teleport failures and crashes. The safer fix is to stamp the time of the pre-save (for example `p:SetAttribute("PreTpSave", os.clock())`). In onLeave, if that save was less than about 6 s ago and the player was teleporting, still run the release save (it is needed to drop the lock), but wait until those 6 s have passed so the write is not throttled. An alternative is to make the pre-save the release save: set release=true only after TeleportAsync succeeds. Do not release before calling TeleportAsync, because if the teleport fails the player stays on this server without a lock.

### C26 · LOW · perf-server — Plaza teleport saves with the lock kept, so the destination's first Load is always LOCKED and waits 4 s
`ServerScriptService.Server.PlazaService` ~Zeile 153 · Aufwand S
- **Problem:** Goto L154 / Return L176: `pcall(ctx.Data.Save, p, false)` refreshes `Lock.Time`, then `TeleportAsync`. The origin releases only in PlayerRemoving after the player has left. The destination's DataService.Load (L96-98) hits LOCKED and waits `task.wait(4)` before trying again.
- **Fix (gegengeprüft):** In D.Load, use a short wait for the first attempts (`task.wait(attempt <= 4 and 1 or 4)`) and raise LOAD_ATTEMPTS to keep the same total wait time. The release still happens only in onLeave, so no data race is introduced.

### C27 · LOW · perf-server — Prompt fallbacks: missing markers are re-searched recursively on every call; UpdateSign scans all descendants
`ServerScriptService.Server.PlotService` ~Zeile 103 · Aufwand S
- **Problem:** P.Marker: `local found = pl.Model:FindFirstChild(name, true) if found then ... end pl.MarkerCache[name] = nil return pl.Hidden[name]`. A miss is never cached, so every call does a recursive search over the whole warehouse (template + WHModules + RackItems, thousands of instances). JobService.TruckAtDepot (L276) calls Marker(p, "TruckSpot") every second from the CrewWork.Init loop (L30) while CrewAt == "Truck". UpdateSign (L165) does `for _, x in …
- **Fix (gegengeprüft):** In Marker, cache a miss with a sentinel: `if c == false then return pl.Hidden[name] end`. On a miss, set `pl.MarkerCache[name] = false` instead of nil. In ApplyExpansions, after WB.Build and next to `pl.RackSlots = nil`, add `pl.MarkerCache = nil`. WB.Build can create new markers and folders get hidden or shown there, so a cached miss or hit must be invalidated at that point. UpdateSign is optional: either cache the CompanySign roots per model and clear that cache in ApplyExpansions, or leave it as it is, since it is rarely called.

### C28 · LOW · perf-server — rackLayout re-sorts the inventory with table.find inside the comparator on every RackPath/RackSlot call
`ServerScriptService.Server.PlotService` ~Zeile 201 · Aufwand S
- **Problem:** rackOrder: `table.sort(ids, function(a, b) local ia, ib = table.find(R.Order, a) or 999, table.find(R.Order, b) or 999 ...` (L201-205), a linear scan of R.Order (all items) per compare. rackLayout calls rackOrder and builds the signature string BEFORE checking the cache (L222-228), so the 'cache hit' still pays the full sort. It is called through P.RackPath -> P.RackSlot for every crew batch and robot trip (JobService L1287, L1463), in StartPrep …
- **Fix (gegengeprüft):** ItemRegistry, after the R.Order sort: `R.OrderIndex = {} for i, id in ipairs(R.Order) do R.OrderIndex[id] = i end`. PlotService rackOrder comparator: `local ia, ib = R.OrderIndex[a] or 999, R.OrderIndex[b] or 999`. In rackLayout, use a separate local (`local sigParts = {...}; local sig = table.concat(sigParts, ",")`) to clear the luau-lsp retype error. Leave out the InvVersion cache, or add it only if every Inventory write bumps the version. The Sig compare already keeps the layout correct.

### C29 · LOW · perf-server — RefreshRackPrompts scans every case part and calls RackNeed per tag on every pick
`ServerScriptService.Server.PlotService` ~Zeile 463 · Aufwand S
- **Problem:** `for _, tag in ipairs(f:GetChildren()) do local id = tag.Name == "RackTag" and tag:GetAttribute("ItemId") ... local need = ... ctx.Jobs.RackNeed(p, id)`. RackItems also holds every Case part and item model (up to ~2000 children). JobService.RackNeed (L1197-1205) loops over all `job.Staging` for each tag. Callers include crewLoop/robotLoop after every pick (JobService L1302, L1333, L1477, L1510) and others (L800, L1082, L1219, L1226, L1543, …
- **Fix (gegengeprüft):** Add `S.RackNeedMap(p)` to JobService. It returns {} unless the phase is Packing. Otherwise it makes one pass over job.Staging and counts `m[e.Id] = (m[e.Id] or 0) + 1` for every entry where InRack is set and Claimed is not. In RefreshRackPrompts, build that map once before the loop and set `need = map[id] or 0`. You can also keep the tag parts in a list built during renderRacksNow (clear the list on re-render) and loop over that list instead of f:GetChildren().

### C30 · LOW · network — Show start, teardown and cleanup are broadcast to every client in all three cities
`ServerScriptService.Server.ShowService` ~Zeile 43 · Aufwand S
- **Problem:** L43 `ctx.Remote("Show"):FireAllClients({... StageCF = { job.StageCF:GetComponents() }, Folder = job.Folder, ...})` and L108 `ctx.Remote("Build"):FireAllClients({... Teardown = true, Folder = job.Folder, ...})`. JobService.Cleanup does the same. PlacementService.Put already uses `ctx.FireRegion("Build", ctx.RegionAt(wpos), p, ...)` (L202) for the same Build remote.
- **Fix (gegengeprüft):** At L43, replace the call with `ctx.FireRegion("Show", ctx.RegionAt(job.StageCF.Position), p, payload)`. At L108, replace it with `ctx.FireRegion("Build", ctx.RegionAt(job.StageCF.Position), p, {Owner=..., Teardown=true, ...})`. Use the same pattern for the Build/Cleanup broadcast in JobService.Cleanup. Keep StageCF as the components table unless you also update the client decoding (ShowDirector) at the same time.

### C31 · LOW · perf-server — Trade loop does recursive FindFirstChild over every child of World.Trading (including the whole Plaza model) every 0.3 s, on every server
`ServerScriptService.Server.TradeService` ~Zeile 156 · Aufwand S
- **Problem:** local tf = workspace.World:FindFirstChild("Trading")
for _, tbl in ipairs(tf:GetChildren()) do
	if not sessions[tbl] then
		local padA, padB = tbl:FindFirstChild("PadA", true), tbl:FindFirstChild("PadB", true)
PlazaService.SetMode puts the full Plaza model into the same folder (`m.Parent = tf`, L82), and the model has no pads. L139 also runs recursive lookups for each active table trade every tick.
- **Fix (gegengeprüft):** Simplest fix that keeps behaviour the same: keep a weak-keyed cache `padCache[tbl] = {A=padA, B=padB}` (or `false` when the child has no pads), filled the first time each child is seen and cleared on tf.ChildRemoved. Store the pads on the trade object in open() and use them at L139. Better still: in PlazaService, give the decorative model its own folder instead of putting it in World.Trading.

### C32 · LOW · perf-server — renderCargoNow destroys and recreates every cargo box and weld on each change
`ServerScriptService.Server.VehicleService` ~Zeile 318 · Aufwand M
- **Problem:** L318-319 `local old = t:FindFirstChild("CargoVisual") if old then old:Destroy() end`, then for every cargo id a Case Part, an Edge Part and two WeldConstraints (L332-369), plus up to 48 MatPallets with welds (L376-401). The deferred dirty flag only merges changes within one frame. Venue unloading and crew build trips call TakeCargo/AddCargo once per item over many frames, so each item triggers a full rebuild. On larger trucks cols*rows*layers is …
- **Fix (gegengeprüft):** Keep the CargoVisual folder and cache its parts in s.CargoParts = { {box=, edge=, id=} ... } and s.CargoMatN. In renderCargoNow:
1. If the truck or bay changed, or the folder is missing, do the full rebuild.
2. Otherwise, for i = 1, min(#Cargo, maxBoxes): create the part pair if it is missing (same code as now, with the weld to root); if pair.id ~= Cargo[i], set edge.Color = CAT[...] and pair.id = Cargo[i].
3. Destroy the pairs with index > n and remove them from the cache.
4. Rebuild MatPallets only when the computed n, or the start index min(#Cargo, maxBoxes), changed.
5. Also early-return when the signature (table.concat(Cargo, ","), MatKg) equals the last rendered one.
Clear the cache whenever the truck is respawned or despawned (L199 path).

### C33 · LOW · perf-server — Cargo Case/Edge parts keep CanTouch=true, so HighwayTrigger.Touched fires once per cargo part (client-reported)
`ServerScriptService.Server.VehicleService` ~Zeile 352 · Aufwand S
- **Problem:** In renderCargoNow the Case and Edge parts set `CanCollide = false`, `CanQuery = false` and `Massless`, but not CanTouch (L341-362). Only MatPallet sets `box.CanTouch = false` (L392). The highway trigger handler `trig.Touched:Connect(function(hit) local truck = hit:FindFirstAncestorWhichIsA("Model") while truck and not truck:GetAttribute("OwnerId") ...` (L20-33) allocates `s.HighwayAt = {...}` before its debounce check.
- **Fix (gegengeprüft):** In renderCargoNow, after `box.CanQuery = false` add `box.CanTouch = false; box.CastShadow = false`, and after `edge.CanQuery = false` add `edge.CanTouch = false; edge.CastShadow = false`.

### C34 · LOW · perf-server — Any module upgrade rebuilds the entire warehouse (up to ~2250 instances) and invalidates all rack slots
`ServerScriptService.Server.WarehouseBuilder` ~Zeile 701 · Aufwand M
- **Problem:** WB.Build: `local old = model:FindFirstChild("WHModules") if old then old:Destroy() end` and then it rebuilds floor, racks, annex, mezzanines, docks, forklifts, outdoor, kitchen and robot docks unconditionally. PlotService.ApplyExpansions (L144-148) then sets `pl.RackSlots = nil pl.RackLayout = nil P.RenderRacks(p)`. ShopService.BuyModule calls ApplyExpansions for every module, including Office/Branch/Lounge, which have little or no WHModules …
- **Fix (gegengeprüft):** Build each module into its own subfolder (WH_Floor, WH_Racks, WH_Docks, ...) with an attribute holding the level (and `raise` for Floor). On Build, rebuild only the subfolders whose level or signature changed. Run resetTemplate/adaptTemplate only when Racks changed. Clear the RackSlots/RackLayout caches only when WH_Racks was rebuilt.

### C35 · LOW · perf-client — Ambient probes attributes on every descendant added anywhere in workspace (plus a full GetDescendants at join)
`StarterPlayer.StarterPlayerScripts.Client.Ambient` ~Zeile 222 · Aufwand M
- **Problem:** `for _, d in ipairs(workspace:GetDescendants()) do register(d) end workspace.DescendantAdded:Connect(register) workspace.DescendantRemoving:Connect(forget)`. register() calls `d:GetAttribute("Windmill")`, then for every BasePart `GetAttribute("NightWindow")`, `"NightLight"`, `"TownClock"` and `"NightPool"`. This runs for every streamed chunk (the PolishLog measures about 33k streamed client instances) and also for every client-spawned part: …
- **Fix (gegengeprüft):** DevTools pass: for every instance in workspace AND ServerStorage (templates such as Templates.Warehouse, plus Backups) that has the Windmill, NightWindow, NightLight, TownClock or NightPool attribute, call CollectionService:AddTag(inst, name). Keep the attributes. Runtime: `local CS = game:GetService("CollectionService"); for _, tag in {"Windmill","NightWindow","NightLight","TownClock","NightPool"} do for _, d in CS:GetTagged(tag) do register(d) end; CS:GetInstanceAddedSignal(tag):Connect(register); CS:GetInstanceRemovedSignal(tag):Connect(forget) end`. register keeps its existing attribute branches, so it still works for a tagged instance. Replace the GetDescendants scan and the DescendantAdded/DescendantRemoving connections. Before shipping, check in Play that the lamp and window counts match the old path, because an untagged template would lose its night behaviour silently.

### C36 · LOW · perf-client — CrewDirector: recursive FindFirstChild('Staging', true) on the whole company model every 0.3 s per player
`StarterPlayer.StarterPlayerScripts.Client.CrewDirector` ~Zeile 323 · Aufwand S
- **Problem:** refreshAnchors runs per crew every 0.3 s (`crew.NextA = t + 0.3`, L716) and does `local comp = comps and comps:FindFirstChild("Company_" .. uid) local st = comp and comp:FindFirstChild("Staging", true)`. Company models contain the whole warehouse (racks, modules, cargo). The server already learned this lesson and caches it: PlotService.Marker L97 `-- [Polish C] rekursive Suche cachen (wird in Tick-Schleifen aufgerufen)`.
- **Fix (gegengeprüft):** In refreshAnchors, replace L323 with a cached lookup, and do the full search no more than once per second when Staging isn't found:
```lua
local st = crew.StagingPart
if not (st and comp and st:IsDescendantOf(comp)) then
	st = nil
	if comp and os.clock() >= (crew.StagingRetry or 0) then
		st = comp:FindFirstChild("Staging", true)
		crew.StagingRetry = st and 0 or os.clock() + 1
	end
	crew.StagingPart = st
end
```
Keep the existing A.Staging line, which still checks st:IsA("BasePart"). removeCrew already sets crews[uid] = nil, so the cached reference is released when the player leaves.

### C37 · LOW · perf-client — Per-frame redundant property writes (crowd phone lights)
`StarterPlayer.StarterPlayerScripts.Client.Crowd` ~Zeile 182 · Aufwand S
- **Problem:** `if p.Light then p.Light.Transparency = phone and 0 or 1 ...` runs for every phone holder (about 30% of up to 230 people) on every updated frame, even though `phone` only changes once, at the outro.
- **Fix (gegengeprüft):** if p.LightOn ~= phone then p.LightOn = phone; p.Light.Transparency = phone and 0 or 1 end  -- phone is a boolean here (it starts as false/nil and is set to p.Phone); coerce with `phone = phone == true` so that nil and false do not each trigger a write

### C38 · LOW · perf-client — Teardown animation runs on every client in the server regardless of distance (FireAllClients + no distance gate)
`StarterPlayer.StarterPlayerScripts.Client.Effects` ~Zeile 554 · Aufwand S
- **Problem:** The server sends `ctx.Remote("Build"):FireAllClients({ Owner = p.UserId, Key = job.Key, Teardown = true, Folder = job.Folder, ... })` (ShowService L108). job.Folder is a Folder (JobService L1740), so it replicates to every client even under StreamingEnabled. Its non-atomic child Models exist without parts. The client handler has no distance check before scheduling work: `for i, e in ipairs(list) do ... task.delay(..., function() ... for _, d in …
- **Fix (gegengeprüft):** Inside the task.delay callback, compute `start`/`cam` before collecting parts, then add `if not cam or (cam.CFrame.Position - start.Position).Magnitude > 700 then return end`, so each model checks its own distance. Alternatively, keep a single early return after `list` is built that uses msg.Folder's first child pivot with the same 700-stud threshold. Optionally, on the server, replace FireAllClients with ctx.FireRegion so far-away clients don't get the event. Visual behavior for nearby players stays the same.

### C39 · LOW · perf-client — GPS RenderStepped rebuilds label strings and sets Text every frame
`StarterPlayer.StarterPlayerScripts.Client.Effects` ~Zeile 633 · Aufwand S
- **Problem:** Every frame: `pillarText.Text = via and ("📍 " .. (gps.Name or "Ziel") .. "  •  🛣️ " .. via) or ("📍 " .. ... .. math.floor(shown / 3.57) .. " m")` and `arrowLabel.Text = math.floor(shown / 3.57) .. " m"`. The displayed metre value changes at most a few times per second.
- **Fix (gegengeprüft):** Declare `local lastM, lastVia, lastName` outside the connection. Inside it: `local m = math.floor(shown / 3.57); local nm = gps.Name or "Ziel"; if m ~= lastM or via ~= lastVia or nm ~= lastName then lastM, lastVia, lastName = m, via, nm; <set pillarText/arrowLabel Text as before using m and nm> end`. Also reset lastM to nil whenever the labels are recreated or the target changes.

### C40 · LOW · perf-client — Ghosts.Recolor walks every ghost's full descendant tree on every State push
`StarterPlayer.StarterPlayerScripts.Client.Ghosts` ~Zeile 158 · Aufwand S
- **Problem:** `for _, g in pairs(ghosts) do ... local noMat = not locked and U.MatMissing(job, g.Slot.P) > 0 ... for _, d in ipairs(g.Model:GetDescendants()) do if d:IsA("BasePart") and d.Name ~= "GhostAnchor" and d.Transparency < 1 then d.Color = col d.Transparency = tr end end end` (L150-164). This runs from State.Changed on every snapshot (L186), including snapshots unrelated to ghosts (cash, Mat.List countdowns, carry kg). U.MatMissing is also recomputed …
- **Fix (gegengeprüft):** 1. In build(), after styleGhost, cache the parts once: `g.Parts = {}`. Fill it with every BasePart descendant whose Name is not "GhostAnchor" and whose Transparency is below 1. The new transparency values (0.15 to 0.8) are always below 1, so the cached set never changes.
2. In Recolor, keep the Prompt.Enabled and ActionText updates exactly as they are now.
3. Compute missing material at most once per phase per call, e.g. `local miss = {}` and `miss[p] = miss[p] or U.MatMissing(job, p)`.
4. Use `if g.LastCol ~= col or g.LastTr ~= tr then for _, d in ipairs(g.Parts) do d.Color = col; d.Transparency = tr end; g.LastCol, g.LastTr = col, tr end`. Color3 values compare by value, so `~=` works here.

### C41 · LOW · perf-client — Navigation visuals: ~41 individual part CFrame writes per frame, ClockTime re-read per chevron, HUD strings rebuilt every frame
`StarterPlayer.StarterPlayerScripts.Client.Navigator` ~Zeile 199 · Aufwand S
- **Problem:** drawChevrons runs every Heartbeat: `for k, c in ipairs(chevrons) do ... c.A.CFrame = ... c.B.CFrame = ... c.C.CFrame = ... local tr = 0.05 + 0.75 * (k / CHEV_N) + nightExtra() ... c.A.Parent, c.B.Parent, c.C.Parent = c.M, c.M, c.M` (L201-217). nightExtra() reads Lighting.ClockTime on each call and is also called per strip (L182). The Effects RenderStepped then writes 5 arrow parts (Effects L656-660) and rebuilds `pillarText.Text` / …
- **Fix (gegengeprüft):** Compute `local ne = nightExtra()` once per drawChevrons/drawStrips call. Track a c.Shown flag so Parent is only assigned when visibility changes. Batch the chevron CFrames with workspace:BulkMoveTo. In Effects, cache the last floored distance and the last via string, and only reassign the label texts when either changes. Keep the arrow on RenderStepped (do not move it to Heartbeat).

### C42 · LOW · perf-client — RigAnim.SetAlpha walks GetDescendants on every call, and callers use it per frame during fades
`StarterPlayer.StarterPlayerScripts.Client.RigAnim` ~Zeile 37 · Aufwand S
- **Problem:** `for _, d in ipairs(rig.Model:GetDescendants()) do if d:IsA("Decal") then ... elseif d:IsA("SurfaceGui") then ...`. Pedestrians calls it every frame while `o.Fade < 1` (Pedestrians L346-349, about 37 frames per spawn). CrewDirector calls it on every 0.05 alpha step (L681-684).
- **Fix (gegengeprüft):** In RA.New, add `Decals = {}, Guis = {}` to the rig table. In the existing descendant loop, add: `elseif d:IsA("Decal") then table.insert(rig.Decals, d) elseif d:IsA("SurfaceGui") then table.insert(rig.Guis, d)`. Keep these checks separate from the BasePart check. In SetAlpha, replace the GetDescendants loop with: `for _, d in ipairs(rig.Decals) do d.Transparency = 1 - a end; for _, g in ipairs(rig.Guis) do g.Enabled = a > 0.5 end`. Behaviour stays the same, assuming no decals are added to the rig after it is cloned.

### C43 · LOW · perf-client — Robots: idle shuttles are PivotTo'd, searched with FindFirstChild and recoloured every frame
`StarterPlayer.StarterPlayerScripts.Client.Robots` ~Zeile 161 · Aufwand S
- **Problem:** For every robot of every player within VIS_DIST, every Heartbeat: `local yaw = CFrame.lookAt(Vector3.zero, rb.Dir) local cf = CFrame.new(rb.Pos) * yaw rb.Model:PivotTo(cf) local beacon = rb.Model:FindFirstChild("Beacon") if beacon then beacon.Color = ... end`. This also runs when `rb.Task == nil` and the robot sits on its dock without moving. PivotTo moves all 9 parts of the model each time.
- **Fix (gegengeprüft):** In robotAt, cache the beacon: rb.Beacon = m:FindFirstChild("Beacon").

In update(), for robots that are not far:
- Keep `local moved = rb.Task ~= nil or rb.PlacedPos ~= rb.Pos or rb.PlacedDir ~= rb.Dir or rb.Model.Parent ~= folder` and compute it before re-parenting.
- If moved, run PivotTo(cf) and set rb.PlacedPos = rb.Pos and rb.PlacedDir = rb.Dir.
- Compute `local on = rb.Task ~= nil and math.sin(t*9+rb.Phase) > 0`. Write rb.Beacon.Color only when `on ~= rb.BeaconOn`, then set rb.BeaconOn = on.

The prop placement already runs only while there is a task, so it can keep using cf. No BulkMoveTo is needed.

### C44 · LOW · perf-client — Admin panel rebuilds a button for every item on every action, plus an Overview poll every 2 s
`StarterPlayer.StarterPlayerScripts.Client.ScreensAdmin` ~Zeile 330 · Aufwand M
- **Problem:** The Economy tab does `for id, x in pairs(R.Items) do if not x.Modular then table.insert(ids, id) end end ... for _, id in ipairs(ids) do local b = UI.Button(pick, id, "ghost", ...)` on every build. `act()` always ends with `task.wait(0.2) refresh()`, which fetches the Overview and does a full UI.Refresh. The live loop L671-684 calls `fetch()` (InvokeServer Overview) every 2 s while the panel is open. `parseNum` strips '.', so "1.5" becomes 15 …
- **Fix (gegengeprüft):** Build the item picker once and reuse it. Alternatively, have act() update the cached data and the live labels instead of rebuilding the whole panel. Leave the 2 s poll as it is, or pause it while the window is not focused. Do not change how parseNum treats '.' and ','. Treating '.' as a thousands separator is intended ("250.000"), and decimals are already accepted together with k/m/b suffixes.

### C45 · LOW · perf-client — ShowDirector writes every light, beam and LED property every frame, including constants, and allocates ColorSequences per beam per frame
`StarterPlayer.StarterPlayerScripts.Client.ShowDirector` ~Zeile 282 · Aufwand S
- **Problem:** Inside RenderStepped: `bm.Color = ColorSequence.new(c)` for every beam (L285). `s.Brightness = 12 s.Color = Color3.new(1, 1, 1)` for every strobe (L310-311) and `s.Brightness = 14 s.Color = C3(255, 214, 160)` for every blinder (L317-318), which are constant every frame. Spots and LED backgrounds are rewritten each frame although `col` and `col2` only change every 2-4 beats. Lasers allocate `ColorSequence.new(...)` per beam per frame (L340). …
- **Fix (gegengeprüft):** Make these changes before connecting:

1. Precompute the colour sequences:
`local SEQ = {} for i, c in ipairs(PALETTE) do SEQ[i] = ColorSequence.new(c) end`
`local LASER_SEQ = { ColorSequence.new(C3(0,200,255)), ColorSequence.new(C3(40,255,90)) }`

2. Set the constant strobe and blinder properties once:
`for _, s in ipairs(f.Strobes) do s.Brightness = 12 s.Color = Color3.new(1,1,1) end`
`for _, s in ipairs(f.Blinders) do s.Brightness = 14 s.Color = C3(255,214,160) end`

3. Set each laser beam's colour once when `laserBeams` is built:
`e.Beam.Color = LASER_SEQ[(li % 2 == 0) and 2 or 1]`

4. Declare `local lastCi, lastStrobe, lastBlind = -1, nil, nil`.

In the RenderStepped loop:

5. Delete `local pulse`.

6. Compute `local colorChanged = ci ~= lastCi` and set `lastCi = ci`. When `colorChanged or newBeat`:
   - For beams, set `bm.Color = SEQ[(i % 2 == 0) and ci or ((ci % #PALETTE) + 1)]` …

### C46 · LOW · perf-client — Client State.Changed is a BindableEvent fired with (s, prev): Roblox deep-copies both full snapshots on every push, and prev is unused
`StarterPlayer.StarterPlayerScripts.Client.State` ~Zeile 15 · Aufwand S
- **Problem:** L6 `local changed = Instance.new("BindableEvent")`, L15 `changed:Fire(s, prev)`. BindableEvent arguments are serialised and copied, so a full snapshot plus the previous one are copied on every State push. The 7 listeners (HUD L452, Ghosts L170, ScreensRoadcase L453, Effects L539, ScreensCrew L333, ScreensJobs L389, ClientMain L65) never read the second argument. Listeners also get a copy that is not identical to State.Data. State.Wait (L38-40) …
- **Fix (gegengeprüft):** Use a plain Lua signal. Inside fire, call each listener with task.spawn(fn, s) so they don't block each other and keep their current behaviour. Loop over a copy of the listener list (table.clone) so that a listener which connects or disconnects during the fire can't change the list mid-loop. Optionally drop prev, since no listener reads it. Callers use :Connect directly on State.Changed, so it only has to support :Connect and Disconnect, which the proposed fix already does.

### C47 · LOW · perf-client — Traffic obstacles(): GetBoundingBox on every vehicle model on the server every 0.25 s, with no distance filter
`StarterPlayer.StarterPlayerScripts.Client.Traffic` ~Zeile 695 · Aufwand S
- **Problem:** `for _, m in ipairs(vf:GetChildren()) do if m:IsA("Model") then local ok, cf, sz = pcall(m.GetBoundingBox, m) ...` (L695-707). This runs for all trucks in World.Vehicles, including those in other cities. GetBoundingBox iterates every part of the truck and its cargo. CrewDirector already caches truck extents in a weak table (`extents[t] = t:GetExtentsSize()`).
- **Fix (gegengeprüft):** In update(), move the obstacle refresh after the `active == 0` early return, or skip it when active == 0. In obstacles(), first read `local piv = m:GetPivot()` and skip the model if `(piv.Position - camPos).Magnitude > DESPAWN`. Measure the size once per model in a weak-keyed cache (`sizeCache[m] = sizeCache[m] or select(2, m:GetBoundingBox())`), then use piv.Position and piv.LookVector with the cached size. Check that the model's pivot is roughly at its center, otherwise the front and rear points move. The cache keeps the bounding box from when a truck first appears, so a truck whose length changes later (for example when cargo is added) would keep the old value.

### C48 · LOW · perf-client — UI.Bar creates a new Tween on every call, and the HUD's 1 s loop re-runs the full update
`StarterPlayer.StarterPlayerScripts.Client.UI` ~Zeile 210 · Aufwand S
- **Problem:** `local function set(a) UI.Tween(fill, 0.35, { Size = UDim2.fromScale(math.clamp(a, 0, 1), 1) }) end` has no unchanged check. HUD L461-470: `while true do task.wait(1) ... if job and (job.DeadlineIn or ...) then pcall(update, s) end end`. update() calls setXP, setProg and setCarry, rebuilds all strings, runs fillCarry and recolours the step chips every second, just to tick two countdown labels.
- **Fix (gegengeprüft):** In set(), skip when `math.abs(a - last) < 1e-3`. Split out a `tickCountdowns()` that only rewrites trMat (and the truck line) and call that from the 1 s loop instead of update().

### C49 · LOW · perf-client — Spinning viewports keep a RenderStepped connection running after their window is closed
`StarterPlayer.StarterPlayerScripts.Client.UI` ~Zeile 269 · Aufwand S
- **Problem:** `conn = RunService.RenderStepped:Connect(function(dt) if not vp.Parent then conn:Disconnect() return end if vp.Visible then a += dt * 0.6 place(a) end end)`. UI.Close only sets `w.Frame.Visible = false` (L392) and never destroys Content. `vp.Visible` is the viewport's own property, not its effective visibility, so it stays true after the window closes. Spin=true is used in Roadcases (4 viewports), Cases (4), Shop detail (1) and Crew detail (1).
- **Fix (gegengeprüft):** Inside the RenderStepped callback, spin only when the viewport belongs to the open window. Keep the disconnect-on-destroy check:
```lua
conn = RunService.RenderStepped:Connect(function(dt)
	if not vp.Parent then conn:Disconnect() return end
	local cur = UI.Current
	if vp.Visible and cur and cur.Frame.Visible and vp:IsDescendantOf(cur.Frame) then
		a += dt * 0.6
		place(a)
	end
end)
```
UI.Current is set before the Builder runs (L342 vs L346), so newly built spinners start spinning right away. A shared RenderStepped with a weak-keyed spinner table is optional; the per-viewport guard is enough. Behaviour and saves are unchanged.

### C50 · LOW · perf-client — Banners have no cap and Toast rebuilds its icon table on every call
`StarterPlayer.StarterPlayerScripts.Client.UI` ~Zeile 431 · Aufwand S
- **Problem:** UI.Banner appends a new panel to `UI.BannerLayer` (a fixed 200 px tall frame with a UIListLayout) on every call with no limit, unlike Toast's `if kids > 6`. Toast declares `local ICON = { Info = ..., ... }` inside the function (L408).
- **Fix (gegengeprüft):** Move ICON next to KIND at module scope. In UI.Banner, after creating f, count the Frame children of UI.BannerLayer. While there are more than 3, destroy the first Frame child, which is the oldest. The pending task.delay will then call f:Destroy() on a frame that is already destroyed, and in Roblox that is a harmless no-op.
