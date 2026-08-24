-- Regression tests for battle-audit critical fixes (tokens, toxic spikes, Gen2 trap).
return function(T)
  local Host = require("mods.Kanto-Reforged.core.host")
  local SwitchIn = require("mods.Kanto-Reforged.battle.switch_in")
  local CoreInstall = require("mods.Kanto-Reforged.battle.core.install")
  local Residuals = require("mods.Kanto-Reforged.battle.core.residuals")
  local PartialTrap = require("mods.Kanto-Reforged.battle.partial_trap")

  -- Toxic Spikes: two layers must badly poison on Gen1 (not plain PSN).
  do
    local applied
    local adapter = {
      isGen2 = function() return false end,
      isFainted = function() return false end,
      types = function() return { "NORMAL" } end,
      abilityOf = function() return nil end,
      maxHp = function() return 100 end,
      applyHpLoss = function() end,
      applyStatus = function(_, _b, status, _source, opts)
        applied = { status = status, opts = opts }
        return true
      end,
      status = function() return nil end,
      say = function() end,
      displayName = function(_, b) return b.name or "Mon" end,
    }
    local battler = { name = "Rattata", mon = { hp = 100, stats = { hp = 100 } } }
    SwitchIn.applyHazards(adapter, battler, {
      hazards = { { id = "TOXIC_SPIKES", layers = 2 } },
    })
    T.eq(applied and applied.status, "toxic", "2-layer toxic spikes use toxic status")
    T.check(applied and applied.opts and applied.opts.toxic,
      "2-layer toxic spikes pass toxic opts")
  end

  if Host.isGen1() then
    -- Engine tickTokens must not advance KR-owned Wish / Future Sight tokens.
    CoreInstall.install({ events = { on = function() end } })
    local BattleState = require("src.battle.BattleState")
    T.check(BattleState._krSideTokenOwnership, "Gen1 side-token ownership patch installed")

    local side = {
      tokens = {
        { id = "EXP_WISH", turns = 2, heal = 25 },
        { id = "OTHER", turns = 2 },
      },
    }
    local function tokenTurns(id)
      for _, tok in ipairs(side.tokens) do
        if tok.id == id then return tok.turns end
      end
    end
    local battle = { sides = { side }, field = { tokens = {} } }
    BattleState.tickTokens(battle)
    T.eq(tokenTurns("EXP_WISH"), 2, "engine tickTokens leaves EXP_WISH alone")
    T.eq(tokenTurns("OTHER"), 1, "engine tickTokens still ticks other tokens")

    -- KR volatiles: Wish heals only after the second residual tick.
    local mon = { hp = 50, stats = { hp = 100 } }
    local wishSide = { tokens = { { id = "EXP_WISH", turns = 2, heal = 25 } } }
    local healed = false
    local adapter = {
      _battle = {},
      tickWeather = function() end,
      hp = function(_, b) return b.mon.hp end,
      maxHp = function() return 100 end,
      isFainted = function(_, b) return (b.mon.hp or 0) <= 0 end,
      heal = function(_, b, n) b.mon.hp = b.mon.hp + n; healed = true end,
      say = function() end,
      displayName = function(_, b) return b.name end,
      ownSide = function() return wishSide end,
      activeBattlers = function() return { { mon = mon, name = "Mon" } } end,
      isBattleDecided = function() return false end,
      emitFaint = function() end,
      rng = function() return math.random end,
      fieldGet = function(_, key) return nil end,
      fieldSet = function() end,
      mon = function(_, b) return b.mon end,
      heldItemOf = function() return nil end,
      isGen2 = function() return false end,
      applyHpLoss = function(_, b, n) b.mon.hp = math.max(0, b.mon.hp - n) end,
      onTurnEnded = function() end,
      tickStatusBerry = function() end,
      status = function() return nil end,
      abilityOf = function() return nil end,
      clearStatus = function() return false end,
    }
    local battler = { mon = mon, name = "Mon" }
    Residuals.clear()
    require("mods.Kanto-Reforged.battle.core.residual_handlers").registerAll()
    Residuals.runTurn(adapter)
    T.check(not healed, "Wish does not heal on first KR residual tick")
    T.eq(wishSide.tokens[1].turns, 1, "Wish turns decrement once per KR tick")
    Residuals.runTurn(adapter)
    T.check(healed, "Wish heals on second KR residual tick")
    T.eq(#wishSide.tokens, 0, "Wish token removed after heal")
  end

  -- Gen2 install path wires partial trap (Host.force so install reaches Gold branch).
  do
    local prev = Host.generation()
    Host.force(2)
    PartialTrap.install({ events = { on = function() end } })
    local Battle = require("src.battle.gen2.Battle")
    T.check(Battle._krGen3PartialTrap, "Gen2 partial-trap hooks installed")
    if prev == 1 or prev == 2 then
      Host.force(prev)
    else
      Host.clearForce()
    end
  end
end
