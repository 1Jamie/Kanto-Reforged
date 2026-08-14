-- Vermilion City gangway sailor ↔ One Island ferry (Phase 0).
-- Same sailor who blocks the dock after the S.S. Anne leaves; a RAINBOW PASS
-- lets him send you to the Sevii Islands instead.

local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
local Strings = require("src.core.Strings")

local Ferry = {}
Ferry.OWNER = "sevii_ferry"

local function champ(game)
  return game.save.flags and game.save.flags.EVENT_BEAT_CHAMPION_RIVAL
end

local function hasPass(game, mod)
  if mod.save:get("sevii_unlocked", false) then return true end
  local inv = game.save.inventory or {}
  return inv.RAINBOW_PASS and inv.RAINBOW_PASS > 0
end

local function anneLeft(game)
  local Flags = require("src.script.Flags")
  return Flags.get(game.save, "EVENT_SS_ANNE_LEFT")
end

local function warpTo(mod, game, ow, destMap, x, y)
  if mod.world and mod.world.warpTo then
    mod.world:warpTo(destMap, x, y)
  elseif ow and ow.startWarpTo then
    ow:startWarpTo(destMap, x, y, "down")
  end
end

-- Offer / grant Rainbow Pass and sail. Returns true if the interaction was
-- fully handled (caller should not run vanilla sailor lines).
local function handleSeviiSailor(mod, game, ow, done)
  if not anneLeft(game) then
    return false
  end
  if not champ(game) then
    HouseNpcs.pushText(game, Strings(
      "The ship set sail."), done)
    return true
  end
  if not hasPass(game, mod) then
    if HouseNpcs.giveItem(game, "RAINBOW_PASS", 1) then
      mod.save:set("sevii_unlocked", true)
      HouseNpcs.pushText(game, Strings(
        "A RAINBOW PASS!\nThe SEVII ferry\vis ready."), done)
      return true
    end
    HouseNpcs.pushText(game, Strings("The ship set sail."), done)
    return true
  end
  HouseNpcs.ask(game, Strings("Sail to ONE\nISLAND?"), function(yes)
    if not yes then
      if done then done() end
      return
    end
    warpTo(mod, game, ow, "SEVII_ONE_ISLAND_HARBOR", 8, 6)
    if done then done() end
  end)
  return true
end

function Ferry.register(mod)
  mod.content.items:register("RAINBOW_PASS", {
    id = "RAINBOW_PASS",
    name = "RAINBOW PASS",
    price = 0,
    keyItem = true,
    tossable = false,
  })

  -- Gangway sailor (TEXT_VERMILIONCITY_SAILOR1) + onStep at the dock cell.
  mod.content.map_scripts:register("VERMILION_CITY", {
    priority = 10,
    talk = {
      TEXT_VERMILIONCITY_SAILOR1 = function(game, ow, npc, done)
        if handleSeviiSailor(mod, game, ow, done) then
          return
        end
        -- Ship still docked: ticket check (vanilla behavior).
        local t = game.data.text
        local ask = t._VermilionCitySailor1DoYouHaveATicketText
          or "Welcome to S.S.\nANNE!\fExcuse me, do you\nhave a ticket?"
        local hasTicket = (game.save.inventory.S_S_TICKET or 0) > 0
        if hasTicket then
          HouseNpcs.pushText(game,
            ask .. "\f" .. (t._VermilionCitySailor1FlashedTicketText
              or "{PLAYER} flashed\nthe S.S.TICKET!"), done)
        else
          HouseNpcs.pushText(game,
            ask .. "\f" .. (t._VermilionCitySailor1YouNeedATicketText
              or "You need a ticket\nto get aboard."), done)
        end
      end,
    },
    onStep = function(game, ow, x, y)
      if x ~= 18 or y ~= 30 then return false end
      if ow.player.facing ~= "down" then return false end
      if not anneLeft(game) then return false end
      -- After the Anne leaves: Rainbow Pass → sail offer; else bounce.
      if hasPass(game, mod) and champ(game) then
        handleSeviiSailor(mod, game, ow, function() end)
        return true
      end
      if champ(game) and not hasPass(game, mod) then
        handleSeviiSailor(mod, game, ow, function() end)
        return true
      end
      local t = game.data.text
      local TextBox = require("src.render.TextBox")
      game.stack:push(TextBox.new(game,
        t._VermilionCitySailor1ShipSetSailText or "The ship set sail.",
        function() ow:scriptMove(ow.player, "up", 1) end))
      return true
    end,
  })

  -- Stay on the dock if the player has a Rainbow Pass (Birth Island DNA
  -- sailor still lives here). Temporarily clear EVENT_SS_ANNE_LEFT so the
  -- vanilla onEnter kick does not fire, then restore it.
  mod.content.map_scripts:register("VERMILION_DOCK", {
    priority = 10,
    onEnter = function(game, ow)
      if not hasPass(game, mod) then return end
      local Flags = require("src.script.Flags")
      if Flags.get(game.save, "EVENT_SS_ANNE_LEFT") then
        Ferry._restoreAnneLeft = true
        Flags.clear(game.save, "EVENT_SS_ANNE_LEFT")
      end
    end,
  })
  mod.content.map_scripts:register("VERMILION_DOCK", {
    priority = -1,
    onEnter = function(game, ow)
      if not Ferry._restoreAnneLeft then return end
      Ferry._restoreAnneLeft = nil
      local Flags = require("src.script.Flags")
      Flags.set(game.save, "EVENT_SS_ANNE_LEFT")
    end,
  })

  mod.content.map_scripts:register("SEVII_ONE_ISLAND_HARBOR", {
    talk = {
      TEXT_SEVII_HARBOR_SAILOR = function(game, ow, npc, done)
        HouseNpcs.ask(game, Strings("Return to\nVERMILION?"), function(yes)
          if not yes then if done then done() end return end
          -- City side of the gangway sailor (not the dock — Anne is gone).
          warpTo(mod, game, ow, "VERMILION_CITY", 18, 29)
          if done then done() end
        end)
      end,
    },
  })
end

function Ferry.install(_mod)
end

return Ferry
