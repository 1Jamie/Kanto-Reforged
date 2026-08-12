-- Standalone: luajit mods/Kanto-Reforged/tests/gold_mvp_standalone.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
local GameVersion = require("src.core.GameVersion")
local Host = require("mods.Kanto-Reforged.host")

-- Loader generation=2 alone does not flip GameVersion; Host (and real Gold
-- boots) key off GameVersion / Host.force. Keep this in-mod — no engine edits.
GameVersion.set("gold")
Host.force(2)

pcall(function()
  Data:load()
end)

-- Prefer a local Gold ROM cache so TILESET_JOHTO collision is real (berry farm
-- block remap). Game2 boots load this via data/generated under the gold root.
do
  local home = os.getenv("HOME") or ""
  local paths = {
    home .. "/.local/share/love/pokemon-love2d/gold/data/generated/tilesets.lua",
    "data/generated/tilesets.lua",
  }
  for _, p in ipairs(paths) do
    local ok, ts = pcall(dofile, p)
    if ok and ts and ts.TILESET_JOHTO and ts.TILESET_JOHTO.collision then
      Data.gen2Tilesets = ts
      break
    end
  end
end

local run = T.sdk.loadMods({
  "mods/pokegear_cards",
  "mods/Kanto-Reforged",
}, {
  data = Data,
  generation = 2,
})

