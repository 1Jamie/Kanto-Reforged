-- Bake Gold Johto battle pics into save/mod-derived for Gen1 KR to reuse.
-- On a Gen1 boot Johto files are absent from the active cache → no-op.
-- On a Gold boot the player's imported pics are copied as-is (native Gold
-- sizes). Gen1 draw size is handled by battleScale* via battle_sprite_scale.lua
-- — never resample; nearest-neighbor wrecks 2bpp art.

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

-- Gold file basenames that differ from KR id lowercasing.
local GOLD_FRONT = {
  ho_oh = "hooh",
}

return function(ctx)
  local baked = 0
  for _, name in ipairs(JOHTO) do
    local goldFront = GOLD_FRONT[name] or name:gsub("_", "")
    local frontCandidates = {
      "battle/front/" .. goldFront .. ".png",
      "battle/front/" .. name .. ".png",
      "battle/front/" .. name:gsub("_", "") .. ".png",
    }
    local backCandidates = {
      "battle/back/" .. goldFront .. "_back.png",
      "battle/back/" .. name .. "_back.png",
      "battle/back/" .. name:gsub("_", "") .. "_back.png",
    }

    local frontRel
    for _, rel in ipairs(frontCandidates) do
      if ctx.exists(rel) then frontRel = rel break end
    end
    if frontRel then
      ctx.writeImage(ctx.readImage(frontRel), "johto/" .. name .. "_front.png")
      baked = baked + 1
    end

    local backRel
    for _, rel in ipairs(backCandidates) do
      if ctx.exists(rel) then backRel = rel break end
    end
    if backRel then
      -- Keep native Gold pixels (typically 48×48). Gen1 battleScaleBack
      -- (see battle_sprite_scale.applyGoldBackOnGen1) sizes them on screen.
      ctx.writeImage(ctx.readImage(backRel), "johto/" .. name .. "_back.png")
      baked = baked + 1
    end
  end
end
