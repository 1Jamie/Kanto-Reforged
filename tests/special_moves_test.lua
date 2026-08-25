-- Gates / variable power / doubles-disable smoke tests.
return function(T, Data, _run)
  local VP = require("mods.Kanto-Reforged.battle.variable_power")
  local Damaging = require("mods.Kanto-Reforged.battle.core.effects.damaging")
  local Calls = require("mods.Kanto-Reforged.battle.core.effects.calls")
  local DisabledMoves = require("mods.Kanto-Reforged.pokemon.disabled_moves")
  local MoveEffects = require("mods.Kanto-Reforged.battle.move_effects")

  T.eq(Data.moves.SUCKER_PUNCH.effect, "EXP_SUCKER_PUNCH_EFFECT", "Sucker Punch gated")
  T.eq(Data.moves.WAKE_UP_SLAP.effect, "EXP_WAKE_UP_SLAP_EFFECT", "Wake-Up Slap cures")
  T.eq(Data.moves.NATURAL_GIFT.effect, "EXP_NATURAL_GIFT_EFFECT", "Natural Gift effect")
  T.eq(Data.moves.FINAL_GAMBIT.effect, "EXP_FINAL_GAMBIT_EFFECT", "Final Gambit exists")
  T.eq(Data.moves.BEAT_UP.power, 10, "Beat Up base power for scaling")

  for _, id in ipairs({
    "FOLLOW_ME", "RAGE_POWDER", "ALLY_SWITCH", "WIDE_GUARD", "QUICK_GUARD",
    "AFTER_YOU", "QUASH", "SPOTLIGHT", "HELPING_HAND",
  }) do
    T.check(DisabledMoves.isDisabled(id), id .. " disabled in singles")
  end

  -- Sucker Punch: fails without a damaging pending foe move.
  do
    local ok, msg = Damaging.suckerPunchGate({
      target = { expPendingMove = "GROWL" },
      opts = { data = Data },
    })
    T.eq(ok, false, "Sucker Punch fails vs status pending")
    T.check(type(msg) == "string", "Sucker Punch fail message")

    ok = Damaging.suckerPunchGate({
      target = { expPendingMove = "TACKLE" },
      opts = { data = Data },
    })
    T.eq(ok, true, "Sucker Punch OK vs damaging pending")

    ok = Damaging.suckerPunchGate({
      target = { expActedThisTurn = true, expPendingMove = "TACKLE" },
      opts = { data = Data },
    })
    T.eq(ok, false, "Sucker Punch fails if foe already acted")
  end

  -- Me First copies pending, not lastMove.
  do
    local failed = false
    local picked = Calls.meFirst({
      user = {},
      target = { lastMove = "GROWL", expPendingMove = "THUNDERBOLT" },
      opts = { data = Data },
      adapter = { sayFail = function() failed = true end },
    })
    T.eq(picked, "THUNDERBOLT", "Me First copies pending move")
    T.check(not failed, "Me First does not fail on damaging pending")
  end

  -- Variable power sanity.
  T.eq(VP.punishmentPower(nil, { stages = { attack = 2, defense = 1 } }), 120,
    "Punishment scales with boosts")
  T.eq(VP.storedPower(nil, { stages = { attack = 1, speed = 1 } }), 60,
    "Stored Power scales with boosts")
  T.eq(VP.wringOutPower({ mon = { hp = 50, stats = { hp = 100 } } }), 60,
    "Wring Out scales with HP")
  T.eq(VP.trumpCardPower({ pp = 1 }), 200, "Trump Card max at 1 PP")
  local gift = VP.naturalGift("CHERI_BERRY")
  T.eq(gift and gift.type, "FIRE", "Natural Gift Cheri → Fire")
  T.eq(VP.beatUpPower({ game = { save = { party = {
    { hp = 10 }, { hp = 10, status = "SLP" }, { hp = 0 }, { hp = 5 },
  } } } }, { isPlayer = true }), 20, "Beat Up counts healthy unstatused")

  -- Pending helper.
  T.eq(MoveEffects.pendingMoveOf({ expPendingMove = "DIG" }), "DIG",
    "pendingMoveOf reads battler flag")
end
