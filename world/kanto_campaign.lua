-- Gen2 Kanto Rocket campaign: Blue mission control, Moon/Tunnel/Safari chapters.
-- Layout stays in restored_dungeons_data.lua; this module overlays story content.

local Host = require("mods.Kanto-Reforged.core.host")
local Content = require("mods.Kanto-Reforged.world.kanto_campaign_content")

local Campaign = {}

Campaign.FLAGS = Content.FLAGS
Campaign.CONTENT = Content
Campaign._installed = false
Campaign._mod = nil

local PHONE_CONTACT = 2 -- PHONECONTACT_BIKESHOP spare slot
local PHONE_SPECIAL_ID = 6 -- SPECIALCALL_BIKESHOP
local SAVE_PHONE_TIER = "kr_kanto_blue_phone_tier"
local SAVE_SAFARI_ORIG_BLOCK = "kr_fuchsia_safari_orig_block"

local ow = Content.ow

local KANTO_BADGE_FLAGS = {
  "ENGINE_BOULDERBADGE",
  "ENGINE_CASCADEBADGE",
  "ENGINE_THUNDERBADGE",
  "ENGINE_RAINBOWBADGE",
  "ENGINE_SOULBADGE",
  "ENGINE_MARSHBADGE",
  "ENGINE_VOLCANOBADGE",
  "ENGINE_EARTHBADGE",
}

local function eventsOf(save)
  return save and save.events
end

function Campaign.hasEvent(save, id)
  local ev = eventsOf(save)
  if not ev or not id then return false end
  if type(ev.get) == "function" then
    return ev:get(id) and true or false
  end
  return ev[id] and true or false
end

function Campaign.setEvent(save, id, value)
  local ev = eventsOf(save)
  if not ev or not id then return end
  if type(ev.set) == "function" then
    ev:set(id, value ~= false)
  else
    ev[id] = value ~= false or nil
  end
end

local function engineFlag(save, name)
  if not save or not save.engineFlags then return false end
  if save.engineFlags[name] then return true end
  local FlagNames = package.loaded["src.core.gen2.FlagNames"]
  local id = FlagNames and FlagNames.engine and FlagNames.engine[name]
  return id and save.engineFlags[id] and true or false
end

function Campaign.kantoBadgeCount(save)
  local n = 0
  for _, f in ipairs(KANTO_BADGE_FLAGS) do
    if engineFlag(save, f) then n = n + 1 end
  end
  return n
end

function Campaign.isSafariUnlocked(save)
  if Campaign.hasEvent(save, Content.FLAGS.SAFARI_UNLOCKED) then return true end
  return Campaign.hasEvent(save, Content.FLAGS.MT_MOON_ROCKETS_CLEARED)
    and Campaign.hasEvent(save, Content.FLAGS.ROCK_TUNNEL_ROCKETS_CLEARED)
end

function Campaign.tryUnlockSafari(save)
  if not save then return false end
  if Campaign.isSafariUnlocked(save) then
    Campaign.setEvent(save, Content.FLAGS.SAFARI_UNLOCKED, true)
    return true
  end
  return false
end

local function upsertObject(mdef, neu)
  mdef.objects = mdef.objects or {}
  for i, obj in ipairs(mdef.objects) do
    if obj.name == neu.name then
      for k, v in pairs(neu) do
        obj[k] = v
      end
      return obj
    end
  end
  neu.index = neu.index or (#mdef.objects + 1)
  mdef.objects[#mdef.objects + 1] = neu
  return neu
end

local function bindTrainerScripts(obj, textTable)
  if not obj.trainer then return end
  local tr = obj.trainer
  local seenKey = tr.seenText or obj.text
  local winKey = tr.winText or (obj.text and (obj.text .. "_WIN"))
  local seen = (textTable and textTable[seenKey]) or seenKey or "Let's battle!"
  local win = (textTable and textTable[winKey]) or winKey or "Defeated!"
  tr.seenText = seen
  tr.winText = win
  local after = obj.afterScriptKey or {
    { op = "opentext" },
    { op = "rawtext", text = win },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "end" },
  }
  tr.scriptKey = after
  obj.scriptKey = nil
end

local function moonClearAfter()
  return {
    { op = "opentext" },
    { op = "rawtext", text = Content.TEXT.TEXT_MTMOONB2F_ROCKET4_WIN },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "setevent", event = Content.FLAGS.MT_MOON_ROCKETS_CLEARED },
    { op = "end" },
  }
