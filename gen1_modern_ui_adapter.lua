-- Optional Gen1 Modern UI contract for Kanto Reforged.
-- No-op when gen1_modern_ui is not installed; native Gen1 screens stay as-is.

local SummaryUi = require("mods.Kanto-Reforged.summary_ui")
local SplitSpecial = require("mods.Kanto-Reforged.split_special")
local TypeChart = require("src.battle.TypeChart")
local Growth = require("src.pokemon.Growth")
local Gender = require("mods.Kanto-Reforged.gender")

local function call(state, names, ...)
  local api = state and state.gen1ModernUi
  if type(api) == "table" then
    for _, name in ipairs(names) do
      if type(api[name]) == "function" then
        return api[name](api, ...)
      end
    end
  end
  for _, name in ipairs(names) do
    if type(state[name]) == "function" then
      return state[name](state, ...)
    end
  end
  return false
end

local function bagMatches(state)
  return type(state) == "table"
    and state.screenId == "BagMenu"
    and type(state.items) == "table"
    and type(state.__pocketIndex) == "number"
    and type(state.__pocketIds) == "table"
    and type(state.title) == "string"
end

local function bagModel(_, state)
  local rows = {}
  for _, item in ipairs(state.items or {}) do
    rows[#rows + 1] = {
      label = item.label or item.name or "ITEM",
      value = item.right or item.displayValue or item.count,
      enabled = item.enabled,
      source = {
        id = item.value,
        prefix = item.prefix,
        move = item.move,
      },
    }
  end
  return {
    title = state.title or "ITEMS",
    rows = rows,
    index = state.index or 1,
    scroll = state.scroll or 0,
    footer = { "LEFT/RIGHT pocket", "A use", "B back" },
  }
end

local function summaryMatches(state)
  return type(state) == "table"
    and state.screenId == "SummaryMenu"
    and state._expMaxPage == 3
    and type(state.page) == "number"
    and state.mon ~= nil
end

local function monTitle(mon, def)
  local base = mon.nickname or (def and def.name) or mon.species or "POKéMON"
  return Gender.nameWithGlyph(mon, base)
end

local function typeLabel(def)
  if not def or not def.types then return "-----" end
  local a = def.types[1] and TypeChart.displayName(def.types[1]) or nil
  local b = def.types[2] and TypeChart.displayName(def.types[2]) or nil
  if a and b then return a .. " / " .. b end
  return a or "-----"
end

local function movePp(move, moveDef)
  if not move or not moveDef then return "--" end
  local maxPP = (moveDef.pp or 0) + (move.ppUps or 0) * math.floor((moveDef.pp or 0) / 5)
  return ("%d/%d"):format(move.pp or 0, maxPP)
end

