-- Held-item essentials / berry behavior (keeps Kanto-Reforged_test under
-- LuaJIT's 200-local limit).
return function(T, Data, HeldItems)
  local drains = 0
  local berryTarget = {
    mon = { heldItem = "BERRY", hp = 20, stats = { hp = 50 } },
    name = "Foe", isPlayer = false,
  }
  HeldItems.afterDamage({
    battle = {
      sayNext = function() end,
      drainNext = function() drains = drains + 1 end,
    },
    target = berryTarget,
  }, 10)
  T.eq(berryTarget.mon.hp, 30, "Berry heals 10 at half HP (detail)")
  T.eq(berryTarget.mon.heldItem, nil, "Berry consumed (detail)")
  T.eq(drains, 1, "Berry heal animates HP bar")

  -- Pinch berry via applyDamage: model heals, damage drain still pins to
  -- the post-hit HP so the bar dips then climbs (not a silent no-op).
  do
    local Pokemon = require("src.pokemon.Pokemon")
    local BattleState = require("src.battle.BattleState")
    local mon = Pokemon.new(Data, "BULBASAUR", 20)
    mon.heldItem = "BERRY"
    local max = mon.stats.hp
    mon.hp = math.floor(max / 2) + 3
    local game = {
      data = Data,
      save = {
        party = { mon }, player = { name = "RED" }, inventory = {},
        options = { battleStyle = "set" },
        pokedex = { seen = {}, owned = {} }, flags = {}, money = 0,
      },
      stack = { push = function() end, pop = function() end, top = function() end },
    }
    local b = BattleState.newWild(game, "RATTATA", 5)
    b.player.shownHP = mon.hp
    b.sayNext = function() end
    local start = mon.hp
    local dealt = b:applyDamage(b.player, 5)
    local damaged = start - dealt
    T.check(dealt == 5, "applyDamage dealt 5")
    T.eq(mon.hp, damaged + 10, "Berry healed +10 on the model after damage")
    T.eq(mon.heldItem, nil, "Berry consumed after applyDamage")
    -- First queued drain should pin at the post-hit HP.
    local drainRow
    for _, item in ipairs(b.queue) do
      if item.drain and item.stopAt ~= nil then drainRow = item break end
    end
    T.check(drainRow ~= nil, "damage drain queued with stopAt")
    T.eq(drainRow.stopAt, damaged, "damage drain stopAt is post-hit HP")
    b.draining = true
    b.player.drainFloor = drainRow.stopAt
    -- One long step burst should land on the pin, not skip to healed HP.
    for _ = 1, 500 do
      if not b:stepHPDrain() then break end
    end
    T.eq(math.floor(b.player.shownHP + 0.5), damaged,
      "bar drains to post-hit HP before heal rise")
    T.eq(mon.hp, damaged + 10, "model stays healed while bar shows the dip")
  end

  for _, row in ipairs({
    { "CHERI_BERRY", "PAR" },
    { "CHESTO_BERRY", "SLP" },
    { "PECHA_BERRY", "PSN" },
    { "RAWST_BERRY", "BRN" },
    { "ASPEAR_BERRY", "FRZ" },
  }) do
    local item, status = row[1], row[2]
    local tgt = {
      mon = { heldItem = item, status = status, hp = 30, stats = { hp = 50 } },
      name = "Foe", isPlayer = false,
    }
    if status == "PSN" then tgt.toxicCounter = 3 end
    if status == "SLP" then tgt.sleepTurns = 2 end
    T.check(HeldItems.tryStatusBerry({ sayNext = function() end }, tgt, status),
      item .. " cures " .. status)
    T.eq(tgt.mon.status, nil, item .. " clears status")
    T.eq(tgt.mon.heldItem, nil, item .. " is consumed")
    if status == "PSN" then
      T.eq(tgt.toxicCounter, nil, "Pecha clears toxicCounter")
    end
    if status == "SLP" then
      T.eq(tgt.sleepTurns, nil, "Chesto clears sleepTurns")
    end
  end

  -- Lum clears any major status + confusion in one bite.
  local lumTgt = {
    mon = { heldItem = "LUM_BERRY", status = "BRN", hp = 30, stats = { hp = 50 } },
    confusedTurns = 4, name = "Foe", isPlayer = false,
  }
  T.check(HeldItems.tryStatusBerry({ sayNext = function() end }, lumTgt, "BRN"),
    "Lum cures burn")
  T.eq(lumTgt.mon.status, nil, "Lum clears BRN")
  T.eq(lumTgt.confusedTurns, nil, "Lum also clears confusion")
  T.eq(lumTgt.mon.heldItem, nil, "Lum is consumed")

  local lumSleep = {
    mon = { heldItem = "LUM_BERRY", status = "SLP", hp = 30, stats = { hp = 50 } },
    sleepTurns = 3, name = "Foe", isPlayer = false,
  }
  T.check(HeldItems.tryStatusBerry({ sayNext = function() end }, lumSleep, "SLP"),
    "Lum cures sleep")
  T.eq(lumSleep.sleepTurns, nil, "Lum clears sleepTurns")

  local lumConfOnly = {
    mon = { heldItem = "LUM_BERRY", hp = 30, stats = { hp = 50 } },
    confusedTurns = 2, name = "Foe", isPlayer = false,
  }
  T.check(HeldItems.tryStatusBerry({ sayNext = function() end }, lumConfOnly, "confusion"),
    "Lum cures confusion alone")
  T.eq(lumConfOnly.confusedTurns, nil, "Lum clears confusion-only")
  T.eq(lumConfOnly.mon.heldItem, nil, "Lum consumed for confusion")

  local tickTgt = {
    mon = { heldItem = "CHERI_BERRY", status = "PAR", hp = 30, stats = { hp = 50 } },
    name = "Foe", isPlayer = false,
  }
  T.check(HeldItems.tickStatusBerry({ sayNext = function() end }, tickTgt),
    "tickStatusBerry cures existing PAR")
  T.eq(tickTgt.mon.status, nil, "tick clears PAR")
  T.eq(tickTgt.mon.heldItem, nil, "tick consumes Cheri")

  local confTgt = {
    mon = { heldItem = "PERSIM_BERRY", hp = 30, stats = { hp = 50 } },
    confusedTurns = 3, name = "Foe", isPlayer = false,
  }
  T.check(HeldItems.tryStatusBerry({ sayNext = function() end }, confTgt, "confusion"),
    "Persim cures confusion")
  T.eq(confTgt.confusedTurns, nil, "Persim clears confusedTurns")
  T.eq(confTgt.mon.heldItem, nil, "Persim is consumed")

  local confMiss = {
    mon = { heldItem = "PERSIM_BERRY", hp = 30, stats = { hp = 50 } },
    name = "Foe", isPlayer = false,
  }
  T.check(not HeldItems.tryStatusBerry({ sayNext = function() end }, confMiss, "confusion"),
    "Persim does nothing when not confused")
  T.eq(confMiss.mon.heldItem, "PERSIM_BERRY", "Persim kept when not confused")

  -- Bestow a Cheri onto an already-paralyzed foe → immediate cure.
  local bestowUser = {
    mon = { heldItem = "CHERI_BERRY" }, name = "User", isPlayer = true,
  }
  local bestowFoe = {
    mon = { heldItem = nil, status = "PAR", hp = 40, stats = { hp = 50 } },
    name = "Foe", isPlayer = false,
  }
  Data.move_effects.EXP_BESTOW_EFFECT.run({
    battle = { sayNext = function() end },
    user = bestowUser, target = bestowFoe,
  })
  T.eq(bestowFoe.mon.status, nil, "Bestow Cheri cures existing PAR")
  T.eq(bestowFoe.mon.heldItem, nil, "Bestow Cheri is consumed after cure")

  local iceUser = {
    mon = { heldItem = "NEVERMELTICE", hp = 50, stats = { hp = 50 } },
    name = "User", isPlayer = true,
  }
  T.eq(HeldItems.modifyDamage(100, { user = iceUser, move = { type = "ICE", power = 60 } }),
    110, "NeverMeltIce boosts effective Ice-type move")
  T.eq(HeldItems.modifyDamage(100, { user = iceUser, move = { type = "NORMAL", power = 60 } }),
    100, "NeverMeltIce ignores non-Ice move type")

  -- Focus Band miss path (90%).
  local missBattle = { rng = function() return 50 end, sayNext = function() end }
  local missTgt = { mon = { heldItem = "FOCUS_BAND", hp = 5, stats = { hp = 40 } },
                    name = "Foe", isPlayer = false }
  T.eq(HeldItems.focusBandClamp(missBattle, missTgt, 20), 20,
    "Focus Band can fail to save")

  -- Bag / pause-menu USE (later-gen style medicine)
  local ItemEffects = require("src.inventory.ItemEffects")
  T.check(ItemEffects.needsTarget("BERRY"), "Berry needs a party target")
  T.check(ItemEffects.needsTarget("CHERI_BERRY"), "Cheri needs a party target")
  T.check(ItemEffects.healsHP("BERRY"), "Berry counts as HP heal for bar fill")
  T.check(not ItemEffects.healsHP("CHERI_BERRY"), "Cheri is status-only (no HP bar)")

  local save = { player = { name = "RED" }, party = {} }
  local hurt = {
    species = "RATTATA", nickname = "Rat", hp = 10, stats = { hp = 40 },
  }
  local result, _, extra = ItemEffects.use(Data, save, "BERRY", hurt)
  T.eq(result, "consumed", "Bag BERRY heals and is consumed")
  T.eq(hurt.hp, 20, "Bag BERRY restores 10 HP")
  T.eq(extra and extra.healedFrom, 10, "Bag BERRY reports healedFrom")

  local full = { species = "RATTATA", hp = 40, stats = { hp = 40 } }
  T.eq(ItemEffects.use(Data, save, "BERRY", full), "failed",
    "Bag BERRY fails at full HP")

  local para = { species = "RATTATA", hp = 30, stats = { hp = 40 }, status = "PAR" }
  T.eq(ItemEffects.use(Data, save, "CHERI_BERRY", para), "consumed",
    "Bag Cheri cures PAR")
  T.eq(para.status, nil, "Bag Cheri clears PAR")

  local healthy = { species = "RATTATA", hp = 30, stats = { hp = 40 } }
  T.eq(ItemEffects.use(Data, save, "CHERI_BERRY", healthy), "failed",
    "Bag Cheri fails with no status")

  local burned = { species = "RATTATA", hp = 30, stats = { hp = 40 }, status = "BRN" }
  T.eq(ItemEffects.use(Data, save, "LUM_BERRY", burned), "consumed",
    "Bag Lum cures BRN")
  T.eq(burned.status, nil, "Bag Lum clears BRN")

  local confMon = { species = "RATTATA", hp = 30, stats = { hp = 40 } }
  local confBattle = {
    player = { mon = confMon, confusedTurns = 3, name = "Rat", isPlayer = true },
    enemy = { mon = { species = "PIDGEY", hp = 20, stats = { hp = 20 } } },
  }
  T.eq(ItemEffects.use(Data, save, "PERSIM_BERRY", confMon, confBattle), "consumed",
    "Bag Persim cures confusion in battle")
  T.eq(confBattle.player.confusedTurns, nil, "Bag Persim clears confusedTurns")

  T.eq(ItemEffects.use(Data, save, "PERSIM_BERRY", confMon, nil), "failed",
    "Bag Persim fails outside battle")

  -- Leftovers stay hold-only (Oak's line via vanilla fallthrough)
  T.check(not ItemEffects.needsTarget("LEFTOVERS"), "Leftovers is not a bag target item")
end
