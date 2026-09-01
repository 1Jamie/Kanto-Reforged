-- Emerald TM items that the host cart does not already teach.
-- Item ids are TM_G3_<MOVE> so they never collide with TM01 DynamicPunch /
-- Mega Punch. Old saves keep their host TM_/HM_ keys.

local Gen3Tms = {}

-- Emerald TM01–50. HMs are omitted (host carts already have Cut/Fly/…).
Gen3Tms.MACHINES = {
  { n = 1,  move = "FOCUS_PUNCH",  price = 4000 },
  { n = 2,  move = "DRAGON_CLAW",  price = 4000 },
  { n = 3,  move = "WATER_PULSE",  price = 2000 },
  { n = 4,  move = "CALM_MIND",    price = 3000 },
  { n = 5,  move = "ROAR",         price = 2000 },
  { n = 6,  move = "TOXIC",        price = 3000 },
  { n = 7,  move = "HAIL",         price = 2000 },
  { n = 8,  move = "BULK_UP",      price = 3000 },
  { n = 9,  move = "BULLET_SEED",  price = 2000 },
  { n = 10, move = "HIDDEN_POWER", price = 3000 },
  { n = 11, move = "SUNNY_DAY",    price = 2000 },
  { n = 12, move = "TAUNT",        price = 3000 },
  { n = 13, move = "ICE_BEAM",     price = 4000 },
  { n = 14, move = "BLIZZARD",     price = 5500 },
  { n = 15, move = "HYPER_BEAM",   price = 7500 },
  { n = 16, move = "LIGHT_SCREEN", price = 2000 },
  { n = 17, move = "PROTECT",      price = 2000 },
  { n = 18, move = "RAIN_DANCE",   price = 2000 },
  { n = 19, move = "GIGA_DRAIN",   price = 3000 },
  { n = 20, move = "SAFEGUARD",    price = 2000 },
  { n = 21, move = "FRUSTRATION",  price = 3000 },
  { n = 22, move = "SOLARBEAM",    price = 3000 },
  { n = 23, move = "IRON_TAIL",    price = 3000 },
  { n = 24, move = "THUNDERBOLT",  price = 4000 },
  { n = 25, move = "THUNDER",      price = 5500 },
  { n = 26, move = "EARTHQUAKE",   price = 4000 },
  { n = 27, move = "RETURN",       price = 3000 },
  { n = 28, move = "DIG",          price = 2000 },
  { n = 29, move = "PSYCHIC_M",    price = 3000 },
  { n = 30, move = "SHADOW_BALL",  price = 3000 },
  { n = 31, move = "BRICK_BREAK",  price = 3000 },
  { n = 32, move = "DOUBLE_TEAM",  price = 2000 },
  { n = 33, move = "REFLECT",      price = 2000 },
  { n = 34, move = "SHOCK_WAVE",   price = 3000 },
  { n = 35, move = "FLAMETHROWER", price = 4000 },
  { n = 36, move = "SLUDGE_BOMB",  price = 3000 },
  { n = 37, move = "SANDSTORM",    price = 2000 },
  { n = 38, move = "FIRE_BLAST",   price = 5500 },
  { n = 39, move = "ROCK_TOMB",    price = 2000 },
  { n = 40, move = "AERIAL_ACE",   price = 3000 },
  { n = 41, move = "TORMENT",      price = 2000 },
  { n = 42, move = "FACADE",       price = 3000 },
  { n = 43, move = "SECRET_POWER", price = 2000 },
  { n = 44, move = "REST",         price = 2000 },
  { n = 45, move = "ATTRACT",      price = 2000 },
  { n = 46, move = "THIEF",        price = 2000 },
  { n = 47, move = "STEEL_WING",   price = 2000 },
  { n = 48, move = "SKILL_SWAP",   price = 2000 },
  { n = 49, move = "SNATCH",       price = 2000 },
  { n = 50, move = "OVERHEAT",     price = 4000 },
}

Gen3Tms.PREFIX = "TM_G3_"

function Gen3Tms.itemId(move)
  return Gen3Tms.PREFIX .. move
end

