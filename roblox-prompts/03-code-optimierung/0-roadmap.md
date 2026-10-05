# Roadmap, Test-Gerüst & Leitplanken

Teil des Code-Audits von `Place1backup1_klein.rbxl` (Stand 04.10.2026). Englisch, weil es für das Modell gedacht ist.

## 1. Roadmap (architecture, test harness, strict, config, network)

ROADMAP for the next Studio/MCP developer: Event Company Simulator (ECS) runtime code

== 0. Fix first (verified bugs; small, behaviour-preserving) ==
a) DataService saves can overlap. D.Save (L134-163) has no per-player lock. The autosave runs `task.spawn(D.Save, p, false)` (L183), Plaza.Goto/Return save with release=false, and onLeave calls Save(p,true) (Main L485). A slower autosave or teleport save can commit after the release save. It then writes an older copy and puts back `Lock={Job,Time}`. The player's next join waits about 50 s and gets a Temp profile, and progress is rolled back.
   Fix: chain saves per player (one in flight at a time). Add `d.SaveSeq` (+1 for each save; Reconcile default 0). In the UpdateAsync transform, `return nil` if `old.SaveSeq > copy.SaveSeq`. Set `released[userId]=true` after the release save so that later non-release saves do nothing.
b) ShowService.Finish (L110-118) runs after `task.wait(dur)` with no check that the player is still there. If the player left during teardown, `ctx.Jobs.StartJob` indexes `s.Job` on a nil session and errors, and tour rewards land on a profile that was already saved. Fix: `if not p.Parent or ctx.Sessions[p] ~= s then return end` right after the wait.
c) InteractService L85: `local ok, why = (kind == "Plaza") and ctx.Plaza.Goto(p) or ctx.Plaza.Return(p)`. When Goto returns false (for example "Beende ... deinen Auftrag"), Return(p) runs instead, and `why` is always nil, so the portal fails silently. Fix: use an explicit if/else.
d) Client.Effects L644: `e[1].Parent = hidden and nil or arrow` always gives `arrow`, so the GPS arrow never hides near the goal. Fix: use if/else.
e) Main L233: `H.Unload` calls JobService.CargoInteract (L1088) with no distance check. A remote call can load carried items into the truck, or unload up to 12 items at the venue, from anywhere. Fix: require HRP within 15 studs of truck `CargoDoor` (the prompt itself uses MaxActivationDistance 12).
f) VehicleService L19 `deb[p]` (highway debounce) is never cleared, so it holds Player references. Clear it on PlayerRemoving.
g) startJob (JobService L541) spends the rent before `venueFolder`/`Unload..stage` are resolved (L568-570). A nil `vf` then errors after the money is taken. Do the stage/zone lookup before `Economy.Spend`.
h) Not a bug: the lsp DuplicateCondition in TenderGen L227 is a false positive (it re-rolls `chance()`). Leave it.

== 1. Regression / smoke-test harness ==
Location: ServerStorage.DevTools.Tests (Folder)
- TestRunner (ModuleScript)
  - Asserts: eq, near(eps), truthy, finite, throws.
  - `Fresh(mod)` clones the ModuleScript into the same parent under a random name, requires it, then destroys the clone. Edit-mode `require` caches modules; cloning beside the original keeps `script.Parent.X` requires working.
  - `Run(list)` returns `{pass,fail,failures={...}}` and prints one line with the prefix "[TEST]".
  - While tests run, it hooks LogService.MessageOut. Any new MessageWarning/MessageError that starts with "[Jobs]", "[Request]", "[Main]", "[Data]" or "[Show]" counts as a failure.
- Unit_* modules: run them in edit mode with MCP run_code: `return require(game.ServerStorage.DevTools.Tests.TestRunner).RunUnit()`
  - Unit_Validate:
    - isFinite(0/0), isFinite(math.huge) and isFinite("5") are false
    - clampInt(0/0,0,10,5)==5
    - key(x, R.Items) rejects a table
    - sanitizeProfile fixes: Cash=NaN becomes G.StartCash, Inventory.X=inf is removed, Level=0 becomes 1, Cash<0 becomes 0, and the returned list names each fix
  - Unit_JobLogic:
    - J.Load({})==0,0
    - the LED item uses J.LEDArea(level)*R.LEDWall.KgPerM2
    - J.Slots is sorted by phase
    - FX cap: adding 20 FX items raises ratio by at most 0.15
    - J.Payout(job,5)==floor(job.Cash*J.StarMult[5])
    - J.Assign never assigns more of an id than inventory minus reserved
    - J.TypeModelFor("StageSystem",job) has SystemRank >= job.System
    - GOLDEN: for every W.Jobs entry, record {Payout(1..5), Evaluate(StartInventory).Stars, Load} as JSON in a StringValue Tests.Golden. Compare after every refactor. This is the safety net for the magic-number move.
  - Unit_Luck: RollOnce/Roll are deterministic with `Random.new(1)`; Effective() sums to about 1; RollCount>=1.
  - Unit_Economy: build a fake ctx {Data={Profiles={[fp]=profile}}, Sessions={[fp]={OwnedPasses={}}}, FX/Notify=no-op}.
    - AddCash(NaN|inf|-1) leaves Cash unchanged
    - Spend(math.huge) is false
    - AddXP over several levels gives the right Level/XP
    - CashMult with DoubleCash+VIP is 2.25 + crew bonus (additive)
    - Reward floors its results
  - Unit_TenderGen: add `T.SetSeed(n)` (a one-line change to the module rng). For levels 1..60 with fixture profiles (Neustadt only / all unlocked), 200 rolls each. Check: tier<=TierFor(L); def.Venue is in d.Venues and its region is unlocked; Cash finite and >0; Freight>=0; condition Ids are in {Express,Premium,Sponsor,Press}.
  - Unit_JobMath: S.MatNeed/MatMissing on plain job tables; FmtT(950/1500/12000).
  - Unit_DataSave: add the seam `D._SetStore(fake)`. Use a fake UpdateAsync that yields 0.3-1 s and records writes, and a fake player {UserId=1,Name="t",Parent=workspace}. Fire Save(false) and Save(true) at the same time; the final record must have Lock==nil and the newest data. This is the regression test for 0a.
