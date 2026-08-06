-- Gen 3 Root / Claw fossils at Cinnabar Lab.

local HouseNpcs = require("mods.expansion_pack.house_npcs")
local Strings = require("src.core.Strings")

local FossilsGen3 = {}
FossilsGen3.OWNER = "fossils_gen3"

local FOSSIL_MAP = {
  ROOT_FOSSIL = "LILEEP",
  CLAW_FOSSIL = "ANORITH",
}

function FossilsGen3.register(mod)
  for id, name in pairs({
    ROOT_FOSSIL = "ROOT FOSSIL",
    CLAW_FOSSIL = "CLAW FOSSIL",
  }) do
    mod.content.items:register(id, {
      id = id, name = name, price = 0, keyItem = true, tossable = false,
    })
  end

  mod.content.field:patch("hiddenItems", {
    MT_MOON_B2F = { { x = 12, y = 8, item = "ROOT_FOSSIL" } },
    SEAFOAM_ISLANDS_1F = { { x = 8, y = 6, item = "CLAW_FOSSIL" } },
  })

  HouseNpcs.appendNpc(mod, "CINNABAR_LAB_FOSSIL_ROOM", {
    index = 3, name = "CINNABARLABFOSSILROOM_GEN3",
    sprite = "SPRITE_SCIENTIST", text = "TEXT_CINNABARLABFOSSILROOM_GEN3",
    x = 2, y = 4,
  }, FossilsGen3.OWNER)

  mod.content.map_scripts:register("CINNABAR_LAB_FOSSIL_ROOM", {
    talk = {
      TEXT_CINNABARLABFOSSILROOM_GEN3 = function(game, ow, npc, done)
        local save = game.save
        if save.flags and save.flags.MOD_LAB_GEN3_HANDING then
          local species = mod.save:get("lab_gen3_species", nil)
          if species then
            local Party = require("src.pokemon.Party")
            local Pokemon = require("src.pokemon.Pokemon")
            local mon = Pokemon.new(game.data, species, 30)
            if Party.add(save.party, mon) then
              save.flags.MOD_LAB_GEN3_HANDING = nil
              save.flags.MOD_LAB_GEN3_REVIVING = nil
              mod.save:set("lab_gen3_species", nil)
              HouseNpcs.pushText(game, Strings(
                "Here's your\n%s!", game.data.pokemon[species].name), done)
            else
              HouseNpcs.pushText(game, Strings(
                "Make room in your\nparty or boxes!"), done)
            end
          else
            if done then done() end
          end
          return
        end
        if save.flags and save.flags.MOD_LAB_GEN3_REVIVING then
          HouseNpcs.pushText(game, Strings(
            "Still working...\f"
              .. "Leave the island\nand come back."), done)
          return
        end
        local options = {}
        for fossil, species in pairs(FOSSIL_MAP) do
          if save.inventory and (save.inventory[fossil] or 0) > 0 then
            options[#options + 1] = {
              label = game.data.items[fossil] and game.data.items[fossil].name or fossil,
              value = { fossil = fossil, species = species },
            }
          end
        end
        if #options == 0 then
          HouseNpcs.pushText(game, Strings(
            "I revive ROOT and\nCLAW FOSSILS."), done)
          return
        end
        local ListMenu = require("src.ui.ListMenu")
        game.stack:push(ListMenu.new(game, Strings("Revive which?"), options, {
          onChoose = function(row, menu)
            menu:close()
            local Bag = require("src.inventory.Bag")
            Bag.remove(save, row.value.fossil, 1)
            save.flags = save.flags or {}
            save.flags.MOD_LAB_GEN3_REVIVING = true
            mod.save:set("lab_gen3_species", row.value.species)
            HouseNpcs.pushText(game, Strings(
              "Leave CINNABAR and\nreturn later!"), done)
          end,
        }))
      end,
    },
  })

  -- Clear reviving flag when entering Cinnabar Island (vanilla fossil pattern)
  mod.content.map_scripts:register("CINNABAR_ISLAND", {
    onEnter = function(game)
      if game.save.flags and game.save.flags.MOD_LAB_GEN3_REVIVING then
        game.save.flags.MOD_LAB_GEN3_REVIVING = nil
        game.save.flags.MOD_LAB_GEN3_HANDING = true
      end
    end,
  })
end

return FossilsGen3