function Gen3Tms.hostMoveSet(mod)
  local taught = {}
  local prefix = Gen3Tms.PREFIX
  local function consider(id, def)
    if type(id) == "string" and id:sub(1, #prefix) == prefix then
      return
    end
    if type(def) ~= "table" then return end
    if def.teaches then taught[def.teaches] = true end
    if def.machine and def.machine.move then
      taught[def.machine.move] = true
    end
  end
  local Data = package.loaded["src.core.Data"]
  if Data and type(Data.items) == "table" then
    for id, def in pairs(Data.items) do
      consider(id, def)
    end
  end
  if mod and mod.content and mod.content.items and mod.content.items.each then
    for id, def in mod.content.items:each() do
      consider(id, def)
    end
  end
  -- Host carts spell Psychic as PSYCHIC or PSYCHIC_M.
  if taught.PSYCHIC then taught.PSYCHIC_M = true end
  if taught.PSYCHIC_M then taught.PSYCHIC = true end
  return taught
end

function Gen3Tms.needed(mod)
  local taught = Gen3Tms.hostMoveSet(mod)
  local out = {}
  for _, row in ipairs(Gen3Tms.MACHINES) do
    if not taught[row.move] then
      out[#out + 1] = row
    end
  end
  return out
end

function Gen3Tms.shopStock(mod)
  local stock = {}
  for _, row in ipairs(Gen3Tms.needed(mod)) do
    stock[#stock + 1] = Gen3Tms.itemId(row.move)
  end
  return stock
end

-- Host carts already occupy TM01–TM50. Offset so the bag/shop label is
-- still the Gen 1/2 "TMxx" form without colliding with Mega Punch / Headbutt.
function Gen3Tms.displayNumber(n)
  return 60 + n
end

function Gen3Tms.displayName(n)
  return ("TM%02d"):format(Gen3Tms.displayNumber(n))
end

local function itemsTable(mod)
  if mod and mod.data and type(mod.data.items) == "table" then
    return mod.data.items
  end
  local Data = package.loaded["src.core.Data"]
  return Data and Data.items
end

function Gen3Tms.numberOf(itemId, items)
  items = items or itemsTable()
  local def = items and items[itemId]
  if type(def) == "table" then
    if def.machine and tonumber(def.machine.number) then
      return tonumber(def.machine.number)
    end
    if tonumber(def.tmNumber) then return tonumber(def.tmNumber) end
    local digits = tostring(def.name or ""):match("(%d+)")
    if digits then return tonumber(digits) end
  end
  local digits = tostring(itemId or ""):match("(%d+)")
  return tonumber(digits) or 9999
end

function Gen3Tms.isMachineList(ids, items)
  if type(ids) ~= "table" or #ids == 0 then return false end
  items = items or itemsTable()
  for _, id in ipairs(ids) do
    local def = items and items[id]
    local tm = (type(def) == "table" and def.machine)
      or (type(id) == "string" and id:find("^TM_") == 1)
    if not tm then return false end
  end
  return true
end

function Gen3Tms.sortIds(ids, items)
  if type(ids) ~= "table" then return ids end
  items = items or itemsTable()
  table.sort(ids, function(a, b)
    local na, nb = Gen3Tms.numberOf(a, items), Gen3Tms.numberOf(b, items)
    if na ~= nb then return na < nb end
    return tostring(a) < tostring(b)
  end)
  return ids
end

function Gen3Tms.register(mod)
  if not (mod and mod.content and mod.content.items) then return 0 end
  local n = 0
  for _, row in ipairs(Gen3Tms.needed(mod)) do
    if mod.content.moves:get(row.move) then
      local id = Gen3Tms.itemId(row.move)
      if not mod.content.items:get(id) then
        local number = Gen3Tms.displayNumber(row.n)
        local label = Gen3Tms.displayName(row.n)
        local ok = pcall(function()
          mod.content.items:register(id, {
            id = id,
            name = label,
            tmLabel = label,
            tmNumber = number,
            price = row.price or 3000,
            tossable = true,
            needsTarget = true,
            machine = { kind = "TM", move = row.move, number = number },
            teaches = row.move,
          })
        end)
        if ok then n = n + 1 end
      end
    end
  end
  mod.log:info("Registered %d Gen3 TM items missing from the host", n)
  return n
end

return Gen3Tms
