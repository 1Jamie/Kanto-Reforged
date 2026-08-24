local Strings = require("src.core.Strings")
local H = require("mods.Kanto-Reforged.battle.core.effects._helpers")

local Weather = {}

local WEATHER = {
  EXP_WEATHER_SUNNY = { "SUNNY", "The sunlight\nturned harsh!" },
  EXP_WEATHER_RAINY = { "RAINY", "It started\nto rain!" },
  EXP_WEATHER_SANDSTORM = { "SANDSTORM", "A sandstorm\nkicked up!" },
  EXP_WEATHER_HAIL = { "HAIL", "It started\nto hail!" },
}

local function set(ctx, kind, text)
  -- Weather line first, then Forecast (FRLG ON_WEATHER). adapter:setWeather
  -- must not Forecast ahead of this say.
  ctx.adapter:setWeather(kind, 5, { skipForecast = true })
  ctx.adapter:say(Strings(text))
  local battle = ctx.adapter._battle
  local ok, Abilities = pcall(require, "mods.Kanto-Reforged.battle.abilities")
  if ok and Abilities and battle then
    Abilities.updateForecast(battle, battle.player)
    Abilities.updateForecast(battle, battle.enemy)
  end
end

function Weather.fromMove(ctx)
  local row = WEATHER[ctx.moveId]
  if not row then return H.sayFail(ctx) end
  set(ctx, row[1], row[2])
end

function Weather.sunny(ctx) set(ctx, "SUNNY", "The sunlight\nturned harsh!") end
function Weather.rainy(ctx) set(ctx, "RAINY", "It started\nto rain!") end
function Weather.sandstorm(ctx) set(ctx, "SANDSTORM", "A sandstorm\nkicked up!") end
function Weather.hail(ctx) set(ctx, "HAIL", "It started\nto hail!") end

return Weather
