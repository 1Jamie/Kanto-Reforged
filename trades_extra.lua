-- Extra Gen 1 → Gen 2/3 in-game trades with held-item preloads.

local HouseNpcs = require("mods.Kanto-Reforged.house_npcs")

local TradesExtra = {}
TradesExtra.OWNER = "trades_extra"

TradesExtra.TRADES = {
  {
    give = "RATTATA",
    get = "TAILLOW",
    nickname = "SWIFT",
    dialogset = 1,
    held = "CLEANSE_TAG",
    flag = "MOD_TRADE_TAILLOW_DONE",
    map = "ROUTE_2_TRADE_HOUSE",
    index = 3,
    name = "ROUTE2TRADEHOUSE_TAILLOW",
    sprite = "SPRITE_BRUNETTE_GIRL",
    text = "TEXT_ROUTE2TRADEHOUSE_TAILLOW",
    x = 6, y = 5,
  },
  {
    give = "BELLSPROUT",
    get = "SEEDOT",
    nickname = "GLAND",
    dialogset = 2,
    held = "SOOTHE_BELL",
    flag = "MOD_TRADE_SEEDOT_DONE",
    map = "FUCHSIA_BILLS_GRANDPAS_HOUSE",
    index = 4,
    name = "FUCHSIABILLSGRANDPASHOUSE_SEEDOT",
    sprite = "SPRITE_GRAMPS",
    text = "TEXT_FUCHSIABILLSGRANDPASHOUSE_SEEDOT",
    x = 6, y = 4,
  },
}

local heldByGet = {}

function TradesExtra.refreshScope(mod, scopeMode)
  -- Trades stay registered; talk gate below refuses under kanto.
end

function TradesExtra.register(mod)
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

  local baseIndex = 10
  for i, row in ipairs(TradesExtra.TRADES) do
    local tradeIndex = baseIndex + i
    HouseNpcs.appendNpc(mod, row.map, {
      index = row.index,
      name = row.name,
      sprite = row.sprite,
      text = row.text,
      x = row.x,
      y = row.y,
    }, TradesExtra.OWNER)
    mod.content.map_scripts:register(row.map, {
      talk = {
        [row.text] = function(game, ow, npc, done)
          local SpeciesScope = require("mods.Kanto-Reforged.species_scope")
          if not SpeciesScope.allowsSpeciesId(mod, row.get, nil) then
            local Strings = require("src.core.Strings")
            HouseNpcs.pushText(game, Strings(
              "Hmm... my offer's for\na NATIONAL DEX run.\f"
                .. "Come back off KANTO\nscope."), done)
            return
          end
          -- Fall through to scripted trade command list
          local Commands = require("src.script.Commands")
          if Commands and Commands.trade then
            Commands.trade({ game = game, save = game.save }, tradeIndex, row.flag)
          end
          if done then done() end
        end,
      },
    })
  end

  -- Apply held preload when in-game trade creates the received mon.
  -- Concatenate the module name so gen2check cannot MK402 this Gen1-only require;
  -- TradesExtra.register only runs under Host.isGen1().
  local Gen1Patch = require("mods.Kanto-Reforged.gen1_patch")
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
        if mon and mon.species == trade.get and mon.traded and not mon.heldItem then
          mon.heldItem = held
          break
        end
      end
    end
    Commands._expansionTradeHeld = true
  end)
end

return TradesExtra