end

local function tunnelClearAfter()
  return {
    { op = "opentext" },
    { op = "rawtext", text = Content.TEXT.TEXT_ROCKTUNNEL_ADMIN_WIN },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "setevent", event = Content.FLAGS.ROCK_TUNNEL_ROCKETS_CLEARED },
    { op = "end" },
  }
end

local function safariBossScript()
  local F = Content.FLAGS
  local boss = Content.ROSTERS.SAFARIZONE_BOSS
  return {
    { op = "checkevent", event = F.SAFARI_ROCKETS_CLEARED },
    {
      op = "iftrue",
      script = {
        { op = "faceplayer" },
        { op = "opentext" },
        { op = "rawtext", text = ow("...We're done here.\nThe preserve's yours.") },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "end" },
      },
    },
    { op = "faceplayer" },
    { op = "opentext" },
    { op = "rawtext", text = Content.TEXT.TEXT_SAFARIZONE_BOSS_SEEN },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "winlosstext", winText = Content.TEXT.TEXT_SAFARIZONE_BOSS_WIN, lossText = "Humph!" },
    { op = "loadtrainer", class = boss.classNum, member = boss.member },
    { op = "startbattle" },
    { op = "reloadmapafterbattle" },
    { op = "opentext" },
    { op = "rawtext", text = Content.TEXT.TEXT_SAFARIZONE_BOSS_AFTER },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "setevent", event = F.SAFARI_ROCKETS_CLEARED },
    { op = "end" },
  }
end

local function blueTunnelScript(save)
  local F = Content.FLAGS
  local moon = Campaign.hasEvent(save, F.MT_MOON_ROCKETS_CLEARED)
  local tunnel = Campaign.hasEvent(save, F.ROCK_TUNNEL_ROCKETS_CLEARED)
  if tunnel and moon then
    return {
      { op = "faceplayer" },
      { op = "opentext" },
      { op = "rawtext", text = ow([[
You cut both pipelines.
The SAFARI door in FUCHSIA should be open now.

Go take their industrial playground apart!
]]) },
      { op = "waitbutton" },
      { op = "closetext" },
      { op = "setevent", event = F.SAFARI_UNLOCKED },
      { op = "end" },
    }
  end
  if tunnel and not moon then
    return {
      { op = "faceplayer" },
      { op = "opentext" },
      { op = "rawtext", text = ow([[
Tunnel's clear -- good.
But MT. MOON's still running their racket.

Smash that checkpoint, then FUCHSIA opens.
]]) },
      { op = "waitbutton" },
      { op = "closetext" },
      { op = "end" },
    }
  end
  return {
    { op = "faceplayer" },
    { op = "opentext" },
    { op = "rawtext", text = ow([[
BLUE: Took you long enough.

TEAM ROCKET fled JOHTO and dug into soft KANTO.
ROCK TUNNEL's their supply line to FUCHSIA.

Clear the grunts -- especially their admin --
and we'll crack open the SAFARI takeover.
]]) },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "end" },
  }
end

function Campaign.mergeTexts(dungeonText)
  if not dungeonText then return end
  for k, v in pairs(Content.TEXT) do
    if v ~= nil then
      dungeonText[k] = v
    end
  end
end

function Campaign.registerRosters(rosterTable, byKey)
  if not rosterTable then return end
  for name, entry in pairs(Content.ROSTERS) do
    rosterTable[name] = entry
    if byKey then
      byKey[name] = entry
      if entry.classId and entry.member then
        byKey[string.format("%s_%s", entry.classId, entry.member)] = entry
      end
      if entry.classNum and entry.member then
        byKey[string.format("%s_%s", entry.classNum, entry.member)] = entry
      end
    end
  end
end

