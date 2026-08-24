-- Resolve Gen2 ROM cache paths (gold / silver / crystal) for tools & tests.
-- Prefer the active GameVersion cachePrefix, then fall through other Gen2
-- editions so a machine with only Silver/Crystal imported still runs tests.

local CachePaths = {}

CachePaths.GEN2_IDS = { "gold", "silver", "crystal" }

local function homeRoot()
  local home = os.getenv("HOME") or ""
  return home .. "/.local/share/love/pokemon-love2d"
end

function CachePaths.root(versionId)
  versionId = versionId or "gold"
  return homeRoot() .. "/" .. versionId
end

function CachePaths.generated(versionId, name)
  return CachePaths.root(versionId) .. "/data/generated/" .. name
end

--- Ordered candidate paths for a generated Lua module (e.g. tilesets.lua).
-- preferred: optional version id to try first (defaults to GameVersion.get()).
function CachePaths.generatedCandidates(name, preferred)
  local order = {}
  local seen = {}
  local function push(id)
    if not id or seen[id] then return end
    seen[id] = true
    order[#order + 1] = id
  end
  if preferred then push(preferred) end
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if ok and GameVersion then
    if type(GameVersion.get) == "function" then
      local cur = GameVersion.get()
      if cur == "gold" or cur == "silver" or cur == "crystal" then
        push(cur)
      end
    end
    if type(GameVersion.cachePrefix) == "function" then
      local prefix = GameVersion.cachePrefix()
      if type(prefix) == "string" then
        local id = prefix:match("^([%w_]+)/")
        push(id)
      end
    end
  end
  for _, id in ipairs(CachePaths.GEN2_IDS) do
    push(id)
  end
  local paths = {}
  for _, id in ipairs(order) do
    paths[#paths + 1] = CachePaths.generated(id, name)
  end
  paths[#paths + 1] = "data/generated/" .. name
  return paths
end

--- dofile the first existing generated module; return table or nil.
function CachePaths.loadGenerated(name, preferred)
  for _, p in ipairs(CachePaths.generatedCandidates(name, preferred)) do
    local ok, val = pcall(dofile, p)
    if ok and type(val) == "table" then
      return val, p
    end
  end
  return nil, nil
end

return CachePaths
