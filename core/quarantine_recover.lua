-- Recover party/bag content the engine quarantined while this mod was
-- missing or failed to load. SaveData.validate's reclaim() always deposits
-- restored mons into the PC; that feels like "my team got boxed" after a
-- mod update. Run on save.loading (before validate) so known species/items
-- go back to party / bag first.

local Bag = require("src.inventory.Bag")

local QuarantineRecover = {}

local function known(map, id)
  return type(map) == "table" and id ~= nil and map[id] ~= nil
end

--- Pull orphaned mons/items that this merged Data knows back into party/bag.
--- Returns counts for logging: { mons, items }.
function QuarantineRecover.restore(save, data)
  if type(save) ~= "table" or type(data) ~= "table" then
    return { mons = 0, items = 0 }
  end
  local orphaned = save.orphaned
  if type(orphaned) ~= "table" then
    return { mons = 0, items = 0 }
  end

  local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
  local mod = SpeciesScope._mod
  local kantoLock = mod and SpeciesScope.mode(mod) == SpeciesScope.MODE_KANTO

  local restoredMons, restoredItems = 0, 0
  save.party = save.party or {}

  local mons = orphaned.mons
  if type(mons) == "table" then
    local keep = {}
    for _, mon in ipairs(mons) do
      if type(mon) == "table" and known(data.pokemon, mon.species)
          and #save.party < 6 then
        if kantoLock and SpeciesScope.isOutOfScopeMon(mod, mon, { data = data, save = save }) then
          -- Do not yank Gen3 into a kanto-locked party; leave orphaned.
          keep[#keep + 1] = mon
        else
          save.party[#save.party + 1] = mon
          restoredMons = restoredMons + 1
        end
      else
        keep[#keep + 1] = mon
      end
    end
    orphaned.mons = keep
  end

  local items = orphaned.items
  if type(items) == "table" then
    local keep = {}
    for _, entry in ipairs(items) do
      if type(entry) == "table" and known(data.items, entry.id)
          and entry.from ~= "pcItems"
          and Bag.add(save, entry.id, entry.count or 1, data) then
        restoredItems = restoredItems + 1
      else
        keep[#keep + 1] = entry
      end
    end
    orphaned.items = keep
  end

  if #(orphaned.mons or {}) == 0 and #(orphaned.items or {}) == 0 then
    save.orphaned = nil
  end

  return { mons = restoredMons, items = restoredItems }
end

function QuarantineRecover.install(mod)
  -- Before SaveData.validate quarantines / reclaim-to-PC.
  mod.events:on("save.loading", function(ev)
    local save = ev and ev.raw
    local game = mod.activeGame
    local data = (game and game.data) or require("src.core.Data")
    if not save or not data then return end
    local n = QuarantineRecover.restore(save, data)
    local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
    SpeciesScope.restoreDexFlags(SpeciesScope._mod or mod, save)
    SpeciesScope.snapshotDexFlags(SpeciesScope._mod or mod, save)
    if n.mons > 0 or n.items > 0 then
      mod.log:info(
        "Restored %d quarantined mon(s) to party, %d item stack(s) to bag",
        n.mons, n.items)
    end
  end)
end

return QuarantineRecover
