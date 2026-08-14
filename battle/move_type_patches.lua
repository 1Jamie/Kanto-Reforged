-- Gen1/Gen2 move types → Gen3 (identical on Red and Gold).
-- Sprite / generate_pokemon_mod.py are NOT involved — only moves:patch.
--
-- Gen1→Gen2 type changes (unchanged through Gen3):
--   Bite, Gust, Karate Chop, Sand-Attack
-- Gen2 moves that PokeAPI/Gen6 retconned to Fairy stay Normal for Gen3
-- (species also avoid Fairy retcons).

local M = {}

-- id → Gen3 type id (as used in Data.moves / type_chart)
M.TYPES = {
  -- Gen1 ROM moves still typed Normal on Red; Gold ROM already Gen2-typed
  BITE = "DARK",
  GUST = "FLYING",
  KARATE_CHOP = "FIGHTING",
  SAND_ATTACK = "GROUND",

  -- Gen2 moves: Gen3 Normal, Gen6 Fairy (KR pokemon_data may register Fairy)
  CHARM = "NORMAL",
  SWEET_KISS = "NORMAL",
  MOONLIGHT = "NORMAL",
}

--- Apply type patches to whatever is already registered.
-- Runs on Red and Gold. Idempotent when the host already matches Gen3.
-- On Gold, also remaps Gen1 effect ids → Gen2 so taking ownership via
-- patch does not fail schema validation on headless / incomplete boots.
function M.apply(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  local Gen2Compat = Host.isGen2()
    and require("mods.Kanto-Reforged.core.gen2_compat")
    or nil

  local n = 0
  local checked = 0
  for id, typeId in pairs(M.TYPES) do
    local cur = mod.content.moves:get(id)
    if not cur then
      -- move absent on this host
    else
      checked = checked + 1
      local partial = {}
      if cur.type ~= typeId then
        partial.type = typeId
      end
      if Gen2Compat and cur.effect then
        local mapped = Gen2Compat.effectForMove(id, cur.effect)
        if mapped and mapped ~= cur.effect
            and mod.content.move_effects:get(mapped) then
          partial.effect = mapped
        elseif not mod.content.move_effects:get(cur.effect) then
          -- Seed a stub so ownership after patch still validates.
          Gen2Compat.seedMoveEffectStubs(mod, {
            moves = { [id] = { effect = cur.effect } },
          })
        end
      end
      if next(partial) then
        local ok, err = pcall(function()
          mod.content.moves:patch(id, partial)
        end)
        if ok then
          n = n + 1
        else
          mod.log:warn("move type patch %s failed: %s", id, tostring(err))
        end
      end
    end
  end
  if n > 0 then
    mod.log:info("Patched %d moves to Gen3 types (checked %d)", n, checked)
  else
    mod.log:info("Move types already Gen3 (%d checked)", checked)
  end
  return n
end

return M
