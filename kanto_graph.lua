-- Kanto outdoor adjacency + valid roamer grass maps.

local KantoGraph = {}

-- Built at boot from Data.maps[].connections (outdoor edges).
KantoGraph.neighbors = {}
KantoGraph.grassRoutes = {}

local GRASS_CANDIDATES = {
  "ROUTE_1", "ROUTE_2", "ROUTE_3", "ROUTE_4", "ROUTE_5", "ROUTE_6",
  "ROUTE_7", "ROUTE_8", "ROUTE_9", "ROUTE_10", "ROUTE_11", "ROUTE_12",
  "ROUTE_13", "ROUTE_14", "ROUTE_15", "ROUTE_16", "ROUTE_17", "ROUTE_18",
  "ROUTE_21", "ROUTE_22", "ROUTE_24", "ROUTE_25",
}

function KantoGraph.build(data)
  KantoGraph.neighbors = {}
  KantoGraph.grassRoutes = {}
  if not data or not data.maps then return end

  local function link(a, b)
    if not a or not b then return end
    KantoGraph.neighbors[a] = KantoGraph.neighbors[a] or {}
    KantoGraph.neighbors[b] = KantoGraph.neighbors[b] or {}
    local function add(from, to)
      for _, x in ipairs(KantoGraph.neighbors[from]) do
        if x == to then return end
      end
      KantoGraph.neighbors[from][#KantoGraph.neighbors[from] + 1] = to
    end
    add(a, b)
    add(b, a)
  end

  for id, map in pairs(data.maps) do
    local cons = map.connections
    if cons then
      for _, dir in ipairs({ "north", "south", "east", "west" }) do
        local c = cons[dir]
        if c and c.map then link(id, c.map) end
      end
    end
  end

  for _, id in ipairs(GRASS_CANDIDATES) do
    local enc = data.encounters and data.encounters[id]
    if enc and enc.grass and enc.grass.slots and #enc.grass.slots > 0 then
      KantoGraph.grassRoutes[#KantoGraph.grassRoutes + 1] = id
    elseif data.maps[id] then
      -- Still allow as roamer maps even if mixer emptied grass
      KantoGraph.grassRoutes[#KantoGraph.grassRoutes + 1] = id
    end
  end
end

function KantoGraph.isAdjacent(a, b)
  local list = KantoGraph.neighbors[a]
  if not list then return false end
  for _, n in ipairs(list) do
    if n == b then return true end
  end
  return false
end

function KantoGraph.randomGrass(rng)
  rng = rng or love.math.random
  local routes = KantoGraph.grassRoutes
  if #routes == 0 then return "ROUTE_1" end
  return routes[rng(1, #routes)]
end

function KantoGraph.randomNeighbor(mapId, rng)
  rng = rng or love.math.random
  local list = KantoGraph.neighbors[mapId]
  if not list or #list == 0 then
    return KantoGraph.randomGrass(rng)
  end
  -- Prefer grass neighbors when possible
  local grass = {}
  for _, n in ipairs(list) do
    for _, g in ipairs(KantoGraph.grassRoutes) do
      if g == n then grass[#grass + 1] = n break end
    end
  end
  local pool = #grass > 0 and grass or list
  return pool[rng(1, #pool)]
end

function KantoGraph.displayName(mapId)
  if not mapId then return "?" end
  return mapId:gsub("_", " ")
end

return KantoGraph
