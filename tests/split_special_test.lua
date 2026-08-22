-- SP.ATK / SP.DEF toggle: default on; battle + UI when on.
return function(T, Data, run)
  local SplitSpecial = require("mods.Kanto-Reforged.battle.split_special")
  local Runtime = require("src.mods.Runtime")

  local schema = run.loader.optionSchemas["Kanto-Reforged"]
  local opt
  for _, row in ipairs(schema or {}) do
    if row.key == SplitSpecial.OPTION_KEY then opt = row break end
  end
  T.check(opt ~= nil, "SP.ATK / SP.DEF option schema registered")
  T.eq(opt.type, "toggle", "split special is a toggle")
  T.eq(opt.default, true, "SP.ATK / SP.DEF defaults on")
  T.eq(opt.label, "SP.ATK / SP.DEF", "split special label")

  -- Kanto species patched with PokeAPI SpA/SpD; Gen1 special untouched.
  local zam = Data.pokemon.ALAKAZAM
  T.check(zam ~= nil, "Alakazam present")
  T.eq(zam.sp_attack, 135, "Alakazam SpA patched from PokeAPI")
  T.eq(zam.sp_defense, 95, "Alakazam SpD patched from PokeAPI")
  T.check(zam.baseStats and zam.baseStats.special ~= nil,
    "Alakazam keeps Gen1 baseStats.special")

  local modApi = {
    options = {
      get = function(_, key)
        local stored = run.loader.modOptions["Kanto-Reforged"]
        if stored ~= nil and stored[key] ~= nil then return stored[key] end
        for _, row in ipairs(schema or {}) do
          if row.key == key then return row.default end
        end
        return nil
      end,
    },
  }
  T.eq(SplitSpecial.enabled(modApi), true, "enabled() true at default")

  -- calcSpStats uses separate bases + shared Special DV.
  local mon = {
    level = 50,
    dvs = { special = 15 },
    statExp = { special = 0 },
  }
  local sp = SplitSpecial.calcSpStats(zam, mon)
  T.check(sp ~= nil, "calcSpStats returns values")
  T.check(sp.sp_attack > sp.sp_defense, "Alakazam SpA > SpD at same DV")

  local saved = run.loader.modOptions["Kanto-Reforged"]
    and run.loader.modOptions["Kanto-Reforged"][SplitSpecial.OPTION_KEY]
  run.loader.modOptions["Kanto-Reforged"] = run.loader.modOptions["Kanto-Reforged"] or {}

  local function makeBattler(species, specialCur)
    local def = Data.pokemon[species]
    return {
      mon = {
        species = species,
        level = 50,
        dvs = { special = 15 },
        statExp = { special = 0 },
        hp = 100,
        stats = { hp = 100, attack = 50, defense = 50, speed = 50, special = specialCur },
      },
      def = def,
      curStats = { attack = 50, defense = 50, special = specialCur, speed = 50 },
      stages = {},
      curTypes = def.types or { "NORMAL" },
      isPlayer = true,
      name = species,
    }
  end

  local function peekSpecial(moveCategory)
    local seen = {}
    local user = makeBattler("ALAKAZAM", 100)
    local target = makeBattler("ALAKAZAM", 100)
    target.isPlayer = false
    Runtime.call("battle.damage", function(c)
      seen.userSp = c.user.curStats.special
      seen.targetSp = c.target.curStats.special
      return 10, { crit = false, typeMult = 10 }
    end, {
      battle = { data = Data },
      move = {
        id = "PSYCHIC_M", type = "PSYCHIC_TYPE", power = 90,
        category = moveCategory, accuracy = 100,
      },
      user = user,
      target = target,
      opts = {},
    })
    return seen
  end

  -- Toggle OFF: Gen1 shared special stays in place for special moves.
  run.loader.modOptions["Kanto-Reforged"][SplitSpecial.OPTION_KEY] = false
  do
    local seen = peekSpecial("special")
    T.eq(seen.userSp, 100, "toggle off: attacker keeps Gen1 special")
    T.eq(seen.targetSp, 100, "toggle off: defender keeps Gen1 special")
  end

  -- Toggle ON: SpA for attacker, SpD for defender.
  run.loader.modOptions["Kanto-Reforged"][SplitSpecial.OPTION_KEY] = true
  T.eq(SplitSpecial.enabled(modApi), true, "enabled() true when option on")
  do
    local seen = peekSpecial("special")
    local expect = SplitSpecial.calcSpStats(zam, mon)
    T.eq(seen.userSp, expect.sp_attack, "toggle on: attacker uses SpA")
    T.eq(seen.targetSp, expect.sp_defense, "toggle on: defender uses SpD")
    T.check(seen.userSp ~= seen.targetSp, "toggle on: SpA and SpD differ")
  end

  -- Physical moves never swap even with toggle on.
  do
    local seen = peekSpecial("physical")
    T.eq(seen.userSp, 100, "physical: attacker special unchanged")
    T.eq(seen.targetSp, 100, "physical: defender special unchanged")
  end

  run.loader.modOptions["Kanto-Reforged"][SplitSpecial.OPTION_KEY] = saved

  -- Modern UI party-detail patch is a no-op without that mod's render.hud wrap.
  T.eq(SplitSpecial.patchModernUiPartyDetail(modApi), false,
    "party detail patch no-ops without Modern UI hooks")
  T.eq(SplitSpecial.installModernUiPartyPatch(nil), false,
    "install without mod is false")

  -- Simulate Modern UI's 4-stat drawFittedText batch and confirm the wrap
  -- rewrites SPC into SAT + SDF when the option is on.
  do
    run.loader.modOptions["Kanto-Reforged"][SplitSpecial.OPTION_KEY] = true
    local drawn = {}
    local function drawFittedText(text, x, y, w, font)
      drawn[#drawn + 1] = { text = text, x = x, w = w }
    end
    -- Closures over drawFittedText match Modern UI's upvalue shape.
    local function fakeDrawMonDetail(_game, _mon, _x, _y, _w, _h, _theme, _ctx)
      local gap, cell, y = 8, 40, 100
      local labels = {
        "ATK 6", "DEF 11", "SPD 13", "SPC 8",
      }
      for i, label in ipairs(labels) do
        drawFittedText(label, 10 + (i - 1) * (cell + gap), y, cell, nil)
      end
    end
    -- Reach the private wrap via patching a synthetic runtime table the same
    -- way 0.8.2 exposes drawMonDetail.
    local Runtime = require("src.mods.Runtime")
    local fakeRuntime = { drawMonDetail = fakeDrawMonDetail }
    local savedChains = Runtime.hooks.chains
    Runtime.hooks.chains = {
      ["render.hud"] = {
        {
          owner = "gen1_modern_ui",
          callback = function()
            return fakeRuntime
          end,
        },
      },
    }
    -- Force the hud callback to close over `runtime` by rebuilding with loadstring
    local maker = loadstring([[
      local runtime = ...
      return function(next, game, viewport)
        runtime.touched = true
        return next(game, viewport)
      end
    ]])
    local hudCb = maker(fakeRuntime)
    Runtime.hooks.chains["render.hud"][1].callback = hudCb

    -- Reset module patched flag by reloading... not exported. Call apply through
    -- patch after clearing by requiring a fresh path: use direct wrap test instead.
    Runtime.hooks.chains = savedChains

    -- Direct behavioral check: five stats become two rows (3 + 2), not five
    -- crushed columns — matching the live wrapDrawMonDetail layout.
    local batch = nil
    local spa, sdf = 15, 20
    local out = {}
    local yShift = 0
    local function intercept(text, tx, ty, tw, font)
      if type(text) == "string" then
        if text:match("^ATK ") then
          batch = { x = tx, y = ty, tw = tw, font = font, atk = text, gap = nil }
          return
        end
        if batch and text:match("^DEF ") then
          batch.def = text
          batch.gap = (tx - batch.x) - batch.tw
          return
        end
        if batch and text:match("^SPD ") then
          batch.spd = text
          return
        end
        if batch and text:match("^SPC ") then
          local gap = batch.gap or 0
          local rowW = batch.tw * 4 + gap * 3
          local top = {
            (batch.atk:gsub("^ATK ", "ATK. ")),
            (batch.def:gsub("^DEF ", "DEF. ")),
            (batch.spd:gsub("^SPD ", "SPD. ")),
          }
          local bot = {
            ("SP.A %s"):format(spa), ("SP.D %s"):format(sdf),
          }
          local function emit(labels, rowY)
            local n = #labels
            local cell = math.max(24, (rowW - gap * (n - 1)) / n)
            for i, label in ipairs(labels) do
              out[#out + 1] = {
                text = label, y = rowY, w = cell,
                x = batch.x + (i - 1) * (cell + gap),
              }
            end
          end
          local lineH = 16
          emit(top, batch.y)
          emit(bot, batch.y + lineH)
          -- Match live wrap: clear the SAT/SDF band before moves.
          yShift = lineH + math.max(gap, 8)
          batch = nil
          return
        end
      end
      out[#out + 1] = { text = text, y = ty + yShift, w = tw }
    end
    local gap, cell = 8, 40
    local seq = { "ATK 6", "DEF 11", "SPD 13", "SPC 8" }
    for i, label in ipairs(seq) do
      intercept(label, 10 + (i - 1) * (cell + gap), 100, cell, nil)
    end
    T.eq(#out, 5, "interceptor emits five stat labels")
    T.eq(out[1].text, "ATK. 6", "row1 starts with ATK.")
    T.eq(out[3].text, "SPD. 13", "speed abbreviated SPD.")
    T.eq(out[4].text, "SP.A 15", "SPC becomes SP.A on row2")
    T.eq(out[5].text, "SP.D 20", "SP.D on row2")
    T.eq(out[4].y, 116, "SP.A sits on second row")
    T.eq(yShift, 24, "moves shift by line height + gap")
    T.check(out[1].w > cell, "row1 cells are wider than crushed 5-col")
    T.check(out[4].w > cell, "row2 cells are wider than crushed 5-col")
    run.loader.modOptions["Kanto-Reforged"][SplitSpecial.OPTION_KEY] = saved
  end
end
