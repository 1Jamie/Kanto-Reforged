-- Gen 1 battle EXP bar + a few engine-surface checks after pulling gen1recomp.
return function(T, Data, run)
  local BattleExpBar = require("mods.Kanto-Reforged.ui.battle_exp_bar")
  local BattleState = require("src.battle.BattleState")
  local Growth = require("src.pokemon.Growth")
  local Pokemon = require("src.pokemon.Pokemon")
  local Host = require("mods.Kanto-Reforged.core.host")

  T.eq(BattleExpBar.LENGTH_PX, 64, "EXP bar is 8 tiles / 64 px like Gen 2")
  T.eq(BattleExpBar.WIDE_PX, 208, "Widescreen EXP bar starts at tile 26 (208px)")
  T.eq(BattleExpBar.WIDE_LENGTH_PX, 64, "Widescreen EXP bar track length is 64px")
  T.check(Host.isGen1(), "suite is on Gen 1")
  T.check(BattleState._krExpBar, "EXP bar patched BattleState")
  T.check(BattleExpBar.OPTION ~= nil and BattleExpBar.OPTION.key == "battle_exp_bar",
          "EXP bar option schema registered")

  -- Engine surfaces KR wraps: HP drain still walks shownPx (GH #3).
  T.check(type(BattleState.stepHPDrain) == "function", "stepHPDrain still exists")
  T.check(type(BattleState.applyDamage) == "function", "applyDamage still exists")
  T.check(type(BattleState.awardExp) == "function", "awardExp still exists")
  T.check(type(BattleState.playerPartyView) == "function",
          "playerPartyView still exists")
  T.check(type(BattleState.drawHUDs) == "function", "drawHUDs still exists")

  local Status = require("src.battle.Status")
  T.check(Status.RECORDS and Status.RECORDS.FRZ
            and type(Status.RECORDS.FRZ.beforeMove) == "function",
          "FRZ.beforeMove still patchable")

  local def = Data.pokemon.BULBASAUR
  T.check(def and def.growthRate, "BULBASAUR has a growth curve")
  local lv, nextLv = 5, 6
  local base = Growth.expForLevel(def.growthRate, lv, Data.growth_rates)
  local nxt = Growth.expForLevel(def.growthRate, nextLv, Data.growth_rates)
  local span = nxt - base
  T.check(span > 0, "level 5→6 has an exp span")

  local mon = { species = "BULBASAUR", level = lv, exp = base }
  T.eq(BattleExpBar.expPixels(Data, mon, lv, base), 0, "empty at level floor")
  T.eq(BattleExpBar.expPixels(Data, mon, lv, nxt), 64, "full at next-level floor")
  local mid = base + math.floor(span / 2)
  local midPx = BattleExpBar.expPixels(Data, mon, lv, mid)
  T.check(midPx > 0 and midPx < 64, "mid-level is a partial fill")
  T.eq(BattleExpBar.expPixels(Data, { species = "BULBASAUR", level = 100, exp = 0 },
                              100, 0), 0, "level 100 bar stays empty")

  local function fakeBattle(startExp)
    local pmon = Pokemon.new(Data, "BULBASAUR", lv)
    pmon.exp = startExp
    pmon.level = lv
    return {
      data = Data,
      player = { mon = pmon, isPlayer = true },
    }
  end

  local battle = fakeBattle(base)
  BattleExpBar.latch(battle)
  T.eq(battle.krShownExp, 0, "latch at level floor is empty")
  T.eq(battle.krShownLevel, lv, "latch stores the battler's level")

  -- Applying exp must not snap the HUD; the crawl chases live exp.
  battle.player.mon.exp = mid
  T.eq(battle.krShownExp, 0, "shownExp stays latched after the model gains exp")
  local guard = 0
  while BattleExpBar.step(battle) and guard < 400 do
    guard = guard + 1
  end
  T.check(guard > 10, "crawl takes more than the sound delay")
  T.eq(battle.krShownExp, midPx, "crawl stops on the live fraction")
  T.eq(battle.krShownLevel, lv, "no level wrap when staying in-level")

  -- Level-up: fill to 64, then restart at 0 and chase the new level.
  battle = fakeBattle(base)
  BattleExpBar.latch(battle)
  battle.player.mon.exp = nxt + 1
  battle.player.mon.level = nextLv
  guard = 0
  local sawFull = false
  while BattleExpBar.step(battle) and guard < 800 do
    if battle.krShownExp == 64 then sawFull = true end
    guard = guard + 1
  end
  T.check(sawFull or battle.krShownLevel >= nextLv, "level-up fills the bar")
  T.eq(battle.krShownLevel, nextLv, "shownLevel catches the new level")
  T.eq(battle.krShownExp,
       BattleExpBar.expPixels(Data, battle.player.mon, nextLv, nxt + 1),
       "remainder after the wrap matches the new level")

  -- Option Toggle verification
  local mockMod = { options = { get = function(_, k) if k == "battle_exp_bar" then return false end end } }
  T.check(not BattleExpBar.enabled(mockMod), "option off: enabled() is false")
  T.check(not BattleExpBar.needsCrawl(battle), "option off: needsCrawl() is false")

  -- Real constructor latches via battle.started (Runtime is live after load).
  local pmon = Pokemon.new(Data, "BULBASAUR", 10)
  local game = {
    data = Data,
    save = {
      party = { pmon }, player = { name = "RED" }, inventory = {},
      options = { battleStyle = "set" },
      pokedex = { seen = {}, owned = {} }, flags = {}, money = 0,
    },
    stack = { push = function() end, pop = function() end, top = function() end },
  }
  local b = BattleState.newWild(game, "RATTATA", 5)
  T.check(b.krShownExp ~= nil, "newWild latches shownExp")
  T.eq(b.krShownLevel, pmon.level, "newWild latches shownLevel")
  T.eq(b.krShownExp, BattleExpBar.expPixels(Data, pmon, pmon.level, pmon.exp),
       "newWild shownExp matches the party mon")

  local ok, err = pcall(BattleExpBar.drawFill, b)
  T.check(ok, "drawFill is safe headless (" .. tostring(err) .. ")")

  -- "gained EXP" queues the crawl so the turn holds like Gold's AnimateExpBar.
  b.queue, b.nextInsert, b.krExpPending = {}, 0, 1
  b:sayNext("x gained\n1 EXP. Points!")
  T.eq(b.krExpPending, 0, "sayNext consumes a pending EXP crawl")
  T.check(b.queue[2] and b.queue[2].krExpDrain, "crawl is queued after the EXP text")

  -- After an HP drain, vanilla updateQueue dequeues the next row in the
  -- same call. The crawl marker must not become a blank text prompt.
  b.current, b.draining, b.krExpHold = nil, true, nil
  b.animPlaying, b.waitFrames, b.waitingSound, b.waitingUI = nil, nil, nil, nil
  b.queue, b.nextInsert = { { krExpDrain = true, wait = 1 } }, 0
  b:updateQueue()
  T.check(not b.current, "crawl row is not a text prompt after HP drain")
  T.check(b.krExpHold, "HP-drain fallthrough steals the crawl row")
end