- Play_* scenarios: run in play mode on the server side with run_script_in_play_mode.
  - Wait for `Players:GetPlayers()[1]:GetAttribute("Loaded")`.
  - Drive everything through `ServerStorage.ECS_DevHook:Invoke(cmd, uid, ...)` (Main L359-407: Get/Set/Session/Do/Give/Call).
  - Add a hook command "Route" that calls the real OnServerInvoke handler. Do bypasses rate-limit, PLAZA_BLOCK and pcall, so Route is needed to test those paths.
  - S1 join/load:
    - profile contains every D.Template key; Temp==true in Studio without API access
    - Session has Plot and Truck
    - leaderstats exist
  - S2 shop:
    - Give(1e6) then Do("BuyItem",{Id="Nova_FlatPar12",Qty=1}): Inventory+1 and Cash drops by the price
    - Qty=0/0, math.huge, -1, "7" and {}: Cash stays finite and Inventory changes by at most 1
  - S3 job happy path:
    - Do("AcceptJob", W.Jobs[1].Id) gives Session Job.Phase "Packing"
    - Call("Jobs","ForcePack") gives "Driving"
    - Call("Jobs","Arrive") gives "Building"
    - Call("Jobs","ForceMaterial"), then Call("Build","ForceBuild") gives "Ready"
    - Call("Show","Start",{true}) gives "Show"
    - poll Session "Job" until nil (timeout 60 s); then Stats.Events +1, Cash went up, no `Staged_<uid>` left under World.Staging, no `Build_<uid>` folder, no `Freight_<uid>`
  - S3b cancel: accept, wait 3 s (the crew loop is mid-fetch), Do("CancelJob"). Check that no models are orphaned and that RackItems tags have no ProximityPrompt. Repeat with Spedition {Equip=true}.
  - S4 trade: needs 2 clients, so do it manually (Test > Clients & Servers, 2 players). Automate the logic instead by extracting the `execute` move logic into a pure `T._Swap(dA,dB,offerA,offerB)` and unit-testing it: uid conservation, Equipped cleaned, CrewInventoryMax respected.
  - S5 fast travel: Do("TravelList") then Do("TravelTo", first entry). The character moves; a second call inside the COOLDOWN is rejected.
  - S6 leave mid-load: covered by Unit_DataSave plus Main's `if not p.Parent` path. In play mode, Kick right after join and check that ReleaseLock ran with a fake store.
- Workflow: run Unit plus S1-S3 before and after every step in sections 2-5. Any change to the golden values fails the step unless it is an intended balance change (none are allowed here).

== 2. JobService split (1853 lines; ServerScriptService.Server.JobService) ==
New ModuleScripts under ServerScriptService.Server.Jobs/. Each has `Init(ctx, S)` and receives the facade table S, so there are no cross-requires.
- Jobs/Stages: venueFolder, stageCount, freeStage, S.StageCF, stageLabel, S.ShowStageLabel, S.Occupied (the facade keeps the same table reference).
- Jobs/Quote: rentPrice, isNight/S.IsNight, S.JobAvailable, S.Plan, S.Quote, S.EquipCheck, defSummary/S.DefSummary, S.Board, S.JobDef.
- Jobs/Tenders: openTenders, S.TenderList, S.BroadcastTenders, S.CleanupTenders, S.SpawnTender, S.AcceptTender, the 2 tender loops plus the PlayerAdded push from S.Init, S.Tenders/S.TenderDefs (same table refs; Admin reads ctx.Jobs.Tenders).
- Jobs/Packing: allocSpot, spotCF, S.SpawnStaging, S.TakeStaged, S.ReturnCarried, packingDone (export as S.PackingDone), S.ForcePack, S.CargoInteract, S.NextNeeded, S.Unload, canLoadWithFlight, S.RackNeed, S.TakeFromRack, S.AutoPack, S.StartPrep.
- Jobs/PackCrew: walkLegs, stackLimit, fetchBatch, crewLoop, robotLoop, ROBOT_SPEED. These are about 250 lines of yielding loops; keep them separate from the request handlers.
- Jobs/Material: matFolder, mk, buildYard, setYard, groundAt, S.MatFree, S.MatNeed, S.MatMissing, truckRoomKg, S.UpdateMat, S.LoadMaterial, S.UnloadMaterial, S.ForceMaterial.
- Jobs/Freight: spedById, spawnPallet, spedDockCF, S.SpedDock, S.SpedLoaded, S.Deliver, S.Spedition, plus a new `S.TickDeliveries(p,job,now)` cut from S.Tick (L311-330).
- Dispatch: S.Dispatch and S.CollectDispatch move into StaffService (drivers already come from ctx.Staff.Count). The facade keeps `S.Dispatch=ctx.Staff.Dispatch`.
- What stays in JobService (facade plus lifecycle): S.Init (requires the submodules and calls Init(ctx,S) in this order: Stages, Quote, Material, Freight, Packing, PackCrew, Tenders), the 0.5 s tick loop, S.Tick (arrival, depot forklift, express warning, calls TickDeliveries), startJob/S.StartJob, S.Accept, S.StartTour, S.Cancel, S.Cleanup, S.Reserved, S.Arrive, S.OnDrive, S.Public, S.TruckAtDepot, S.FmtT.
- The facade must keep every name currently called from outside. The list from grep: Cleanup, MatMissing, StartJob, FmtT, TenderList, TakeFromRack, RackNeed, OnDrive, ForceMaterial, CargoInteract, TruckAtDepot, Tenders, StartTour, Spedition, SpawnTender, ReturnCarried, Reserved, Public, LoadMaterial, JobAvailable, ForcePack, Dispatch, CollectDispatch, CleanupTenders, Cancel, Board, Arrive, AcceptTender, Accept, AutoPack. Write a test that asserts `type(ctx.Jobs[name])=="function"` for each.
- Order (one PR or playtest per step, harness green each time): Tenders, then Quote, then Freight, then Material, then PackCrew, then Packing, then Dispatch. Tenders and Quote have the fewest local cross-calls.
- Risks:
  1. Local upvalue calls such as `packingDone(p)` from Spedition (L1729) and LoadMaterial from packingDone must become S.X calls.
  2. Mutable shared tables (S.Occupied, S.Tenders, S.TenderDefs) must never be reassigned.
  3. Loops spawned in StartPrep capture `job`, so keep the alive() checks.
  4. The DevHook "Call" resolves ctx.Jobs.X at call time, so facade aliases keep it working.

