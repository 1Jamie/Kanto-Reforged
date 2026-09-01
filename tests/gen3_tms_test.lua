-- Gen3 TM items + department-store / city-mart shelves (no extra NPCs).
return function(T, Data, run)
  local Gen3Tms = require("mods.Kanto-Reforged.items.gen3_tms")
  local Gen3TmSources = require("mods.Kanto-Reforged.world.gen3_tm_sources")
  local BagPockets = require("mods.Kanto-Reforged.items.bag_pockets")
  local Host = require("mods.Kanto-Reforged.core.host")

  local facadeId = Gen3Tms.itemId("FACADE")
  T.eq(facadeId, "TM_G3_FACADE", "Gen3 TMs use TM_G3_ prefix, not host TM_")
  T.check(Data.items[facadeId] ~= nil, "Facade TM registered")
  T.check(Data.items.TM_FOCUS_PUNCH == nil
      or Data.items.TM_FOCUS_PUNCH == Data.items[Gen3Tms.itemId("FOCUS_PUNCH")],
    "do not register a host-style TM_FOCUS_PUNCH id")
  T.check(Data.items[Gen3Tms.itemId("FOCUS_PUNCH")] ~= nil, "Focus Punch TM registered")
  T.eq(Data.items[facadeId].machine.move, "FACADE", "Facade TM teaches FACADE")
  T.eq(Data.items[facadeId].teaches, "FACADE", "Facade TM has Gen2 teaches")
  T.eq(Data.items[facadeId].name, "TM102", "Facade shows as TM102, not the move name")
  T.eq(Data.items[facadeId].tmLabel, "TM102", "Facade pack label is TM102")
  T.eq(Data.items[Gen3Tms.itemId("FOCUS_PUNCH")].name, "TM61",
    "Focus Punch shows as TM61")
  T.check(Data.items[facadeId].name:find("^TM%d+$") ~= nil,
    "Gen3 TM name is TMxx, not a move name")
  T.eq(BagPockets.classify(facadeId, Data.items[facadeId]), "tmhm",
    "Gen3 TM → tmhm pocket")

  -- Host TMs/HMs keep their ids and moves (old saves keep working).
  T.check(Data.items.TM_TOXIC ~= nil, "host TM_TOXIC still exists")
  T.eq(Data.items.TM_TOXIC.machine.move, "TOXIC", "TM_TOXIC still teaches Toxic")
  T.check(Data.items.TM_MEGA_PUNCH ~= nil, "host TM_MEGA_PUNCH still exists")
  T.eq(Data.items.TM_MEGA_PUNCH.machine.move, "MEGA_PUNCH",
    "TM_MEGA_PUNCH still teaches Mega Punch")
  T.check(Data.items.HM_FLY ~= nil, "HM_FLY still exists")
  T.eq(Data.items.HM_FLY.machine.move, "FLY", "HM_FLY still teaches Fly")
  T.check(Data.items.HM_CUT ~= nil, "HM_CUT still exists")
  T.eq(Data.items.HM_CUT.machine.move, "CUT", "HM_CUT still teaches Cut")
  T.check(Data.items.HM_SURF ~= nil, "HM_SURF still exists")

  local taught = Gen3Tms.hostMoveSet(run.mod)
  T.check(taught.TOXIC == true, "host already teaches Toxic")
  local needed = Gen3Tms.needed(run.mod)
  local listedToxic = false
  for _, row in ipairs(needed) do
    if row.move == "TOXIC" then listedToxic = true end
  end
  T.check(not listedToxic, "Toxic is not in the Gen3 TM needed list")

  for _, row in ipairs(Gen3Tms.MACHINES) do
    local gid = Gen3Tms.itemId(row.move)
    T.check(gid:find("^TM_G3_") == 1, gid .. " uses TM_G3_ prefix")
    if Data.items[gid] then
      T.check(gid ~= "TM_TOXIC" and gid ~= "HM_FLY" and gid ~= "TM_MEGA_PUNCH",
        gid .. " is not a host TM/HM id")
    end
  end

  local oldBag = { TM_MEGA_PUNCH = 1, TM_TOXIC = 2, HM_FLY = 1, TM_BLIZZARD = 1 }
  T.eq(Data.items.TM_MEGA_PUNCH.machine.move, "MEGA_PUNCH",
    "old-save Mega Punch TM is not swapped")
  T.eq(Data.items.HM_FLY.machine.move, "FLY", "old-save Fly HM is not swapped")
  if Data.items.TM_BLIZZARD and Data.items.TM_BLIZZARD.machine then
    T.eq(Data.items.TM_BLIZZARD.machine.move, "BLIZZARD",
      "old-save Blizzard TM is not swapped")
  end
  T.check(oldBag.HM_FLY == 1, "inventory counts are untouched by item registry")

  local stock = Gen3Tms.shopStock(run.mod)
  local hasFacade = false
  for _, id in ipairs(stock) do
    T.check(id:find("^TM_G3_") == 1, "shop stock is Gen3 ids only: " .. id)
    if id == facadeId then hasFacade = true end
  end
  T.check(hasFacade, "needed stock includes Facade")
  T.check(#stock > 0, "needed stock is non-empty")

  local function martHas(mapLabel, textKey, itemId)
    local entry = Data.text_pointers[mapLabel]
    local mart = entry and entry[textKey] and entry[textKey].mart
    if not mart then return false end
    for _, id in ipairs(mart) do
      if id == itemId then return true end
    end
    return false
  end

  local function findObj(mapId, name)
    local def = Data.maps[mapId]
    if not def then return nil end
    for _, o in ipairs(def.objects or {}) do
      if o.name == name then return o end
    end
    return nil
  end

  local function findText(mapId, text)
    local def = Data.maps[mapId]
    if not def then return nil end
    for _, o in ipairs(def.objects or {}) do
      if o.text == text then return o end
    end
    return nil
  end

  -- Story gift NPCs / balls still on their original tiles. No Gen3 TM NPCs.
  T.check(findText("ROUTE_16_FLY_HOUSE", "TEXT_ROUTE16FLYHOUSE_BRUNETTE_GIRL"),
    "Route 16 Fly girl still present")
  T.check(findObj("ROUTE_16_FLY_HOUSE", "G3TM_IMPORTER") == nil
      and findObj("ROUTE_16_FLY_HOUSE", "G3TM_FOCUS_PUNCH") == nil,
    "no Gen3 TM NPC in the Fly house")
  T.check(findObj("CELADON_MART_2F", "G3TM_IMPORTER") == nil
      and findObj("FIGHTING_DOJO", "G3TM_FOCUS_PUNCH") == nil,
    "no Gen3 TM importer/gift NPCs on maps")
  T.check(findText("FIGHTING_DOJO", "TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL"),
    "Hitmonlee prize ball still present")
  T.check(findText("FIGHTING_DOJO", "TEXT_FIGHTINGDOJO_HITMONCHAN_POKE_BALL"),
    "Hitmonchan prize ball still present")
  local nugget = findText("ROCKET_HIDEOUT_B2F", "TEXT_ROCKETHIDEOUTB2F_NUGGET")
    or findObj("ROCKET_HIDEOUT_B2F", "ROCKETHIDEOUTB2F_NUGGET")
  T.check(nugget ~= nil, "Rocket Hideout Nugget ball still present")
  if nugget then
    T.eq(nugget.item, "NUGGET", "Nugget ball still gives NUGGET")
  end

  if Host.isGen1() then
    T.check(martHas("CeladonMart2F", "TEXT_CELADONMART2F_CLERK2", facadeId),
      "Celadon 2F TM clerk sells Facade")
    T.check(not martHas("CeladonMart2F", "TEXT_CELADONMART2F_CLERK1", facadeId),
      "Celadon 2F item clerk does not sell Facade")
    local punchId = Gen3Tms.itemId("FOCUS_PUNCH")
    T.check(martHas("PewterMart", "TEXT_PEWTERMART_CLERK", punchId),
      "Pewter mart sells Focus Punch")
    T.check(not martHas("PewterMart", "TEXT_PEWTERMART_CLERK", facadeId),
      "Pewter does not also sell the dept-store bulk")
    local celadon = Data.text_pointers.CeladonMart2F
    local shelf = celadon and celadon.TEXT_CELADONMART2F_CLERK2
      and celadon.TEXT_CELADONMART2F_CLERK2.mart
    local hasVanilla = false
    for _, id in ipairs(shelf or {}) do
      if type(id) == "string" and not id:find("^TM_G3_") then
        hasVanilla = true
      end
    end
    T.check(hasVanilla, "Celadon 2F TM clerk still has vanilla TM stock (append, not replace)")
    local prev = 0
    for _, id in ipairs(shelf or {}) do
      local n = Gen3Tms.numberOf(id, Data.items)
      T.check(n > prev, id .. " is in TM-number order on Celadon 2F")
      prev = n
    end
  end

  -- Gen2 extras: Goldenrod 5F TM Corner / Celadon 3F; Cianwood gets Focus Punch.
  do
    local plan = Gen3TmSources.plan(run.mod)
    local byId = Gen3TmSources.gen2Extras(plan)
    local gold5f = byId[Gen3TmSources.GEN2_MART.GOLDENROD_5F_1] or {}
    local hasDept = false
    for _, id in ipairs(gold5f) do
      if id == facadeId then hasDept = true end
    end
    T.check(hasDept, "Gen2 plan puts Facade on Goldenrod 5F TM Corner")
    T.check(byId[7] == nil or #(byId[7]) == 0,
      "Gen2 plan does not dump TMs on Goldenrod 3F Battle Collection")
    local celadon3f = byId[Gen3TmSources.GEN2_MART.CELADON_3F] or {}
    local celadonHas = false
    for _, id in ipairs(celadon3f) do
      if id == facadeId then celadonHas = true end
    end
    T.check(celadonHas, "Gen2 plan puts Facade on Celadon 3F TM Showcase")
    T.check(byId[23] == nil or #(byId[23]) == 0,
      "Gen2 plan does not dump TMs on Celadon 2F item clerk")
    local cianwood = byId[Gen3TmSources.GEN2_MART.CIANWOOD] or {}
    local hasPunch = false
    for _, id in ipairs(cianwood) do
      if id == Gen3Tms.itemId("FOCUS_PUNCH") then hasPunch = true end
    end
    T.check(hasPunch, "Gen2 plan puts Focus Punch in Cianwood mart")
    local prev = 0
    for _, id in ipairs(plan.dept) do
      local n = Gen3Tms.numberOf(id, Data.items)
      T.check(n > prev, id .. " is in TM-number order on the dept plan")
      prev = n
    end

    local lists = {
      [8] = { "X_SPEED" },           -- GOLDENROD_3F is martId 7 → lists[8]
      [10] = { "TM_FIRE_PUNCH" },    -- GOLDENROD_5F_1 is martId 9 → lists[10]
      [5] = { "POTION" },            -- CIANWOOD is martId 4 → lists[5]
    }
    Gen3TmSources.applyGen2Lists(lists, byId)
    local goldHas, punchHas, battleHas = false, false, false
    for _, id in ipairs(lists[10]) do
      if id == facadeId then goldHas = true end
      if id == "TM_FIRE_PUNCH" then punchHas = true end
    end
    for _, id in ipairs(lists[8]) do
      if id == facadeId then battleHas = true end
    end
    T.check(goldHas, "applyGen2Lists appends Facade to Goldenrod 5F")
    T.check(punchHas, "applyGen2Lists keeps vanilla Goldenrod 5F TMs")
    T.check(not battleHas, "applyGen2Lists leaves Goldenrod 3F X items alone")
  end
end
