-- Host generation helpers for dual Gen1/Gen2 boot.
-- Prefer GameVersion (real Gold/Red boot). Tests that inject Loader
-- generation=2 without switching version should call Host.force(2) or
-- GameVersion.set("gold") before load.
local GameVersion = require("src.core.GameVersion")

local Host = {}
local forced = nil

function Host.force(generation)
  forced = generation
end

function Host.clearForce()
  forced = nil
end

function Host.generation()
  if forced == 1 or forced == 2 then
    return forced
  end
  return GameVersion.generation()
end

function Host.isGen1()
  return Host.generation() == 1
end

function Host.isGen2()
  return Host.generation() == 2
end

function Host.versionId()
  return GameVersion.get()
end

return Host