== 3. --!strict rollout ==
Create ReplicatedStorage.Modules.Types (types only):
- `Phase = "Packing"|"Driving"|"Building"|"Ready"|"Show"|"Teardown"`. This also fixes the lsp TypeError at JobService Arrive L1755.
- `StagingEntry={Id:string,Slot:number?,InRack:boolean?,Claimed:boolean?,Spot:number?,Model:Model?}`
- `Mat={Total:number,Depot:number,Venue:number,Transit:number,Reserved:number,Deliveries:{Delivery}}`
- `Delivery={PickAt:number?,LeaveAt:number?,At:number,Kg:number,Items:{string}?,Sped:string,N:number,Of:number,Docked:boolean?,Loaded:boolean?}`
- `Job` = the fields of s.Job built in startJob L593-599 plus the ones set later: Deadline, DeadlineWarned, Packing, Prep, InFlight, Flight, Robots, FullWarned, DepotYard, VenueYard, Pallet, Folder, ShowPrompt, ArrivedAt, ShowAt, Eval, Finished, AutoBuilding, FloorBuilt, Claimed.
- `Session={OwnedPasses:{[string]:boolean},Carry:{CarryEntry},Cargo:{string},Joined:number,Job:Job?,Truck:Model?,Plot:any?,MatKg:number?,Policy:any,...}`
- `Profile` = mirror of D.Template (DataService L18-31) plus LastTrade, SaveSeq, Lock.
- `Ctx = {Sessions:{[Player]:Session},Data:any,Economy:any,...,Push:(Player)->(),Notify:(Player,string,string?,{[string]:any}?)->(),FX:(Player,string,any?)->(),Remote:(string)->Instance}`. Start the services as `any` and tighten them one at a time.
Order:
1. Validate (already annotated), Util, Luck, JobLogic, TenderGen (pure; cheap; covered by the unit tests)
2. GameConfig/WorldConfig: export the table types; these files are huge, so --!nonstrict only
3. Economy, DataService (Profile type), CarryService, SkillService, RewardService
4. The new Jobs/* submodules (strict from birth), JobService facade
5. VehicleService, PlotService (fix the bi/sig lsp errors at L226/L232), PlacementService, ShowService, TradeService
6. Main
7. Client: State, then UI, then HUD
Rule: --!strict only once the file has zero errors. Most "Key not found" errors go away once ctx is typed.

== 4. Move magic numbers to GameConfig (names to add) ==
- G.Net:
  - RateMinInterval=0.12, BucketMax=30, BucketRate=15 (Main L303,313)
  - SnapshotTick=0.2 (Main L176)
- G.Data:
  - LockTimeout=150, LoadAttempts=12, LoadRetryWait=4, RetryBackoff=1.5, CloseBudget=25 (DataService L15-16,59,98,175)
- G.Regions.SplitX=4000 (Main RegionAt L51)
- G.Night = {Start=19.2, End=6.3}. Used in JobService L338, Client.Ambient L240 and Client.Navigator L24; three copies today.
- G.Jobs:
  - TickInterval=0.5, DepotRadius=45, DepotTicks=3, MinTruckRoomKg=50
  - UnloadBatch=12 (L1150)
  - ExpressWarnSecs=60
  - LEDRentPerLevel=2000, RentRound=10 (Quote L419,429)
  - MatReserveFrac=0.5 (Plan L381)
  - StackSmall=4, StackDeck=3
  - RobotSpeed=24
  - TenderFirstDelay=20, TenderCleanupEvery=5, TenderPushDelay=6
- G.Freight:
  - BranchDiscount=0.5, FleetCostMult=0.5, FleetTimeMult=0.5, MinCostMult=0.1, MinTimeMult=0.2, DefaultLoad=6, DefaultTravel=12 (Spedition L1694-1700)
- G.Dispatch.XPFactor=0.3 (CollectDispatch L1843)
- G.Carry.MaxItems=12 (CarryService L44)
- G.Build:
  - PlaceRange=24 (PlacementService L224)
  - ShowStartRange=80, ShowDurationDefault=15 (ShowService L24,41)
- G.Vehicle:
  - DefaultMaxSpeed=46, SpeedSlack=1.25, WarpMinStuds=140, WarpSpeedMult=1.8, WarpPad=30, ParkSpeed=2, HighwayDebounce=6, HomeCooldown=20 (VehicleService L52-66,28,234)
- G.PassMult = {DoubleCash=1, VIP=0.25, DoubleXP=1, TurboTruck=0.3} (Economy L259/263, Vehicle L207)
- G.BonusCacheTTL=1.5
Do this only after the golden test exists. Swap each value 1:1 and change none.

== 5. Network protocol (Main snapshot() L141-170, Client.State, HUD) ==
Current problems:
- Every Request (including read-only GetBoard, TravelList, TradePartners, AutoPreview) runs ctx.Push. That rebuilds the full snapshot (Inventory, Crew up to 100, Stats, Staff, Bonuses, StorageUsed) and JSON-encodes it.
- Job.Public adds `DeadlineIn` (L1806), `Mat.NextIn` and `List[].In` (L1786-1796), which change every second. So any push during an Express job or a pending delivery resends the full snapshot.
Steps:
1. Add `READONLY={GetBoard=true,TravelList=true,TradePartners=true,AutoPreview=true}` in the router and skip ctx.Push for those.
2. Use absolute timestamps. When a job or delivery is created, store `DeadlineAt` and `At` as `workspace:GetServerTimeNow()+secs`, next to the existing os.clock values. Public sends those. HUD L374/L395 and ScreensJobs L457 compute `At - workspace:GetServerTimeNow()`, which removes the HUD.SyncClock dependency. Snapshots then stay identical between real changes.
3. Send only changed top-level keys.
   - Server keeps `lastKeyJson[p][k]` and sends `State:{Seq,Full?,Set={k=v},Del={k,...}}`. nil keys (Job, Admin, Plaza) go in Del.
   - Client State.Init: `local new=table.clone(State.Data or {})`, apply Set/Del, set `State.Data=new`, then `changed:Fire(new, prev)`. All six State.Changed consumers (HUD L452, Ghosts L170, Effects L539, ScreensCrew L333, ScreensJobs L389, ScreensRoadcase L453) keep working unchanged because they read whole sub-tables.
   - On a Seq gap, the client calls Request("ResyncState"); the server clears lastKeyJson[p].
4. Dirty categories: `ctx.Push(p, cat)` with cat in "Core" (Cash, Tokens, XP, Level, Passes, Bonuses, Mults, Daily, Storage, Skill*), "Coll" (Inventory, Crew, Equipped, CrewFound, Roadcases, RCFound, Cases, Vehicles, Expansions, WH, Regions, Venues, Milestones, Stats, Staff, Dispatch, Settings) and "Job" (Job, Carry, CarryKg, CarryMax, Truck). Leaving cat out means all, so it stays backward compatible. The snapshot builder computes only the dirty sections. Crew loops and Tick then only rebuild "Job".
5. Optional later: second-level diffs for Inventory and Crew (keyed maps).

== 6. Other high-leverage items ==
- S.Board (L484-511) runs a full Plan/Assign plus two Evaluate calls for each of the ~38 W.Jobs and each tender on every GetBoard. Cache the result per player for 2 s, keyed on Inventory/LEDLevel/vehicle/bonus version, and invalidate in OnInventoryChanged/OnCrewChanged.
- Net.Get (Net module) calls WaitForChild on every Notify/FX/State fire. Cache the instances in a table after Init.
- PlotService rackOrder (L196) calls `table.find(R.Order, ...)` inside the sort comparator. Precompute an index map `R.OrderIndex`.
- BindToClose: SaveAll(true) (DataService L188) and onLeave's Save(p,true) both write for every player at shutdown. With the 0a queue plus the released flag, the second write becomes a no-op and the DataStore budget is protected.
- One lifecycle helper `ctx.Alive(p, s)` (= `p.Parent and ctx.Sessions[p]==s`). Use it after every yield in ShowService.Finish, crewLoop, robotLoop, PlacementService.workerLoop and the task.delay closures in startJob/Arrive.
- Pass `ctx` itself into DevHook "Call" so admin commands can be scripted: add a hook cmd "Admin" that runs `ctx.Admin.Commands[name](p, args)`. This gives SkipPhase/FinishJob to the tests.

## 2. Widerlegte Befunde: NICHT umsetzen

Diese Behauptungen kamen in der Prüfung auf, wurden aber im Code widerlegt.

- Crew worker loses the taken item and leaves the slot claimed if anything throws between takeFromStock and Put (`ServerScriptService.Server.PlacementService` ~339): refuted/low: The claim only holds if something throws between PlacementService L330 (takeFromStock) and L345 (task.wait). I traced every call in that window and found no throw that can be reached:
- CrewWork.BuildTrip (CrewWork L319-348) already handles the one realistic failure, a missing truck. When PickupPos returns nil it does `if not pick then return nil end`, and workerLoop L340-344 then …
- CrewWork depot-return loop has no pcall: one error leaves crews stuck at 'Truck' server-wide (`ServerScriptService.Server.CrewWork` ~27): refuted/low: I traced every call in the loop (CrewWork L24-36) and found no path that throws.
- `s.Truck and s.Truck.PrimaryPart` short-circuits when there is no truck. In the Plaza, where Truck is nil, `root` is nil and the `if` is skipped.
- `root.AssemblyLinearVelocity` is valid on any BasePart.
- `TruckAtDepot` (JobService L273-279) is nil-safe. It returns false when `not t or not t.Parent or …
- Autosave ignores failures and the 'locked' result, so the player keeps playing without saves and is never told (`ServerScriptService.Server.DataService` ~183): refuted/low: The code matches the quote: D.StartAutosave L183 calls `task.spawn(D.Save, p, false)` and ignores the result, and D.Save returns false, "locked" at L158-160. The failure scenario is still essentially unreachable. Another server can only take the lock (D.Load / UpdateAsync) when the same UserId joins that server. Roblox allows one game session per account, so joining elsewhere …
- SkillService.applied calls Vehicles.UpdateStats without pcall after the skill point has already been written (`ServerScriptService.Server.SkillService` ~24): refuted/low: The example scenario cannot happen. VehicleService.UpdateStats (L204-207) returns early when no truck is spawned: `local s = ctx.Sessions[p]; local m = s and s.Truck; if not m then return end`. After that it only calls SetAttribute, reads Economy bonuses and changes part colors. None of those throw, even on a destroyed model. I found no realistic path where it errors between the …
- Cross-server MessagingService subscription is dead code: ctx.GlobalBroadcast is never called (`ServerScriptService.Main` ~76): refuted/low: The claim is wrong: GlobalBroadcast does have callers. ServerScriptService.Server.CaseService.ModuleScript.lua:33 and ServerScriptService.Server.RoadcaseService.ModuleScript.lua:70 both pick it with `local announce = (rarity == "Secret" and ctx.GlobalBroadcast) or ctx.Broadcast`, which announces Secret drops to every server. The subscription is live and in use. The reviewer probably …

## 3. Unklar: nur prüfen, wenn Zeit ist

- Custom prompt billboard cleanup relies only on PromptHidden (`StarterPlayer.StarterPlayerScripts.Client.Prompts` ~72)

## 4. Gute Muster: NICHT kaputt machen

Diese Stellen haben die Prüfer als gelungen markiert. Bei Umbauten müssen sie erhalten bleiben.

- Single RemoteFunction 'Request' router with an action whitelist (H table), a per-action cooldown (0.12 s) plus a global token bucket (15/s, burst 30), and pcall around every handler with a generic error message to the client (Main L307-328). No OnServerEvent …
- Economy sinks (AddCash/Spend/AddTokens/SpendTokens/AddXP) reject non-finite and negative amounts as a last line of defense (Economy L15-18).
- Session lock in UpdateAsync that never steals a fresh lock and returns nil to abort the write (DataService L78-81, L145-147). ReleaseLock covers the case where the player leaves during load. Temp profiles are never written.
- D.Save returns true only when it actually wrote, and ProcessReceipt uses that: Temp profile means NotProcessedYet, idempotency via d.Purchases (capped at 100), and a rollback when the save fails (Monetization L36-72).
- SetSetting key/type whitelist and Validate.int for SetTutorial stop the profile from growing without bound (Main L279-298).
- PolicyService fails closed (paid random items restricted when the lookup fails), Main L428-436.
- Snapshot dedupe via JSON compare that ignores ServerTime, and per-player tables (dirty, lastCall, bucket, lastSnapJson, bonusCache) are cleared on PlayerRemoving.
- Economy.Bonuses cache with explicit Invalidate on crew, pass and skill changes.
- Integer-ppb loot odds with a deterministic RollOnce fallback, and MaxRolls clamp in Luck.RollCount.
- Studio-only BindableFunction dev hook placed in ServerStorage (never reachable from clients).
- Client init wraps every module's Init in pcall (ClientMain safe()), and UI.Refresh is debounced at 0.25 s.
- Job state is fully server-authoritative. Every ProximityPrompt handler checks `plr ~= p` / `plr == p` before acting (staging, depot yard, pallet, rack).
- crewLoop/robotLoop use an `alive()` guard that checks player presence, session identity, job identity and phase after every yield, which avoids most mid-yield races (leave, cancel, Spedition).
- AcceptTender sets `t.Taken = p` and resets it on startJob failure. Accept, startJob and Spedition contain no yields, so double-accept and double-spend races are impossible.
- Spedition's client-supplied Kg goes through Validate.clampInt (NaN/inf/strings fall back to 'all').
- The material model (Depot/Reserved/Transit/Venue + MatFree) cleanly separates what the forklift may load from what a semi has been promised.
- Each player's Tick runs in its own pcall with warn, so one broken job cannot stop the loop for other players.
- Region-scoped FX (ctx.FireRegion) instead of FireAllClients for crew and semi visuals.
- S.Cleanup is idempotent and runs in pcall on PlayerRemoving. All per-job instances (staging models, yards, pallet, build folder, prompts) are tracked on the job and destroyed there.
- EquipCheck rejects jobs whose equipment cannot fit in one truck trip (unless Komplett-Service applies), so jobs cannot get stuck in Packing.
- CleanupTenders garbage-collects TenderDefs that are no longer referenced by open tenders or running jobs.
- J.TypeModel memoizes, and W.GetLayout caches layouts per venue|size.
- VehicleService.RenderCargo: a dirty flag plus task.defer merges several Add/Take calls in one frame into one rebuild, and the deferred task checks `p.Parent and ctx.Sessions[p] == s` before running.
- VehicleService.Travel is server-authoritative: validates regionId type and unlock, requires the player to be the driver, requires a HighwayTrigger touch less than 45 s ago with the truck still within 150 studs, streams the target with RequestStreamAroundAsync …
- The truck uses ModelStreamingMode.PersistentPerPlayer with AddPersistentPlayer(owner), so only the owner keeps it loaded.
- Ownership checks on every truck prompt (`if plr ~= p`), and the Occupant handler kicks non-owners out of the driver seat.
- PlacementService.Place validates the client slot index with Validate.int(idx, 1, 10000) and checks phase, material and distance on the server before popping the item.
- Crew workers apply game logic only after the planned walk time ends and re-check `s.Job ~= job` / `job.Placed[...]` after every wait; items go back to the truck or pallet if the slot was filled meanwhile.
- ShowService.Start flips Phase to 'Show' synchronously, so the double trigger (prompt plus HUD request) cannot start two shows. Finish is idempotent through `job.Finished` and `s.Job ~= job`.
- FastTravel sets the cooldown before yielding, polls `hum.SeatPart` until the player is really out of the seat, and re-validates the character and player after streaming.
- FastTravel caches the scene list once and sends the client plain data without instances, which works under StreamingEnabled.
- InteractService.Handle checks that the profile is loaded and walks the Owner attribute so players cannot use another company's terminals.
- PlacementService.Put sends Build events through ctx.FireRegion (same city only) instead of FireAllClients.
- WarehouseBuilder.new() builds every part into an unparented folder that is parented only at the end of WB.Build, so it replicates as one batch.
- The template rework is idempotent: originals are saved once, restored before each Build and then re-adapted (tested 1->6->1).
- WB.Build runs under pcall in ApplyExpansions, so a builder error cannot break plot claiming.
- Rack layout uses a signature cache (rackLayout), the slot list is cached per model (rackSlots), and both caches are invalidated after a rebuild.
- P.Marker caches lookups and checks them with IsDescendantOf, so stale markers are detected.
- RenderRacks is debounced per player, checks p.Parent and is pcall-wrapped.
- The owner's warehouse uses ModelStreamingMode PersistentPerPlayer, and OnCharacter calls RequestStreamAroundAsync before the teleport.
- CrewWork plans timestamped legs on the server (GetServerTimeNow); game logic happens only on arrival, and FireRegion limits recipients to the owner's region.
- CrewWork.Workers/SetAt only write an attribute when the value changed; truck extents are cached per truck instance.
- StaffService remotes validate input: Validate.key for the role, type(id)=='string' checks, a lead-busy check before Fire, Spend before mutation, and no yields inside handlers.
- StaffService.Tick wraps each player in pcall inside the 1 Hz loop, and its os.time()-based durations let offline auto-events complete on rejoin.
- Auto-event Net is precomputed with CashMult and credited raw, with no double multiplier; Log is capped at 12.
- CrewService.Recycle checks Lock and Trade.IsOffered before deleting; all uid inputs are type-checked.
- Decoration uses deterministic Random seeds (4711/99), so layouts are stable between rebuilds.
- WarehouseConfig.Level clamps to the module's range and falls back to Base for non-number values; Migrate/Mirror keep old Expansions flags save-compatible.
- Economy.Spend/SpendTokens/AddCash route every amount through `amount()` (finite and non-negative), so NaN/inf can never reach Cash or Tokens even if a caller forgets to validate.
- ShopService validates remote input with `Validate.key(x, Registry)` and `Validate.clampInt(arg.Qty, 1, 20, 1)` before using it; the registry lookup doubles as a whitelist.
- All purchase flows check level, region, storage and capacity first and spend afterwards, with no yield between the check and the mutation, so each purchase is atomic on the server.
- Trade: only saveable profiles can trade (`canTrade` excludes Temp). Ownership is re-validated at execution, any offer change resets both Ready flags and the countdown, Recycle is blocked for offered pets (CrewService.IsOffered), the receiver gets a freshly …
- Pending trade requests use a TTL and are cleaned on leave or when the sender switches target.
- Loot rolls happen server-side with `Random.new()` and integer ppb odds; the client only receives the result.
- Rare-drop broadcasts are delayed until after the client reveal, and Secret names are hidden for cash cases.
- Policy handling is fail-closed (onJoin treats a PolicyService failure as restricted), and the premium roadcase checks policy before PromptProductPurchase.
- Premium roadcases go through ProcessReceipt with idempotency, a save before PurchaseGranted, rollback on failed save, and a deferred auto-open (AfterPurchase) that keeps the case in inventory when storage is full.
- AdminService checks admin rights server-side on every invoke, wraps each command in pcall, has a per-admin rate limit, a bounded audit log (60 entries), filters and escapes text before broadcasting, and protects admins from being kicked.
- Plaza detection requires a reserved server (`PrivateServerId ~= "" and PrivateServerOwnerId == 0`), so TeleportData spoofing on public servers cannot switch a server into Plaza mode. TeleportInitFailed resets the Teleporting flag, and occupancy is written …
- Admin truck warps set `s.TruckWarpAt, s.TruckLastCF = os.clock(), nil` so that the anti-teleport check does not flag legitimate server moves.
- Object pooling: Traffic and Pedestrians build all vehicles/rigs once in Init and park them at y=-1000 instead of Clone/Destroy on every spawn.
- workspace:BulkMoveTo with Enum.BulkMoveMode.FireCFrameChanged is used to batch all per-frame movement (Traffic, Pedestrians, Crowd, CrewDirector).
- Server-timestamped leg plans (T0 + workspace:GetServerTimeNow()) for crew and robots: deterministic on all clients and low bandwidth (one message per task, not per frame).
- Distance LOD everywhere: ANIM_DIST full animation versus every 3rd frame, far peds posed at half rate, crowd skipped beyond 600 and every 3rd frame beyond 260, models unparented beyond VIS_DIST.
- Deterministic crowd placement seeded from msg.Key, so every client sees the same audience.
- Heartbeat bodies wrapped in pcall with warn (only the counter needs decay).
- CrewDirector cleans up properly: per-crew connections stored in c.Conns and disconnected in removeCrew, props destroyed in clearProp. Pets clears per-player state on PlayerRemoving.
- Ambient handles streaming correctly with DescendantAdded/DescendantRemoving registration, a sorted light budget by distance and view direction scaled to the graphics quality level, and the day/night switch spread over frames.
- Motor6D.Transform overrides for the player carry pose are set in Stepped, after the Animator, which is the documented way to override animations.
- Arc-length lookup table for Bezier turns gives cars constant speed through curves; braking distance is computed from curvature (v² = v0² + 2ad).
- Data modules (TrafficData/PedData) use compact flat numeric arrays expanded once on the client, and all link indices validate against the point counts (checked: 0 bad links, no segments under 3 points).
- Rigs are cloned and fully configured before parenting (RA.New parents last), and props are welded to one anchored root so a single CFrame write moves the whole prop.
- Navigator pools strip parts and redraws the route band only when the progress index changes or every 0.3 s (stripsDirty/lastStripI/lastStripT); off-route recalculation is debounced (OFF_TIME, 2 s) and the toast is throttled to once per 10 s.
- NavGraph: a spatial hash grid for segment projection, plus A* with a binary heap, an admissible Euclidean heuristic (edge cost multipliers C >= 1) and early termination on bestCost.
- Hatch wraps play() in pcall with a queue for concurrent openings; tweenNumber destroys its NumberValue on Completed; close() is idempotent via the `closed` flag and runs from both the button and a timeout.
- ShowDirector runs only within 700 studs of the stage, dedupes shows by job Key (running[key]), reference-counts dimmed house lights across overlapping shows, wraps Crowd.Spawn and Crowd.Update in pcall, and tracks every temporary instance in `temp` for …
- Effects dispatches FX through a handler table (H[kind]) on task.spawn, wraps purely visual spawners (SpedTruck/SpedPickup/StaffTruck) in pcall, gates sped-truck visuals by camera distance, and plays carry sounds only on actual count changes.
- Terminals only writes a TextLabel when the text changed (set()), refreshes at 1 Hz near the own warehouse, and rotates holo icons at 30 fps with distance gating.
- Every client-created visual part sets CanQuery=false (and mostly CanTouch/CanCollide=false), so it never interferes with gameplay raycasts such as the Truck ground probe.
- Truck: Studio-only test attributes guarded by RunService:IsStudio(), server-teleport detection (>30 studs per frame) resets yaw and speed, and the raycast filter refreshes every 2 s instead of every frame.
- AdminMoves stays server-authoritative: flags come from server-set attributes, the F3/F4 hotkeys go through the Admin RemoteFunction (which checks admins[p] and rate-limits), and the client never toggles its own powers.
- Prompts disconnects all per-prompt connections and destroys the BillboardGui in PromptHidden:Once, and supports touch/click via InputHoldBegin/End.
- Ghosts removed the previously empty per-frame Heartbeat and disables prompts for locked build phases.
- UI.Refresh coalesces rebuilds with a 0.25 s debounce and refreshNow keeps the ScrollingFrame CanvasPosition across rebuilds (UI L356-383).
- The Jobs board is fetched asynchronously behind a 'Lade Aufträge …' placeholder, and results are dropped when `list.Parent` is nil, so stale responses cannot write into a rebuilt window (ScreensJobs L289-292).
- The Roadcases and Luck windows compare a fingerprint (S.Sig / S.LuckSig) and rebuild only when displayed data changed, not on every cash update (ScreensRoadcase L126-157, L453-460). Worth extending to the other refreshable windows.
- UI.Button's UI.OpenedAt guard stops a double-click from passing through to the window that just opened (UI L171), and buttons expose SetEnabled/SetStyle for consistent disabled styling.
- UI.Viewport strips BaseScripts, ParticleEmitters, Lights, Beams and ProximityPrompts from cloned preview models before showing them (UI L237-239).
- Admin authority is entirely server-side: AdminService checks `admins[p]` and validates action and argument types on every invoke. The client's IsAdmin attribute only hides the UI, and each admin tab builder is pcall-wrapped with an inline error message …
- Client module Init calls run through a `safe()` pcall wrapper in ClientMain, so one broken screen cannot stop the others from loading.
- HUD countdowns are extrapolated locally from snapshot receipt time (HUD.SyncClock + os.clock) instead of polling the server.
- State.Request wraps InvokeServer in pcall and shows a user-facing toast when the connection fails.
- Toasts are capped at 7 on screen; Sounds.Play cleans up through Ended:Once plus a timeout fallback.
- Statically known UI strings go through LocalizationTable AutoLocalize on both ScreenGuis, and dynamic strings through Loc.T with {param} substitution and safe fallbacks.
- Drop odds are integer parts-per-billion and asserted at load to sum exactly to Luck.Total (CaseRegistry L34-39, RoadcaseRegistry L58-60). RoadcaseRegistry also asserts that every rarity with non-zero odds has a pool item (L71). Bad odds tables fail fast.
- Each price has one owner: RoadcaseRegistry reads cash prices from R.RoadcasePrice, premium token prices and pass token prices come from G.NiceTokens(Robux) with no literal copies, and sell values use G.TokenCashValue (in ShopService).
- Exclusive roadcase item stats are derived in code from the strongest shop item of the same type within the city's level cap times case/rarity multipliers (ItemRegistry refPoints L277-291). Rebalancing shop items keeps the exclusives consistent automatically.
- GamePassId/ProductId = 0 placeholders are handled by every consumer (MonetizationService L84/L107/L115, RoadcaseService L110), so unpublished products cannot cause API errors or receipt-mapping collisions.
- The layout cache key is venue|size, bounded to 16 venues × 4 sizes, and FOH adjustment runs once before caching, so there is no unbounded growth and no double transform.
- Save compatibility is handled deliberately: CrewRegistry and CaseRegistry keep the old type and case ids (d.Crew[uid].T, d.Cases) while renaming to pets, with comments explaining why.
- Registries are pure data and helper functions with no connections, loops or instance creation, so they add no runtime per-frame cost and no leaks.
- Optional extras are chosen deterministically from a hash of the job id (W.DefaultOptional), so server and client compute identical extras without network sync.
- One RemoteFunction router (Main L307) with a known-action whitelist, a profile-loaded check, a Plaza action block, a 0.12 s per-action limit plus a 15/s token bucket, and pcall with a generic client error
- Validate module used at the numeric remote inputs (BuyItem Qty clampInt, Place Validate.int, Spedition Kg clampInt, SetTutorial). Economy.amount() rejects NaN, inf and negative values in AddCash/Spend/AddTokens
- SetSetting whitelists keys and value types, which closes the unbounded profile-growth vector
- All world ProximityPrompts check ownership (`plr ~= p`, or the Owner attribute walk in InteractService.ownerOf)
- ProcessReceipt checks the Temp profile, deduplicates PurchaseIds, rolls back when the save fails and caps Purchases at 100
- Trade execute re-checks ownership and inventory space on the server, refuses non-saveable (Temp) profiles, and Recycle is blocked for offered pets
- Server never calls InvokeClient. Clients wrap InvokeServer in pcall (State.Request, ScreensAdmin)
- Truck teleport/speed sanity check that resets instead of kicking. Travel needs a recent server-observed HighwayTrigger touch
- Admin RF is gated per call by the server-side admins table, with rate limiting and an action log. The Studio DevHook is a server-only BindableFunction that only exists in Studio
- Session lock uses UpdateAsync, never steals a fresh lock, and Save returns true only when it actually wrote (written flag set inside the transform)
- ReleaseLock is called when the player leaves during Load, and onJoin checks p.Parent right after Data.Load
- ProcessReceipt is idempotent through d.Purchases (capped at 100), returns NotProcessedYet for Temp profiles, and rolls back the credit when the save fails (incomplete, see findings)
- Temp (unsaveable) profiles are blocked from trading (canTrade) and from the Plaza teleport
- Validate.sanitizeProfile repairs NaN/inf/negative values from older exploits on load; Economy.amount() rejects non-finite amounts at the last line of defense
- Settings keys and types are whitelisted (no unbounded profile growth through SetSetting)
- Main onLeave clears dirty/lastCall/bucket/lastSnapJson/Sessions/Profiles/Temp/bonusCache; FastTravel and Admin clear their cooldown tables on PlayerRemoving
- Long-running crew and robot loops (JobService crewLoop/robotLoop) check alive() after every yield (p.Parent, same session, same job, same phase)
- Staff and Job tick loops wrap each player's tick in pcall, so one bad profile cannot kill the loop
- CaseService.OpenOwned restores the case count when an open fails partway
- Main batches state pushes with a per-player dirty set flushed at 5 Hz and skips identical snapshots by JSON compare (ServerTime excluded), so read-only requests no longer cause a send.
- Crew and robots are simulated on the client. The server sends only timestamped leg lists (CrewWork.Send / robotLoop with T0 = workspace:GetServerTimeNow()), and game logic runs after the computed duration, so there are no server-side NPC humanoids or physics.
- FireRegion limits cosmetic world events (CrewTask, CrewDrop, SpedTruck, Build Done) to players in the same city.
- Truck and warehouse models use ModelStreamingMode.PersistentPerPlayer for the owner only, and RequestStreamAroundAsync runs before 8,000-stud travel warps.
- RenderCargo is coalesced with task.defer and a dirty flag. RenderRacks has a 0.15 s debounce, and rackLayout has a signature cache.
- PlotService.Marker caches recursive FindFirstChild results, Economy.Bonuses has a 1.5 s TTL cache with explicit Invalidate, and CrewWork.truckDims caches GetExtentsSize per truck.
- Attribute writes are guarded by value compare (CrewWorkers, Pets, CrewStageSize), which avoids useless replication.
- All server loops are low frequency (0.3-1 s) and iterate only active sessions. There are no Heartbeat/Stepped connections on the server.
- PlayerRemoving clears dirty, lastCall, bucket, lastSnapJson, the Economy cache and Sessions in Main.onLeave.
- Traffic, Pedestrians, CrewDirector and Crowd batch all transforms with workspace:BulkMoveTo and reuse static buffers via table.clear (partBuf/cfBuf, rootBuf/cfBuf).
- Traffic and Pedestrians use object pools: cars and peds are parked at y=-1000 instead of being destroyed and recreated, and mobile gets lower caps (MAX_CARS 5, MAX_PEDS 6).
- Distance-based LOD: CrewDirector only animates joints fully within ANIM_DIST (otherwise every 3rd frame) and hides rigs beyond VIS_DIST. Pedestrians pose far peds every other frame. Crowd skips updates beyond 600 studs.
- HUD counter() connects RenderStepped only while the number animates and disconnects when it reaches the target.
- Ambient light budget scales with SavedQualityLevel, prioritises by distance and view direction, and cleans up on DescendantRemoving for streaming.
- Weak-keyed caches where it matters: CrewDirector `extents` and `armCache` use __mode='k'.
- ScreensRoadcase rebuilds only when a data signature (S.Sig/S.LuckSig) changes, which should be generalised to the other windows. The Admin panel updates live values in place instead of rebuilding.
- Terminals updates at 1 Hz, only near the player, and writes Text only when it changed. Navigator redraws route strips only on index change or every 0.3 s.
- UI.Refresh 0.25 s debounce, plus a JSON-diff on the server so identical snapshots are never re-sent.
- Client.Truck uses modern constraints (LinearVelocity/AlignPosition/AlignOrientation) with raycast ground-follow and a filter refreshed every 2 s instead of every frame.
- Single ctx service registry in Main with explicit Init order after all requires: no require cycles between server modules (only JobService->TenderGen and PlotService->WarehouseBuilder are direct requires).
- No runtime module requires ServerStorage.DevTools; the only references are comments, and the generated data modules (NavData, PedData, TrafficData, NavExtra) are committed outputs.
- Central Request router with per-action 0.12 s limit plus a token bucket, pcall around every handler, and PLAZA_BLOCK gating per action.
- Net module centralizes remote creation; every remote in Net.Events/Functions has both a server sender and a client listener, and all 23 server FX kinds have a matching client handler.
- Economy.amount() rejects NaN/inf as a last line of defence; Validate.sanitizeProfile repairs old profiles on load.
- PolicyService is fail-closed, and the session-lock release runs when the player leaves during load.
- Per-player tables in Main are cleared in onLeave; FastTravel and AdminService clean their own `last` tables on PlayerRemoving.
- FastTravel uses RequestStreamAroundAsync before PivotTo, which is correct under StreamingEnabled.
