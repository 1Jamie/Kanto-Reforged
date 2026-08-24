-- Bake Gen2 Johto battle pics into save/mod-derived for Gen1 KR to reuse.
-- On a Gen1 boot Johto files are absent from the active cache → no-op.
-- On a Gen2 boot the player's imported pics are copied as-is (native
-- sizes). Gen1 draw size is handled by battleScale* via battle_sprite_scale.lua
-- — never resample; nearest-neighbor wrecks 2bpp art.
--
-- STATIC SPRITES ONLY. Crystal extracts animated front sheets under
-- battle/anim/ for MonAnim; Gold/Silver/Gen1 have no that system. Never
-- copy anim sheets, frame strips, or bitmask sidecars into mod-derived —
-- only battle/front/*.png and battle/back/*.png static pics.
--
-- Per-edition caches (gold/silver/crystal under sprites/<edition>/) are
-- owned by core/sprite_cache.lua on Gen2 boot — this recipe only keeps the
-- legacy johto/ bake for older Gen1 installs.

local JOHTO = {
  "chikorita", "bayleef", "meganium", "cyndaquil", "quilava", "typhlosion",
  "totodile", "croconaw", "feraligatr", "sentret", "furret", "hoothoot",
  "noctowl", "ledyba", "ledian", "spinarak", "ariados", "crobat",
  "chinchou", "lanturn", "pichu", "cleffa", "igglybuff", "togepi",
  "togetic", "natu", "xatu", "mareep", "flaaffy", "ampharos",
  "bellossom", "marill", "azumarill", "sudowoodo", "politoed", "hoppip",
  "skiploom", "jumpluff", "aipom", "sunkern", "sunflora", "yanma",
  "wooper", "quagsire", "espeon", "umbreon", "murkrow", "slowking",
  "misdreavus", "unown", "wobbuffet", "girafarig", "pineco", "forretress",
  "dunsparce", "gligar", "steelix", "snubbull", "granbull", "qwilfish",
  "scizor", "shuckle", "heracross", "sneasel", "teddiursa", "ursaring",
  "slugma", "magcargo", "swinub", "piloswine", "corsola", "remoraid",
  "octillery", "delibird", "mantine", "skarmory", "houndour", "houndoom",
  "kingdra", "phanpy", "donphan", "porygon2", "stantler", "smeargle",
  "tyrogue", "hitmontop", "smoochum", "elekid", "magby", "miltank",
  "blissey", "raikou", "entei", "suicune", "larvitar", "pupitar",
  "tyranitar", "lugia", "ho_oh", "celebi",
}

-- Gen2 file basenames that differ from KR id lowercasing.
local GEN2_FRONT = {
  ho_oh = "hooh",
}

-- Reject Crystal MonAnim sheets / frame strips (and anything else under anim/).
local function isStaticBattlePic(rel)
  if type(rel) ~= "string" then return false end
  if rel:find("/anim/", 1, true) or rel:find("^anim/", 1) then return false end
  if rel:find("_frames", 1, true) or rel:find("/frames/", 1, true) then
    return false
  end
  return rel:find("^battle/front/", 1) ~= nil
    or rel:find("^battle/back/", 1) ~= nil
end

local function firstExisting(ctx, candidates)
  for _, rel in ipairs(candidates) do
    if isStaticBattlePic(rel) and ctx.exists(rel) then
      return rel
    end
  end
  return nil
end

return function(ctx)
  local baked = 0
  for _, name in ipairs(JOHTO) do
    local frontBase = GEN2_FRONT[name] or name:gsub("_", "")
    local frontRel = firstExisting(ctx, {
      "battle/front/" .. frontBase .. ".png",
      "battle/front/" .. name .. ".png",
      "battle/front/" .. name:gsub("_", "") .. ".png",
    })
    if frontRel then
      ctx.writeImage(ctx.readImage(frontRel), "johto/" .. name .. "_front.png")
      baked = baked + 1
    end

    local backRel = firstExisting(ctx, {
      "battle/back/" .. frontBase .. "_back.png",
      "battle/back/" .. name .. "_back.png",
      "battle/back/" .. name:gsub("_", "") .. "_back.png",
    })
    if backRel then
      -- Keep native Gen2 pixels (typically 48×48). Gen1 battleScaleBack
      -- (see battle_sprite_scale.applyGoldBackOnGen1) sizes them on screen.
      ctx.writeImage(ctx.readImage(backRel), "johto/" .. name .. "_back.png")
      baked = baked + 1
    end
  end
end