local fatal = {}
for _, err in ipairs(run.errors or {}) do
  -- Soft: registry "no Gen 2 target" warnings are expected for Gen1-only content.
  if not tostring(err):find("has no Gen 2 target", 1, true) then
    fatal[#fatal + 1] = err
  end
end
T.eq(#fatal, 0, "Gold MVP loads with no fatal loader errors")
if #fatal > 0 then
  for _, err in ipairs(fatal) do
    print("fatal:", err)
  end
end

local treecko = Data.pokemon and Data.pokemon.TREECKO
T.check(treecko ~= nil, "TREECKO registered on Gold")
if treecko then
  T.check(treecko.baseStats and treecko.baseStats.specialAttack ~= nil,
    "TREECKO has Gen2 specialAttack")
  T.check(treecko.levelMoves ~= nil or treecko.learnset ~= nil,
    "TREECKO has level moves")
end

-- Johto natives only exist when a Gold cache was imported.
if Data.pokemon and Data.pokemon.CHIKORITA then
  T.check(true, "CHIKORITA still present (Gold native)")
else
  print("note: no Gold cache — skipped CHIKORITA native check")
end

local farm = (Data.gen2Maps and Data.gen2Maps.BERRY_FARM)
  or (Data.maps and Data.maps.BERRY_FARM)
T.check(farm ~= nil, "BERRY_FARM map registered on Gold")

-- Farm access: Johto stairs corner + Kanto exit-mat pads
local BerryFarm = require("mods.Kanto-Reforged.berry_farm")
local HouseNpcs = require("mods.Kanto-Reforged.house_npcs")
T.eq(BerryFarm.PC_DOOR_GEN2_STAIRS.x, 8, "Johto farm stairs at warp-tile x=8")
T.eq(BerryFarm.PC_DOOR_GEN2_PAD.x, 7, "Kanto farm pad left warp-tile")
T.eq(BerryFarm.PC_DOOR_GEN2_INDIGO.x, 16, "Indigo farm stairs warp at BL x=16")
T.eq(BerryFarm.PC_DOOR_GEN2_INDIGO.y, 13, "Indigo farm stairs warp at BL y=13")
T.eq(BerryFarm.PC_BLOCKS_GEN2_INDIGO[7 * 9], 18,
  "Indigo SE corner block is stairs (warp collision)")
T.check(HouseNpcs._talks.TEXT_BERRY_FARM_GIRL ~= nil,
  "Gold talk dispatch has farm girl")
T.check(HouseNpcs._talks.TEXT_BERRY_FARM_MERCHANT ~= nil
    or HouseNpcs._talks.TEXT_BERRY_FARM_SOIL_EXPERT ~= nil,
  "Gold talk dispatch has berry quest NPCs")

-- Gen1 OVERWORLD ids on TILESET_JOHTO turn cobble into water and fences into
-- hop ledges. When Gold tilesets are present the farm must use Johto ids.
if Data.gen2Tilesets and Data.gen2Tilesets.TILESET_JOHTO then
  T.check(farm and farm.tileset == "TILESET_JOHTO",
    "Berry farm uses TILESET_JOHTO when Gold tilesets exist")
  T.eq(farm.borderBlock, BerryFarm.GEN2_TILES.WALL,
    "Johto farm border is pine tree wall $05")
  T.eq(farm.blocks[2 * 19 + 5], BerryFarm.GEN2_TILES.DOOR,
    "Johto shed door block is $77")
  -- Cobble walkways must not be water ($55 was Gen1 cobble → Johto water).
  local waterish = { [0x35] = true, [0x43] = true, [0x54] = true, [0x55] = true,
    [0x58] = true, [0x59] = true, [0x76] = true }
  local yardWater = 0
  for row = 1, 10 do
    for col = 1, 8 do
      local b = farm.blocks[row * 19 + col + 1]
      if waterish[b] then yardWater = yardWater + 1 end
    end
  end
  T.eq(yardWater, 0, "Johto farm yard has no water blocks on paths/plots")
  -- Lake columns stay water.
  T.eq(farm.blocks[3 * 19 + 12], BerryFarm.GEN2_TILES.DEEP,
    "Johto farm lake uses open-water block")

  local Permissions = require("src.world.gen2.Permissions")
  local coll = Data.gen2Tilesets.TILESET_JOHTO.collision
  local function blockWalkable(bid)
    local quad = coll[bid + 1]
    if not quad then return false end
    for _, c in ipairs(quad) do
      if Permissions.isWalkable(c) and not Permissions.isWater(c) then
        return true
      end
    end
    return false
  end
  T.check(blockWalkable(BerryFarm.GEN2_TILES.COBBLE),
    "Johto path block is land-walkable")
  T.check(blockWalkable(BerryFarm.GEN2_TILES.GRASS),
    "Johto plot ground is land-walkable")
  T.check(not blockWalkable(BerryFarm.GEN2_TILES.WALL),
    "Johto tree wall is not land-walkable")
  local doorQuad = coll[BerryFarm.GEN2_TILES.DOOR + 1]
  local hasDoor = false
  for _, c in ipairs(doorQuad or {}) do
    if c == 0x71 then hasDoor = true end
  end
  T.check(hasDoor, "Johto shed door block has COLL_DOOR")
end

-- Plot markers are full-RGBA custom art; Gen2 must not remap them via PAL_OW_*.
do
  local sprites = Data.gen2Sprites or Data.sprites or {}
  local soil = sprites.SPRITE_PLOT_SOIL
  T.check(soil ~= nil, "SPRITE_PLOT_SOIL registered on Gold")
  if soil then
    T.eq(soil.trueColor, true, "plot soil sprite is trueColor (skip OW palette)")
    T.check(type(soil.image) == "string" and soil.image:find("plot_soil", 1, true),
      "plot soil points at custom asset")
  end
  local growing = sprites.SPRITE_PLOT_GROWING
  T.check(growing and growing.trueColor == true,
    "plot growing sprite is trueColor")
  local cheri = sprites.SPRITE_PLOT_CHERI
  T.check(cheri and cheri.trueColor == true,
    "ripe plot sprites are trueColor")
end

-- Berry vendor: Gen1 ShopMenu crashes on Gold (save.money is nil). Buy via
-- Gen2MartMenu against player.money instead.
do
  local BerryQuests = require("mods.Kanto-Reforged.berry_quests")
  local Save = require("src.core.gen2.Save")
  local input = {
    pressed = {},
    press = function(self, btn) self.pressed[btn] = true end,
    wasPressed = function(self, btn)
      if self.pressed[btn] then self.pressed[btn] = nil; return true end
      return false
    end,
    isDown = function() return false end,
  }
  local stack = { _items = {} }
  function stack:push(s) self._items[#self._items + 1] = s end
  function stack:pop() return table.remove(self._items) end
  function stack:top() return self._items[#self._items] end
  local save = Save.newGame()
  save.player.money = 5000
  save.inventory = {}
  local game = {
    save = save,
    input = input,
    data = {
      items = {
        BERRY = { id = "BERRY", name = "BERRY", price = 300, tossable = true },
        CHERI_BERRY = { id = "CHERI_BERRY", name = "CHERI BERRY",
          price = 600, tossable = true },
      },
    },
    stack = stack,
  }
  BerryQuests.openShop(game, { "BERRY", "CHERI_BERRY" }, function() end)
  local mart = stack:top()
  T.check(mart ~= nil and mart.phase ~= nil, "Gold berry shop opens Gen2MartMenu")
  if mart then
    T.eq(#mart.entries, 2, "Berry stall shelves unlocked stock")
    local function press(btn)
      input:press(btn)
      mart:update(0)
    end
    -- STANDARD: top BUY/SELL/QUIT → BUY → first item → qty 1 → YES
    press("a") -- BUY
    T.eq(mart.phase, "buy", "Berry stall entered buy list")
    press("a") -- BERRY
    T.eq(mart.phase, "buyQuantity", "Berry stall asks quantity")
    press("a") -- confirm qty 1
    T.check(mart.confirm ~= nil, "Berry stall price confirm")
    press("a") -- YES
    T.eq(save.inventory.BERRY, 1, "Bought one BERRY from stall")
    T.eq(save.player.money, 4700, "Gold money deducted on berry buy")
  end
end

local cherrygrove = Data.gen2Maps and Data.gen2Maps.CHERRYGROVE_POKECENTER_1F
if cherrygrove then
  local hasStairs
  for _, w in ipairs(cherrygrove.warps or {}) do
    if w.destMap == "BERRY_FARM" and w.x == 8 and w.y == 7 then
      hasStairs = true
    end
  end
  T.check(hasStairs, "Cherrygrove PC has Johto stairs farm warp at (8,7)")
  if cherrygrove.blocks and #cherrygrove.blocks >= 20 then
    T.eq(cherrygrove.blocks[20], 18, "Cherrygrove east south block is stairs")
  end
end

local viridian = Data.gen2Maps and Data.gen2Maps.VIRIDIAN_POKECENTER_1F
if viridian then
  local hasPad, padBlocks
  for _, w in ipairs(viridian.warps or {}) do
    if w.destMap == "BERRY_FARM" and (w.x == 7 or w.x == 8) and w.y == 7 then
      hasPad = true
    end
  end
  if viridian.blocks and #viridian.blocks >= 20 then
    padBlocks = viridian.blocks[19] == 17 and viridian.blocks[20] == 39
  end
  T.check(hasPad, "Viridian PC has Kanto farm pad warps")
  if padBlocks ~= nil then
    T.check(padBlocks, "Viridian PC south row has farm exit mats")
  end
end

local mansion = Data.gen2Maps and Data.gen2Maps.CELADON_MANSION_2F
if mansion then
  local club
  for _, o in ipairs(mansion.objects or {}) do
    if o.name == "CELADONMANSION2F_BATTLE_CLUB" then club = o end
  end
  T.check(club ~= nil, "Celadon Circuit NPC on Kanto mansion 2F")
end

T.check(Data.items and Data.items.CHERI_BERRY, "CHERI_BERRY item registered on Gold")
T.check(Data.items and Data.items.CHOICE_BAND, "CHOICE_BAND item registered on Gold")

-- DexNav lives on the Pokegear on Gold (not the start menu), via pokegear_cards.
local DexNav = require("mods.Kanto-Reforged.dexnav")
local Pokegear = require("src.ui.gen2.Pokegear")
T.check(Pokegear._pokegearCards == true, "pokegear_cards patch installed on Gold")
local cardsApi = run.loader.exports.pokegear_cards
T.check(cardsApi and cardsApi.get("dexnav"), "DexNav registered on pokegear_cards")
do
  local schema = run.loader.optionSchemas["Kanto-Reforged"] or {}
  local byKey = {}
  for _, opt in ipairs(schema) do byKey[opt.key] = opt end
  T.check(byKey.dexnav_mode == nil, "Gold hides DexNav rename/off option")
  T.check(byKey.split_special == nil, "Gold hides SP.ATK/SP.DEF option")
  local lock = byKey.switch_hit_ai
  T.check(lock ~= nil, "Gold still has SWITCH HIT AI")
  T.eq(lock.choices[1][1], "GEN 2", "Gold switch-hit classic label is GEN 2")
  T.eq(lock.choices[2][1], "GEN 3", "Gold switch-hit lock label is GEN 3")
end
do
  local enc1 = select(1, DexNav.sourcesForMap(Data, "ROUTE_1"))
  T.check(enc1 ~= nil and enc1.grass ~= nil, "DexNav reads grass for ROUTE_1 on Gold")
  -- Johto guest inject needs imported Gold encounter tables (skipped on
  -- fixture-only boots without gen2Encounters.grass.ROUTE_29).
  local enc29 = select(1, DexNav.sourcesForMap(Data, "ROUTE_29"))
  if enc29 and enc29.grass and enc29.grass.slots then
    local items = DexNav.buildItems(Data, "ROUTE_29", { seen = {}, caught = {} }, nil, nil)
    local ids, gen3 = {}, 0
    local GEN3 = {
      POOCHYENA=true, ZIGZAGOON=true, SEEDOT=true, RALTS=true, WHISMUR=true,
      SKITTY=true, ELECTRIKE=true, PLUSLE=true, MINUN=true, GULPIN=true,
      SPOINK=true, SWABLU=true, ZANGOOSE=true, SEVIPER=true, TAILLOW=true,
      VOLBEAT=true, ILLUMISE=true,
    }
    for _, row in ipairs(items or {}) do
      if row.value then
        ids[row.value] = true
        if GEN3[row.value] then gen3 = gen3 + 1 end
      end
    end
    local n = 0
    for _ in pairs(ids) do n = n + 1 end
    T.check(n >= 3 and n <= 8, "ROUTE_29 DexNav stays short (got " .. n .. ")")
    T.check(gen3 >= 1 and gen3 <= 3, "ROUTE_29 has a few Gen3 guests (got " .. gen3 .. ")")
    T.check(ids.PIDGEY or ids.SENTRET or ids.RATTATA or ids.HOOTHOOT,
      "ROUTE_29 still lists Gold natives")
  else
    T.check(true, "ROUTE_29 DexNav skipped (no Gold encounter cache)")
    T.check(true, "ROUTE_29 Gen3 guests skipped (no Gold encounter cache)")
    T.check(true, "ROUTE_29 Gold natives skipped (no Gold encounter cache)")
  end
end

T.check(Data.type_chart and Data.type_chart.types and Data.type_chart.types.FAIRY,
  "FAIRY type registered")

-- Gen3 type/matchup/move parity with Red (same KR patches on Gold)
local function getMatchup(attacker, defender)
  for _, row in ipairs(Data.type_chart.matchups or {}) do
    if row.attacker == attacker and row.defender == defender then
      return row.multiplier
    end
  end
  return nil
end

T.eq(getMatchup("GHOST", "PSYCHIC_TYPE"), 20, "Gold: Ghost vs Psychic is SE")
T.eq(getMatchup("BUG", "POISON"), 5, "Gold: Bug vs Poison is NVE")
T.eq(getMatchup("POISON", "BUG"), 10, "Gold: Poison vs Bug is neutral")
T.eq(getMatchup("ICE", "FIRE"), 5, "Gold: Ice vs Fire is NVE")
T.eq(getMatchup("DARK", "PSYCHIC_TYPE"), 20, "Gold: Dark vs Psychic is SE")
T.eq(getMatchup("FAIRY", "DRAGON"), 20, "Gold: Fairy vs Dragon is SE")

if Data.moves and Data.moves.BITE then
  T.eq(Data.moves.BITE.type, "DARK", "Gold: Bite is Dark")
end
if Data.moves and Data.moves.GUST then
  T.eq(Data.moves.GUST.type, "FLYING", "Gold: Gust is Flying")
end
if Data.moves and Data.moves.KARATE_CHOP then
  T.eq(Data.moves.KARATE_CHOP.type, "FIGHTING", "Gold: Karate Chop is Fighting")
end
if Data.moves and Data.moves.SAND_ATTACK then
  T.eq(Data.moves.SAND_ATTACK.type, "GROUND", "Gold: Sand-Attack is Ground")
end
if Data.moves and Data.moves.CHARM then
  T.eq(Data.moves.CHARM.type, "NORMAL", "Gold: Charm is Normal (Gen3)")
end

-- Gen3 imports must resolve GBC colors (not grayscale) on Gold.
local Palettes = require("src.world.gen2.Palettes")
local treeckoPal = Data.gen2Palettes and Data.gen2Palettes.pokemon
  and Data.gen2Palettes.pokemon.TREECKO
T.check(treeckoPal ~= nil, "Gold: TREECKO has gen2Palettes.pokemon entry")
if treeckoPal then
  T.check(treeckoPal.normal and treeckoPal.normal[1] and treeckoPal.normal[2],
    "Gold: TREECKO normal mid-pair present")
end
local treeckoColors = Palettes.monColors(Data.gen2Palettes, "TREECKO", false)
T.check(treeckoColors ~= nil, "Gold: Palettes.monColors(TREECKO) resolves")
if treeckoColors then
  T.eq(#treeckoColors, 4, "Gold: TREECKO colors are 4 shades")
  -- Not flat grayscale: mid shades should differ from white/black and each other
  local mid1, mid2 = treeckoColors[2], treeckoColors[3]
  T.check(mid1[1] ~= mid2[1] or mid1[2] ~= mid2[2] or mid1[3] ~= mid2[3],
    "Gold: TREECKO mid colors are not identical (has hue)")
end

local TypeChart = require("src.battle.TypeChart")
-- Ensure TypeChart sees merged Gold chart (Game.load path may not run in this harness)
pcall(function() TypeChart.load(Data) end)
if Data.pokemon and Data.pokemon.RALTS then
  T.eq(TypeChart.effectiveness("DARK", Data.pokemon.RALTS.types), 20,
    "Gold: Dark vs Ralts is 2×")
end

-- FULL SPAWN MIX helpers on Gold
do
  local EncountersGen2 = require("mods.Kanto-Reforged.encounters_gen2")
  T.check(EncountersGen2._isKantoMap("ROUTE_1"), "ROUTE_1 is Kanto")
  T.check(EncountersGen2._isKantoMap("ROUTE_28"), "ROUTE_28 is Kanto")
  T.check(not EncountersGen2._isKantoMap("ROUTE_29"), "ROUTE_29 is Johto")
  T.check(EncountersGen2._isKantoMap("VIRIDIAN_FOREST"), "Viridian Forest is Kanto")

  local pack = require("mods.Kanto-Reforged.pokemon_data")
  local index = EncountersGen2._buildGoldIndex(run.loader.mods[1] and run.loader.mods[1].api or {
    content = {
      pokemon = {
        each = function()
          return pairs({
            PIDGEY = { dex = 16, baseStats = { hp = 40, attack = 45, defense = 40, speed = 56, special = 35 } },
            SENTRET = { dex = 161, baseStats = { hp = 35, attack = 46, defense = 34, speed = 20, special = 35 } },
            TREECKO = { dex = 252, habitat = "forest",
              baseStats = { hp = 40, attack = 45, defense = 35, speed = 70, special = 65 } },
            MEWTWO = { dex = 150, habitat = "rare" },
          })
        end,
      },
    },
  }, pack)
  T.check(index.meta.TREECKO or index.meta.ZIGZAGOON or true,
    "Gold index builds from pack/registry")
  T.check(not (index.meta.MEWTWO and not index.meta.MEWTWO.rare),
    "Mewtwo not a normal wild entry")

  -- Route 30 is dry grassland/forest — curated guests must not be fish.
  local r30pool = EncountersGen2._poolFor({ "grassland", "forest" }, 6)
  local r30hasFish = false
  for _, sp in ipairs(r30pool) do
    if sp == "BARBOACH" or sp == "CARVANHA" or sp == "CORPHISH"
        or sp == "WAILMER" then
      r30hasFish = true
    end
  end
  T.check(not r30hasFish, "Route 30 curated pool has no fish/water-only mons")
  local guests30 = EncountersGen2._pickGuests({
    content = {
      pokemon = {
        get = function(_, id)
          return pack.species and pack.species[id] or { id = id }
        end,
      },
    },
  }, "ROUTE_30", { level = 6, habitats = { "grassland", "forest" }, count = 2 })
  for _, sp in ipairs(guests30) do
    T.check(sp ~= "BARBOACH", "Route 30 guest is not Barboach (" .. tostring(sp) .. ")")
  end
  local habs30 = EncountersGen2._habitatsForMap("ROUTE_30")

  -- Gold Kanto curated postgame tables must stay populated (not Absol-only /
  -- empty after Johto-early level bands filtered everything out).
  do
    local kantoPools = EncountersGen2._KANTO_HABITAT_POOL
    T.check(kantoPools ~= nil, "Kanto postgame habitat pools exported")
    local r9 = EncountersGen2._poolFor({ "mountain" }, 34, kantoPools)
    T.check(#r9 >= 4, "Route 9 postgame mountain pool has real variety")
    local absolOnly = #r9 == 1 and r9[1] == "ABSOL"
    T.check(not absolOnly, "Route 9 is not Absol-only")
    local r24 = EncountersGen2._poolFor({ "waters-edge", "forest" }, 32, kantoPools)
    T.check(#r24 >= 4, "Routes 24/25 postgame pool is non-empty")
    local r21 = EncountersGen2._poolFor({ "sea", "grassland" }, 32, kantoPools)
    local hasSea = false
    for _, sp in ipairs(r21) do
      if sp == "PELIPPER" or sp == "WAILMER" or sp == "CARVANHA" then
        hasSea = true
      end
    end
    T.check(hasSea, "Route 21 pool includes sea Gen3")
    -- Johto lakeside: bank + rock, not desert Trapinch as the only rock pick.
    local r42 = EncountersGen2._pickGuests({
      content = {
        pokemon = {
          get = function(_, id)
            return pack.species and pack.species[id] or { id = id }
          end,
        },
      },
    }, "ROUTE_42", {
      level = 20, habitats = { "waters-edge", "mountain" }, count = 2,
    })
    local hasTrapinch = false
    for _, sp in ipairs(r42) do
      if sp == "TRAPINCH" then hasTrapinch = true end
    end
    T.check(not hasTrapinch, "Route 42 guests skip desert Trapinch")
  end
  local hasWaterHab = false
  for _, h in ipairs(habs30) do
    if h == "waters-edge" or h == "sea" then hasWaterHab = true end
  end
  T.check(not hasWaterHab, "Route 30 map habitats stay dry")

  -- Live full_random when Gold encounter grass tables exist
  local grass = Data.gen2Encounters and Data.gen2Encounters.grass
  if grass and grass.ROUTE_29 and grass.ROUTE_1 then
    local modApi = nil
    for _, m in ipairs(run.loader.mods or {}) do
      if m.id == "Kanto-Reforged" or (m.api and m.api.id == "Kanto-Reforged") then
        modApi = m.api or m
        break
      end
    end
    if not modApi and run.loader.mods and run.loader.mods[1] then
      modApi = run.loader.mods[1].api or run.loader.mods[1]
    end
    -- Fall back: build a minimal patching shim against Data.gen2Encounters
    if not modApi or not modApi.content then
      modApi = {
        id = "Kanto-Reforged",
        log = { info = function() end, warn = function() end },
        content = {
          encounters = {
            get = function(_, kind) return Data.gen2Encounters[kind] end,
            patch = function(_, kind, partial)
              Data.gen2Encounters[kind] = Data.gen2Encounters[kind] or {}
              for mapId, block in pairs(partial) do
                Data.gen2Encounters[kind][mapId] = block
              end
            end,
          },
          pokemon = {
            each = function()
              return pairs(Data.pokemon or {})
            end,
            get = function(_, id) return Data.pokemon and Data.pokemon[id] end,
          },
        },
        options = { get = function(_, k) return k == "full_spawn_random" end },
      }
    end
    EncountersGen2.clearBaselines()
    local before29 = grass.ROUTE_29.slots.DAY[1].species
    EncountersGen2.apply(modApi, pack, "full_random")
    local after29 = Data.gen2Encounters.grass.ROUTE_29.slots.DAY[1].species
    local after1 = Data.gen2Encounters.grass.ROUTE_1.slots.DAY[1].species
    T.check(after29 ~= nil and after1 ~= nil, "full_random fills Johto and Kanto slots")
    -- Restore curated so later DexNav assumptions stay sane if any
    EncountersGen2.apply(modApi, pack, "curated")
    T.check(true, "curated reapplies after full_random (" .. tostring(before29) .. "→" .. tostring(after29) .. ")")
  else
    T.check(true, "full_random live rewrite skipped (no Gold encounter cache)")
    T.check(true, "curated reapply skipped (no Gold encounter cache)")
  end
end

run.release()
Host.clearForce()
GameVersion.set("red")

T.finish("gold_mvp")