local function applyMapOverlays(Data, save)
  if not (Data and Data.maps) then return end
  local text = Content.TEXT

  -- Mt. Moon admin clear flag
  local moon = Data.maps.MT_MOON_B2F_KR
  if moon and moon.objects then
    for _, obj in ipairs(moon.objects) do
      if obj.name == "MTMOONB2F_ROCKET4" then
        obj.afterScriptKey = moonClearAfter()
        if obj.trainer then
          obj.trainer.scriptKey = obj.afterScriptKey
        end
      end
    end
  end

  for mapId, rows in pairs(Content.OVERLAYS) do
    local mdef = Data.maps[mapId]
    if mdef then
      for _, neu in ipairs(rows) do
        local copy = {}
        for k, v in pairs(neu) do copy[k] = v end
        if copy.name == "ROCKTUNNEL_ADMIN" then
          copy.afterScriptKey = tunnelClearAfter()
        end
        if copy.name == "ROCKTUNNEL_BLUE" then
          copy.scriptKey = blueTunnelScript(save)
          copy.trainer = nil
        end
        local obj = upsertObject(mdef, copy)
        if obj.trainer then
          local roster = Content.ROSTERS[obj.name]
          if roster then
            obj.trainer.roster = roster.roster
            obj.trainer.party = roster.roster
            obj.trainer.member = roster.member
            obj.trainer.class = roster.classNum
            obj.trainer.classId = roster.classId
            obj.trainer.className = roster.className
            obj.trainer.name = roster.name
            obj.trainer.baseMoney = roster.baseMoney
            obj.trainerParty = roster.member
            obj.trainerClass = roster.classId
          end
          bindTrainerScripts(obj, text)
        end
      end
    end
  end

  -- Safari gate workers / signs already use TEXT keys; mergeTexts covers them.
  -- Secret House → Rocket industry boss (not HM Surf).
  local secret = Data.maps.SAFARI_ZONE_SECRET_HOUSE_KR
  if secret and secret.objects then
    for _, obj in ipairs(secret.objects) do
      if obj.name == "SAFARIZONESECRETHOUSE_FISHING_GURU"
          or obj.name == "SAFARIZONE_BOSS" then
        obj.name = "SAFARIZONE_BOSS"
        obj.sprite = "SPRITE_ROCKET_GIRL"
        obj.sight = 0
        obj.movement = 6
        obj.range = "DOWN"
        obj.event = 3025
        obj.eventFlag = 3025
        obj.trainer = nil
        obj.itemball = nil
        obj.isCampaignOverlay = true
        obj.scriptKey = safariBossScript()
        local roster = Content.ROSTERS.SAFARIZONE_BOSS
        if roster then
          obj.trainerClass = roster.classId
          obj.trainerParty = roster.member
          obj.level = 68
        end
      end
    end
  end
end

