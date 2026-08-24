-- Battle-start ability dialog must follow send-outs, not precede intro text.
return function(T, Data)
  local Abilities = require("mods.Kanto-Reforged.battle.abilities")

  -- Gen1 shape: act appends; sayNext inserts after the current act (nextInsert).
  do
    local queue = {
      { text = "TRAINER wants\nto fight!" },
      { text = "TRAINER sent\nout GYARADOS!" },
      { text = "Go! SQUIRTLE!" },
    }
    local battle = {
      data = Data,
      queue = queue,
      player = {
        isPlayer = true, name = "SQUIRTLE",
        mon = { species = "SQUIRTLE", hp = 20, nickname = "SQUIRTLE" },
      },
      enemy = {
        isPlayer = false, name = "Enemy GYARADOS",
        mon = { species = "GYARADOS", hp = 50, nickname = "GYARADOS" },
        stages = { attack = 0 },
      },
      act = function(self, fn)
        table.insert(self.queue, { fn = fn })
      end,
      sayNext = function(self, text)
        self.nextInsert = (self.nextInsert or 0) + 1
        table.insert(self.queue, self.nextInsert, { text = text })
      end,
    }
    if Data.pokemon.GYARADOS then
      Data.pokemon.GYARADOS.ability = "INTIMIDATE"
    end

    Abilities.scheduleBattleStartEntries(battle)
    T.eq(#battle.queue, 4, "Gen1 schedule appends one act after intro")
    T.check(battle.queue[4].fn, "Gen1 pending entry is a deferred act")
    T.eq(battle.queue[1].text, "TRAINER wants\nto fight!",
      "Gen1 intro text stays at queue front before act runs")

    -- Mirror BattleState:updateQueue for an fn row.
    local item = table.remove(battle.queue, 1)
    T.eq(item.text, "TRAINER wants\nto fight!", "first row is trainer intro")
    -- Drain intro until the act.
    while battle.queue[1] and not battle.queue[1].fn do
      table.remove(battle.queue, 1)
    end
    local act = table.remove(battle.queue, 1)
    battle.nextInsert = 0
    act.fn()
    T.check(#battle.queue >= 1, "Intimidate queued after act")
    local first = battle.queue[1] and battle.queue[1].text or ""
    T.check(first:find("INTIMIDATE") or first:find("Intimidate")
        or first:find("ATTACK"),
      "Gen1 ability dialog is first remaining message after send-outs")
  end

  -- Gen2 shape: flag + flush onto UI queue after intro rows.
  do
    local events = {}
    local battle = {
      data = Data,
      events = events,
      _krPendingEntryAbilities = nil,
      player = {
        species = "SQUIRTLE", hp = 20, nickname = "SQUIRTLE", name = "SQUIRTLE",
      },
      enemy = {
        species = "GYARADOS", hp = 50, nickname = "GYARADOS", name = "GYARADOS",
        stages = { attack = 0 },
      },
      emit = function(self, event)
        self.events[#self.events + 1] = event
      end,
      takeEvents = function(self)
        local out = self.events
        self.events = {}
        return out
      end,
    }
    -- Bare Gen2 mons: BattleCompat.mon returns the table itself when no .mon.
    local ui = {
      battle = battle,
      queue = {
        { kind = "message", text = "FOE wants to battle!" },
        { kind = "send", text = "FOE sent out GYARADOS!" },
        { kind = "sendout", text = "Go! SQUIRTLE!" },
      },
      pushAll = function(self, evs)
        for _, e in ipairs(evs or {}) do
          self.queue[#self.queue + 1] = e
        end
      end,
    }

    Abilities.scheduleBattleStartEntries(battle)
    T.check(battle._krPendingEntryAbilities,
      "Gen2 schedule marks pending (no act)")
    T.eq(#battle.events, 0, "Gen2 does not emit ability text before UI intro")

    Abilities.flushPendingBattleStartEntries(ui)
    T.check(not battle._krPendingEntryAbilities, "Gen2 pending cleared")
    T.eq(ui.queue[1].text, "FOE wants to battle!",
      "Gen2 intro stays ahead of ability messages")
    local last = ui.queue[#ui.queue]
    T.check(last and last.kind == "message",
      "Gen2 ability message appended after send-outs")
    T.check(tostring(last.text or ""):find("INTIMIDATE")
        or tostring(last.text or ""):find("ATTACK"),
      "Gen2 Intimidate text is last in intro+ability queue")
  end
end
