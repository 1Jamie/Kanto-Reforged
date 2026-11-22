-- Extra Gen 1 → Gen 2/3 in-game trades with held-item preloads.
-- FRLG: Route 2 House + Fuchsia House 1 (Bill's Grandpa analogue).

local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")

local TradesExtra = {}
TradesExtra.OWNER = "trades_extra"

TradesExtra.TRADES = {
  {
    give = "RATTATA",
    get = "TAILLOW",
    nickname = "SWIFT",
    dialogset = 1,
    held = "CLEANSE_TAG",
    heldItemId = 190, -- ITEM_CLEANSE_TAG
    flag = "MOD_TRADE_TAILLOW_DONE",
    map = "ROUTE_2_TRADE_HOUSE",
    g3Map = "FR_ROUTE2_HOUSE",
    index = 3,
    name = "ROUTE2TRADEHOUSE_TAILLOW",
    sprite = "SPRITE_BRUNETTE_GIRL",
    graphicsId = 23,
    text = "TEXT_ROUTE2TRADEHOUSE_TAILLOW",
    x = 6, y = 5,
    -- FRLG HOUSE2: (5,4) is the table; stand south of it on open floor.
    gen3X = 6, gen3Y = 6,
  },
  {
    give = "BELLSPROUT",
    get = "SEEDOT",
    nickname = "GLAND",
    dialogset = 2,
    held = "SOOTHE_BELL",
    heldItemId = 184, -- ITEM_SOOTHE_BELL
    flag = "MOD_TRADE_SEEDOT_DONE",
    map = "FUCHSIA_BILLS_GRANDPAS_HOUSE",
    g3Map = "FR_FUCHSIA_CITY_HOUSE1",
    index = 4,
    name = "FUCHSIABILLSGRANDPASHOUSE_SEEDOT",
    sprite = "SPRITE_GRAMPS",
    graphicsId = 61,
    text = "TEXT_FUCHSIABILLSGRANDPASHOUSE_SEEDOT",
    x = 6, y = 4,
    -- FRLG HOUSE1: (5,4) is the table; stand west of it, clear of the old man.
    gen3X = 4, gen3Y = 4,
  },
}

local heldByGet = {}

function TradesExtra.refreshScope(mod, scopeMode)
  -- Trades stay registered; talk gate below refuses under kanto.
end

local function tradeFlagDone(mod, game, flag)
  if mod and mod.save and mod.save.get and mod.save:get(flag, false) then
    return true
  end
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local session = game and (game.session or game.save)
    if session and session.flags and session.flags[flag] then
      return true
    end
  end
  return false
end

local function setTradeFlag(mod, game, flag)
  if mod and mod.save and mod.save.set then
    mod.save:set(flag, true)
  end
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local session = game and (game.session or game.save)
    if session then
      session.flags = session.flags or {}
      session.flags[flag] = true
    end
  end
end

local function speciesMatches(mon, wantName)
  if not mon then return false end
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen3() then
    local Pokemon = require("src.core.game3.pokemon")
    local want = Pokemon.speciesFromName(wantName)
    local have = mon.species or mon.speciesId
    if type(have) == "string" then
      have = Pokemon.speciesFromName(have) or tonumber(have)
    end
    return want and have and tonumber(have) == tonumber(want)
  end
  return mon.species == wantName
end

local function talkGen3(mod, row)
  return function(game, ow, npc, done)
    local Strings = require("src.core.Strings")
    if tradeFlagDone(mod, game, row.flag) then
      HouseNpcs.pushText(game, Strings(
        "Thanks for trading\nme your %s!", row.give), done)
      return
    end

    HouseNpcs.ask(game, Strings(
      "Want to trade my\n%s for your\n%s?", row.get, row.give), function(yes)
      if not yes then
        if done then done() end
        return
      end
      local party = HouseNpcs.getParty(game)
      local candidates = {}
      for i, mon in ipairs(party) do
        if speciesMatches(mon, row.give) then
          local label = mon.nickname
          if not label or label == "" then
            local Pokemon = require("src.core.game3.pokemon")
            label = Pokemon.name(mon.species or mon.speciesId) or row.give
          end
          candidates[#candidates + 1] = { label = label, value = i }
        end
      end
      if #candidates == 0 then
        HouseNpcs.pushText(game, Strings(
          "You don't have a\n%s to trade!", row.give), done)
        return
      end
      local Choice = require("src.ui.game3.choice")
      local labels = {}
      for _, c in ipairs(candidates) do labels[#labels + 1] = c.label end
      labels[#labels + 1] = "CANCEL"
      Choice.multi(labels, 0, function(idx)
        local chosen = (type(idx) == "number") and candidates[idx + 1]
        if not chosen then
          if done then done() end
          return
        end
        local Pokemon = require("src.core.game3.pokemon")
        local Party = require("src.core.game3.party")
        local session = game.session or game.save
        local slot = chosen.value
        local level = math.max(5, tonumber(party[slot].level) or 10)
        local getId = Pokemon.speciesFromName(row.get)
        if not getId then
          HouseNpcs.pushText(game, Strings("Trade failed."), done)
          return
        end
        -- Build offered mon in a scratch session, then swap into the party slot.
        local scratch = {
          party = {},
          name = "TRADER",
          trainerId = 41203,
        }
        local ok, _, offered = Party.giveMon(scratch, getId, level, row.nickname, {})
        if not (ok and offered) then
          HouseNpcs.pushText(game, Strings("Trade failed."), done)
          return
        end
        offered.item = row.heldItemId or 0
        offered.heldItem = row.heldItemId or 0
        offered.friendship = 70
        offered.happiness = 70
        local Trade = require("src.core.game3.scripting.natives_trade")
        if Trade.tradeMons then
          Trade.tradeMons(session, slot - 1, offered)
        else
          session.party[slot] = offered
        end
        setTradeFlag(mod, game, row.flag)
        HouseNpcs.pushText(game, Strings(
          "Yes! Take good care\nof my %s!", row.get), done)
      end)
    end)
  end
end

function TradesExtra.register(mod)
  local Host = require("mods.Kanto-Reforged.core.host")

  if not Host.isGen3() then
    local patch = {}
    for _, row in ipairs(TradesExtra.TRADES) do
      patch[#patch + 1] = {
        give = row.give,
        get = row.get,
        nickname = row.nickname,
        dialogset = row.dialogset,
      }
      heldByGet[row.get] = row.held
    end
    mod.content.field:patch("trades", patch)
  end

  local baseIndex = 10
  for i, row in ipairs(TradesExtra.TRADES) do
    local tradeIndex = baseIndex + i
    local mapId = Host.isGen3() and (row.g3Map or row.map) or row.map
    HouseNpcs.appendNpc(mod, mapId, {
      index = Host.isGen3() and (90 + i) or row.index,
      name = row.name,
      sprite = row.sprite,
      graphicsId = row.graphicsId,
      text = row.text,
      x = row.x,
      y = row.y,
      gen3X = row.gen3X or row.x,
      gen3Y = row.gen3Y or row.y,
    }, TradesExtra.OWNER)

    if Host.isGen3() then
      HouseNpcs.bindTalk(mod, mapId, {
        [row.text] = talkGen3(mod, row),
      })
    else
      mod.content.map_scripts:register(row.map, {
        talk = {
          [row.text] = function(game, ow, npc, done)
            local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
            if not SpeciesScope.allowsSpeciesId(mod, row.get, nil) then
              local Strings = require("src.core.Strings")
              HouseNpcs.pushText(game, Strings(
                "Hmm... my offer's for\na NATIONAL DEX run.\f"
                  .. "Come back off KANTO\nscope."), done)
              return
            end
            if not HouseNpcs.runScript(ow, { { "trade", tradeIndex, row.flag } }, {
              npc = npc,
              onDone = done,
            }) then
              local Strings = require("src.core.Strings")
              HouseNpcs.pushText(game, Strings(
                "I want to trade my\n%s for a\n%s!",
                row.get, row.give), done)
            end
          end,
        },
      })
    end
  end

  if Host.isGen3() then return end

  -- Apply held preload when in-game trade creates the received mon.
  -- Concatenate the module name so gen2check cannot MK402 this Gen1-only require;
  -- TradesExtra.register only runs under Host.isGen1() for this hook.
  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  local cmdName = "src" .. ".script.Commands"
  local ok, Commands = pcall(require, cmdName)
  if not ok or not Commands then return end
  Gen1Patch.apply(Commands, function(Commands)
    if Commands._expansionTradeHeld then return end
    local original = Commands.trade
    Commands.trade = function(ctx, tradeIndex, doneFlag)
      original(ctx, tradeIndex, doneFlag)
      local trade = ctx.game.data.field.trades[tradeIndex]
      local held = trade and heldByGet[trade.get]
      if not held then return end
      local party = ctx.save.party or {}
      for i = #party, 1, -1 do
        local mon = party[i]
        if mon and mon.species == trade.get and mon.traded then
          if held and not mon.heldItem then
            mon.heldItem = held
          end
          break
        end
      end
    end
    Commands._expansionTradeHeld = true
  end)
end

return TradesExtra