-- Silver requires Safari clear + 8 Kanto badges.
function Campaign.buildSilverScript(seen, defeat, after)
  local F = Content.FLAGS
  local battle = {
    { op = "faceplayer" },
    { op = "opentext" },
    { op = "rawtext", text = seen },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "winlosstext", winText = defeat, lossText = "Humph! As expected." },
    { op = "loadtrainer", class = 42, member = 210 },
    { op = "startbattle" },
    { op = "dontrestartmapmusic" },
    { op = "reloadmapafterbattle" },
    { op = "playmusic", id = 32 },
    { op = "opentext" },
    { op = "rawtext", text = after },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "setevent", event = 793 },
    { op = "setevent", event = 1914 },
    { op = "setevent", event = 2998 },
    { op = "playmapmusic" },
    { op = "end" },
  }

  local script = {
    { op = "checkevent", event = 793 },
    {
      op = "iftrue",
      script = {
        { op = "faceplayer" },
        { op = "opentext" },
        { op = "rawtext", text = ow("...Don't get in my way.\nI'm still training to surpass RED.") },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "end" },
      },
    },
    { op = "checkevent", event = F.SAFARI_ROCKETS_CLEARED },
    {
      op = "iffalse",
      script = {
        { op = "faceplayer" },
        { op = "opentext" },
        { op = "rawtext", text = ow([[
...Not yet.

I'm watching TEAM ROCKET's mess in FUCHSIA.
Clear that first -- then we'll settle this.
]]) },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "end" },
      },
    },
  }
  for _, flag in ipairs(KANTO_BADGE_FLAGS) do
    script[#script + 1] = { op = "checkflag", flag = flag }
    script[#script + 1] = {
      op = "iffalse",
      script = {
        { op = "faceplayer" },
        { op = "opentext" },
        { op = "rawtext", text = ow([[
...You again?

Beat all eight KANTO GYM LEADERS first!
]]) },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "end" },
      },
    }
  end
  for _, cmd in ipairs(battle) do
    script[#script + 1] = cmd
  end
  return script
end

function Campaign.patchSilver(Data, dungeonText)
  local mdef = Data and Data.maps and Data.maps.MT_MOON_B2F_KR
  if not mdef then return end
  local seen = dungeonText and dungeonText.TEXT_MT_MOON_SILVER_RIVAL_SEEN
    or "…I've been waiting."
  local defeat = dungeonText and dungeonText.TEXT_MT_MOON_SILVER_RIVAL_DEFEAT
    or "Defeated!"
  local after = dungeonText and dungeonText.TEXT_MT_MOON_SILVER_RIVAL_AFTER
    or "…"
  local script = Campaign.buildSilverScript(seen, defeat, after)
  for _, obj in ipairs(mdef.objects or {}) do
    if obj.name == "MTMOONB2F_SILVER_RIVAL" or obj.isRivalEvent then
      obj.scriptKey = script
    end
  end
end

-- Fuchsia Safari door: closed until Moon+Tunnel clear.
local DOOR_BLOCK = 58
local CLOSED_BLOCK = 2 -- solid wall / roof tile stand-in

function Campaign.syncFuchsiaSafariDoor(fuchsia, save)
  if not fuchsia then return false end
  fuchsia.blocks = fuchsia.blocks or {}
  fuchsia.warps = fuchsia.warps or {}
  local width = fuchsia.width or 20
  local idx = 1 * width + 9 + 1

  local unlocked = Campaign.tryUnlockSafari(save)
  if unlocked then
    fuchsia.blocks[idx] = DOOR_BLOCK
    local foundA, foundB = false, false
    for _, w in ipairs(fuchsia.warps) do
      if w.x == 18 and w.y == 3 then
        w.destMap = "SAFARI_ZONE_GATE_KR"
        w.destWarp = 1
        foundA = true
      elseif w.x == 19 and w.y == 3 then
        w.destMap = "SAFARI_ZONE_GATE_KR"
        w.destWarp = 2
        foundB = true
      end
    end
    if not foundA then
      fuchsia.warps[#fuchsia.warps + 1] = { x = 18, y = 3, destMap = "SAFARI_ZONE_GATE_KR", destWarp = 1 }
    end
    if not foundB then
      fuchsia.warps[#fuchsia.warps + 1] = { x = 19, y = 3, destMap = "SAFARI_ZONE_GATE_KR", destWarp = 2 }
    end
  else
    local cur = fuchsia.blocks[idx]
    if cur and cur ~= DOOR_BLOCK then
      -- keep non-door original
    else
      fuchsia.blocks[idx] = CLOSED_BLOCK
    end
    local kept = {}
    for _, w in ipairs(fuchsia.warps) do
      local toSafari = (w.x == 18 or w.x == 19) and w.y == 3
        and type(w.destMap) == "string"
        and w.destMap:find("SAFARI")
      if not toSafari then
        kept[#kept + 1] = w
      end
    end
    fuchsia.warps = kept
  end
  return unlocked
end

local function bluePhoneScript(save)
  local badges = Campaign.kantoBadgeCount(save)
  local F = Content.FLAGS
  local lines
  if Campaign.hasEvent(save, F.SAFARI_ROCKETS_CLEARED) then
    lines = ow([[
BLUE: You wrecked their SAFARI racket!
KANTO owes you one.

If you're still hungry... MT. MOON's depths,
and then MT. SILVER.
]])
  elseif Campaign.isSafariUnlocked(save) then
    lines = ow([[
BLUE: Pipelines are down.
The SAFARI door in FUCHSIA is open --
go shut that industry down!
]])
  elseif Campaign.hasEvent(save, F.MT_MOON_ROCKETS_CLEARED)
      and not Campaign.hasEvent(save, F.ROCK_TUNNEL_ROCKETS_CLEARED) then
    lines = ow([[
BLUE: Moon checkpoint's smashed!
Next: ROCK TUNNEL. They're running stock
to FUCHSIA through that cave.
]])
  elseif badges >= 1 and not Campaign.hasEvent(save, F.MT_MOON_ROCKETS_CLEARED) then
    lines = ow(string.format([[
BLUE: HEY!!! Heard you just showed a KANTO LEADER how it's done!

TEAM ROCKET's shaking down MT. MOON --
toll racket while they train for FUCHSIA.
Go ruin their day. (%d badges in)
]], badges))
  else
    lines = ow([[
BLUE: Champ of JOHTO, huh?
KANTO's soft -- and Rockets noticed.

Keep collecting badges. I'll call when it's time to hit.
]])
  end
  return {
    { op = "specialphonecall", id = 0 },
    { op = "opentext" },
    { op = "rawtext", text = lines },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "end" },
  }
end

function Campaign.installPhone()
  local ok, Phone = pcall(require, "src.core.gen2.Phone")
  if not ok or not Phone then return false end
  Phone.NON_TRAINER_NAMES[PHONE_CONTACT] = "BLUE"
  Phone.CONTACTS[PHONE_CONTACT] = Phone.CONTACTS[PHONE_CONTACT] or {
    number = PHONE_CONTACT,
    map = nil,
    calleeTime = Phone.ANYTIME or 7,
    callerTime = 0,
  }
  Phone.CONTACTS[PHONE_CONTACT].callerTime = 0
  Phone.CONTACTS[PHONE_CONTACT].map = nil
  Phone.SPECIAL_CALLS[PHONE_SPECIAL_ID] = {
    name = "SPECIALCALL_KR_BLUE",
    condition = "outside",
    contact = PHONE_CONTACT,
    script = "KrBluePhoneScript",
    scriptKey = nil, -- filled when queueing
  }
  Phone.SPECIALCALL = Phone.SPECIALCALL or {}
  Phone.SPECIALCALL.SPECIALCALL_KR_BLUE = PHONE_SPECIAL_ID
  Campaign._Phone = Phone
  return true
end

function Campaign.queueBlueCall(save)
  local Phone = Campaign._Phone
  if not (Phone and save) then return false end
  Phone.addContact(save, PHONE_CONTACT)
  local entry = Phone.SPECIAL_CALLS[PHONE_SPECIAL_ID]
  if entry then
    entry.scriptKey = bluePhoneScript(save)
  end
  Phone.queueSpecialCall(save, PHONE_SPECIAL_ID)
  return true
end

function Campaign.maybeQueueBlueCall(save, mod)
  if not save then return end
  local badges = Campaign.kantoBadgeCount(save)
  local tier = 0
  if Campaign.hasEvent(save, Content.FLAGS.SAFARI_ROCKETS_CLEARED) then
    tier = 5
  elseif Campaign.isSafariUnlocked(save) then
    tier = 4
  elseif Campaign.hasEvent(save, Content.FLAGS.MT_MOON_ROCKETS_CLEARED) then
    tier = 3
  elseif badges >= 3 then
    tier = 2
  elseif badges >= 1 then
    tier = 1
  end
  local prev = 0
  if mod and mod.save and Host.saveGet then
    prev = Host.saveGet(mod.save, SAVE_PHONE_TIER, 0) or 0
  elseif save.krPhoneTier then
    prev = save.krPhoneTier
  end
  if tier > prev then
    if mod and mod.save and Host.saveSet then
      Host.saveSet(mod.save, SAVE_PHONE_TIER, tier)
    else
      save.krPhoneTier = tier
    end
    Campaign.queueBlueCall(save)
  end
end

function Campaign.installRoute22Blue(mod)
  local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
  local idx = HouseNpcs.nextFreeIndex(mod, "ROUTE_22", 1)
  HouseNpcs.appendNpc(mod, "ROUTE_22", {
    index = idx,
    sprite = "SPRITE_BLUE",
    x = 10, y = 10,
    facing = "DOWN",
    text = "TEXT_KR_ROUTE22_BLUE",
  }, "kanto_campaign")
  HouseNpcs.bindTalk(mod, "ROUTE_22", {
    TEXT_KR_ROUTE22_BLUE = function(ctx)
      local game = ctx.game
      local save = game and game.save
      Campaign.setEvent(save, Content.FLAGS.ROUTE22_BLUE_MET, true)
      Campaign.installPhone()
      local Phone = Campaign._Phone
      if Phone and save then Phone.addContact(save, PHONE_CONTACT) end
      HouseNpcs.pushText(game, ow([[
BLUE: JOHTO champ, huh?
KANTO got soft after I left the LEAGUE.

TEAM ROCKET noticed -- they're digging in.
Keep beating GYM LEADERS. I'll call you.

And keep your eyes on MT. MOON.
]]))
      return true
    end,
  })
end

function Campaign.applyToData(Data, dungeonText, rosterTable, byKey, save)
  Campaign.mergeTexts(dungeonText)
  Campaign.registerRosters(rosterTable, byKey)
  applyMapOverlays(Data, save)
  Campaign.patchSilver(Data, dungeonText)
  if Data and Data.maps and Data.maps.FUCHSIA_CITY then
    Campaign.syncFuchsiaSafariDoor(Data.maps.FUCHSIA_CITY, save)
  end
end

function Campaign.apply(mod)
  if not Host.isGen2() then return false end
  Campaign._mod = mod
  Campaign.installPhone()
  return true
end

function Campaign.install(mod)
  if Campaign._installed then return true end
  if not Host.isGen2() then return false end
  Campaign._mod = mod
  Campaign.installPhone()
  pcall(function() Campaign.installRoute22Blue(mod) end)

  -- Refresh Blue tunnel script + door when maps load.
  local World = package.loaded["src.world.gen2.World"]
  if not World then
    pcall(require, "src.world.gen2.World")
    World = package.loaded["src.world.gen2.World"]
  end
  if World and World.setMap and not World._krCampaignSetMap then
    World._krCampaignSetMap = true
    local orig = World.setMap
    function World:setMap(mapId, cx, cy, facing, opts)
      local save = self.save or (self.game and self.game.save)
      Campaign.tryUnlockSafari(save)
      Campaign.maybeQueueBlueCall(save, Campaign._mod)
      if self.maps then
        local moon = self.maps.MT_MOON_B2F_KR
        if moon then
          -- refresh Blue + admin scripts with live flags
          applyMapOverlays({ maps = {
            ROCK_TUNNEL_1F_KR = self.maps.ROCK_TUNNEL_1F_KR,
            ROCK_TUNNEL_B1F_KR = self.maps.ROCK_TUNNEL_B1F_KR,
            MT_MOON_B2F_KR = moon,
            SAFARI_ZONE_CENTER_KR = self.maps.SAFARI_ZONE_CENTER_KR,
            SAFARI_ZONE_EAST_KR = self.maps.SAFARI_ZONE_EAST_KR,
            SAFARI_ZONE_WEST_KR = self.maps.SAFARI_ZONE_WEST_KR,
            SAFARI_ZONE_NORTH_KR = self.maps.SAFARI_ZONE_NORTH_KR,
            SAFARI_ZONE_SECRET_HOUSE_KR = self.maps.SAFARI_ZONE_SECRET_HOUSE_KR,
          } }, save)
        end
        if self.maps.FUCHSIA_CITY then
          Campaign.syncFuchsiaSafariDoor(self.maps.FUCHSIA_CITY, save)
        end
      end
      local res = orig(self, mapId, cx, cy, facing, opts)
      if self.map and mapId == "FUCHSIA_CITY" then
        Campaign.syncFuchsiaSafariDoor(self.map, save)
        if self.map._warpAt == nil and self.map.warps then
          self.map._warpAt = {}
          for _, w in ipairs(self.map.warps) do
            if w.x and w.y then
              self.map._warpAt[w.y * 256 + w.x] = w
            end
          end
        end
      end
      return res
    end
  end

  Campaign._installed = true
  return true
end

return Campaign
