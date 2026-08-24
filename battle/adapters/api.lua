-- Opaque adapter contract (documentation stub; no implementation).
-- Gen1 and Gen2 adapters share battle/core/* and differ only in host I/O
-- (see adapters/gen1.lua, adapters/gen2.lua). Router: adapters/init.lua.

--[[
  -- Mon / HP / status
  mon(battler) -> party mon table
  hp(battler), maxHp(battler), status(battler)
  types(battler), stages(battler), changeStages(battler, changes)
  applyStatus(battler, status, source, opts) -> bool
  clearStatus(battler) -> bool
  hasStatus(battler, ...) -> bool
  applyHpLoss(battler, amount), heal(battler, amount)
  say(text, ...), sayFail(), displayName(battler)

  -- Field / sides
  foeSide(battler), ownSide(battler), foeOf(battler)
  findHazard(side, id)
  fieldGet(key), fieldSet(key, value)
  setWeather(kind, turns, opts), tickWeather()

  -- Trap (Gen3 partial trap on both hosts)
  trap.get(battler) -> turns
  trap.moveName(battler) -> string|nil
  trap.set(battler, turns, moveId, moveName)
  trap.clear(battler)

  -- Screens / sub / confusion
  screen.get(side, key), screen.set(side, key, turns)
  hasSubstitute(battler), clearScreens(battler)
  substitute.blocks(effectKind, target)
  isConfused(battler), applyConfusion(battler, turns, source)

  -- Identity / items / abilities
  isGen2() -> bool
  heldItemOf(battler), speciesOf(battler), abilityOf(battler)
  isSeeded(battler), clearSeed(battler)
  lastMoveOf(battler), preparedMoves(battler), partyMons(battler)
  gen3PartialTrapActive() -> bool

  -- Faint / turn
  isFainted(battler) -> bool
  emitFaint(battler)
  isBattleDecided() -> bool
  activeBattlers() -> { battler, ... }
  onTurnEnded(battler)
  tickStatusBerry(battler)

  -- Re-entrancy
  invokeEffect(id, user, target, opts)
  useMove(user, moveId, target, opts)

  -- Residuals (wired to core/residuals.lua)
  residualRegister(phase, fn)
  rng() -> function

  Adapter routing:
    Adapters.forBattle(battle) -> gen1 or gen2 adapter (_host = "gen1"|"gen2")
    Adapters.hostFor(battle)   -> gen1 or gen2 module table

  Engine registry routing (adapters/register.lua):
    Gen1 -> move_effects.lua (ctx.run via EffectRegistry)
    Gen2 -> move_effects_gen2.lua (battle, attacker, defender, def, moveId)
]]

--[[
  move_effects registry (engine + KR):

  kind = "primary" | "secondary" | "full"   -- required by registries.md
  run(ctx|battle,...)                       -- primary / secondary body

  Full / damaging hooks (engine EffectRegistry / Gen2 install shims):
    gate(ctx) -> ok, failMsg
    chooseDamage(ctx) -> damage, info
    afterDamage(ctx)
    onMiss(ctx)
    callsMove(ctx) -> moveId|nil

  KR wraps core via coreRegister / coreRegisterFull (Gen1) and
  MoveEffectsGen2.register / registerHook (Gen2).
]]

return {}
