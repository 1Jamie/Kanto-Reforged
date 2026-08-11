-- Register generated Sevii trainer classes (from sevii_import.py).

local SeviiTrainers = {}

function SeviiTrainers.register(mod)
  local ok, data = pcall(require, "mods.Kanto-Reforged.sevii.trainers_data")
  if not ok or not data or not data.classes then
    return
  end
  for classId, def in pairs(data.classes) do
    mod.content.trainers:register(classId, {
      id = def.id,
      name = def.name,
      basePic = def.basePic,
      baseMoney = def.baseMoney or 25,
      parties = def.parties or {},
    })
  end
end

-- Boss held-item overrides go here later (importer strips generics).
function SeviiTrainers.install(_mod)
end

return SeviiTrainers