local function summaryModel(mod, game, state)
  local data = (game and game.data) or (state.game and state.game.data) or {}
  local mon = state.mon
  local def = data.pokemon and data.pokemon[mon.species]
  local page = state.page or 1
  local title = monTitle(mon, def)
  local assets = state.sprite and { portrait = state.sprite } or nil
  local footer = { ("A/B next  %d/3"):format(page) }
  local rows

  if page == 1 then
    local stats = mon.stats or {}
    rows = {
      {
        label = title,
        value = mon.level and ("Lv " .. tostring(mon.level)) or "",
        image = assets and "portrait" or nil,
        enabled = false,
      },
      {
        label = "HP",
        value = stats.hp and ("%d/%d"):format(mon.hp or 0, stats.hp) or "-----",
        enabled = false,
      },
      { label = "STATUS", value = mon.status or "OK", enabled = false },
      { label = "TYPE", value = typeLabel(def), enabled = false },
      { label = "ATTACK", value = tostring(stats.attack or "-"), enabled = false },
      { label = "DEFENSE", value = tostring(stats.defense or "-"), enabled = false },
      { label = "SPEED", value = tostring(stats.speed or "-"), enabled = false },
    }
    if SplitSpecial.enabled(mod) then
      -- Match native summary abbreviations when five stats are shown.
      rows[5].label = "ATK."
      rows[6].label = "DEF."
      rows[7].label = "SPD."
      local sp = SplitSpecial.calcSpStats(def, mon)
      rows[#rows + 1] = {
        label = "SP.A",
        value = tostring(sp and sp.sp_attack or stats.special or "-"),
        enabled = false,
      }
      rows[#rows + 1] = {
        label = "SP.D",
        value = tostring(sp and sp.sp_defense or stats.special or "-"),
        enabled = false,
      }
    else
      rows[#rows + 1] = {
        label = "SPECIAL",
        value = tostring(stats.special or "-"),
        enabled = false,
      }
    end
    rows[#rows + 1] = {
      label = "ID No.",
      value = ("%05d"):format(mon.otId or (game.save and game.save.player
        and game.save.player.id) or 0),
      enabled = false,
    }
    rows[#rows + 1] = {
      label = "OT",
      value = mon.ot or (game.save and game.save.player and game.save.player.name)
        or "-----",
      enabled = false,
    }
  elseif page == 2 then
    local nextExp = 0
    if def and mon.level and mon.level < 100 and mon.exp then
      nextExp = math.max(0, Growth.expForLevel(def.growthRate, mon.level + 1) - mon.exp)
    end
    rows = {
      { label = "EXP POINTS", value = tostring(mon.exp or 0), enabled = false },
      {
        label = "TO NEXT LEVEL",
        value = mon.level and mon.level >= 100 and "-----" or tostring(nextExp),
        enabled = false,
      },
    }
    for i = 1, 4 do
      local move = mon.moves and mon.moves[i]
      local moveDef = move and data.moves and data.moves[move.id]
      rows[#rows + 1] = {
        label = (moveDef and moveDef.name) or (move and move.id) or "-",
        value = move and ("PP " .. movePp(move, moveDef)) or "--",
        enabled = false,
      }
    end
  else
    local info = SummaryUi.abilityPage(mon, data)
    local effect = table.concat(info.description or {}, " ")
    if effect == "" then effect = "-----" end
    rows = {
      { label = "GENDER", value = info.gender, enabled = false },
      { label = "ITEM", value = info.heldItem, enabled = false },
      { label = "ABILITY", value = info.ability, enabled = false },
      { label = "EFFECT", value = effect, enabled = false },
    }
  end

  return {
    title = page == 1 and "STATUS" or (page == 2 and "MOVES / EXP" or "ABILITY"),
    rows = rows,
    index = 1,
    scroll = 0,
    footer = footer,
    assets = assets,
    details = page == 3 and SummaryUi.abilityPage(mon, data) or nil,
  }
end

local function summaryAdvance(_, state)
  if type(state.advance) == "function" then
    return state:advance()
  end
  return false
end

return function(mod)
  local Host = require("mods.Kanto-Reforged.host")
  if Host.isGen2() then
    return false, "Gen1 Modern UI adapter is Gen1-only"
  end
  local ui = mod.find and mod.find("gen1_modern_ui") or nil
  if not (ui and ui.exports and ui.exports.registerAdapter) then
    return false, "Gen1 Modern UI is not installed"
  end

  SplitSpecial.installModernUiPartyPatch(mod)

  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    screens = {
      UsefulBag = {
        match = bagMatches,
        model = bagModel,
        actions = {
          up = function(_, state)
            return call(state, { "moveCursor", "move" }, -1)
          end,
          down = function(_, state)
            return call(state, { "moveCursor", "move" }, 1)
          end,
          left = function(_, state)
            return call(state, { "switchPocket", "movePocket", "pocket" }, -1)
          end,
          right = function(_, state)
            return call(state, { "switchPocket", "movePocket", "pocket" }, 1)
          end,
          select = function(_, state)
            return call(state, { "select", "choose", "use" })
          end,
          back = function(_, state)
            return call(state, { "back", "close", "exit" })
          end,
          hover = function(_, state, index)
            return call(state, { "hover", "preview" }, index)
          end,
        },
        layer = "screen",
        canSuppressNative = true,
      },
      -- Covers all three KR summary pages so pages 1-2 are not left on
      -- native Gen1 while page 3 alone uses the modern list presenter.
      KantoSummary = {
        match = summaryMatches,
        model = function(game, state)
          return summaryModel(mod, game, state)
        end,
        actions = {
          select = summaryAdvance,
          back = summaryAdvance,
        },
        layer = "screen",
        canSuppressNative = true,
      },
    },
  }

  return ui.exports.registerAdapter({
    owner = mod.id,
    contract = mod.exports.gen1ModernUi,
  })
end
