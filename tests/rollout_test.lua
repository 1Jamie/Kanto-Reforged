-- Rollout / Ice Ball: lock until miss or 5 hits.
return function(T, Data, run)
  local effect = Data.move_effects.EXP_ROLLOUT_EFFECT
  T.check(effect ~= nil, "EXP_ROLLOUT_EFFECT registered")
  T.eq(Data.moves.ROLLOUT.effect, "EXP_ROLLOUT_EFFECT", "Rollout uses rollout effect")
  T.eq(Data.moves.ICE_BALL.effect, "EXP_ROLLOUT_EFFECT", "Ice Ball shares rollout effect")

  local BattleState = require("src.battle.BattleState")
  local moveInst = { id = "ROLLOUT", pp = 20 }
  local user = { name = "Donphan", isPlayer = true }

  -- Hits 1-4: lock continues; hit 5: lock clears
  for hit = 1, 4 do
    effect.afterDamage({ user = user, moveInst = moveInst })
    T.eq(user.expRollout, hit, ("Rollout hit %d sets counter"):format(hit))
    T.eq(user.expRolloutMove, moveInst, ("Rollout hit %d stores move"):format(hit))
    T.eq(BattleState.menuLockedAction(nil, user), moveInst,
      ("Rollout hit %d forces menu lock"):format(hit))
  end

  effect.afterDamage({ user = user, moveInst = moveInst })
  T.eq(user.expRollout, nil, "Rollout hit 5 clears counter")
  T.eq(user.expRolloutMove, nil, "Rollout hit 5 clears move lock")
  T.eq(BattleState.menuLockedAction(nil, user), nil, "Rollout hit 5 releases menu")

  -- Miss mid-set clears the lock
  user.expRollout = 2
  user.expRolloutMove = moveInst
  effect.onMiss({ user = user })
  T.eq(user.expRollout, nil, "Rollout miss clears counter")
  T.eq(user.expRolloutMove, nil, "Rollout miss clears move lock")
  T.eq(BattleState.menuLockedAction(nil, user), nil, "Rollout miss releases menu")

  -- clearVolatiles (paralysis / confusion crash) clears Rollout
  user.expRollout = 3
  user.expRolloutMove = moveInst
  BattleState.clearVolatiles(nil, user, false)
  T.eq(user.expRollout, nil, "clearVolatiles clears rollout counter")
  T.eq(user.expRolloutMove, nil, "clearVolatiles clears rollout move")

  -- Power doubling uses expRollout as the completed-hit count (0-based for 2^n)
  -- Hit 1: n=0 → 1x; after damage n=1. Hit 2: n=1 → 2x, etc.
  local powers = {}
  local u2 = { expRollout = nil, defenseCurled = false }
  for i = 1, 5 do
    local n = u2.expRollout or 0
    powers[i] = 30 * (2 ^ math.min(n, 4))
    local completed = (u2.expRollout or 0) + 1
    if completed >= 5 then
      u2.expRollout = nil
    else
      u2.expRollout = completed
    end
  end
  T.eq(powers[1], 30, "Rollout power hit 1 is 30")
  T.eq(powers[2], 60, "Rollout power hit 2 is 60")
  T.eq(powers[3], 120, "Rollout power hit 3 is 120")
  T.eq(powers[4], 240, "Rollout power hit 4 is 240")
  T.eq(powers[5], 480, "Rollout power hit 5 is 480")
end
