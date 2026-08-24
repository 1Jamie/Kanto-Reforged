-- End-of-turn residual handlers registered into core/residuals.lua phases.
-- Host engines still own native status / Leech Seed / weather chip to avoid
-- double-ticking; KR owns Gen3 partial trap, EXP volatiles, held-item hooks,
-- and ability EOT that the engine does not.

local Strings = require("src.core.Strings")
local Residuals = require("mods.Kanto-Reforged.battle.core.residuals")
local PartialTrap = require("mods.Kanto-Reforged.battle.partial_trap")
local HeldItems = require("mods.Kanto-Reforged.items.held_items")

local Handlers = {}

function Handlers.registerAll()
  -- Field weather: KR Weather.tick (Gen1 full + Gen2 hail overlay).
  -- weather_chip / weather_tick are merged into this call (see PARITY.md).
  Residuals.register("weather_continue", function(ctx)
    ctx.adapter:tickWeather()
  end)
  Residuals.register("weather_chip", function(_ctx) end)
  Residuals.register("weather_tick", function(_ctx) end)

  -- Engine-owned on both hosts (Gen1 Status.residual / Gen2 tickStatus+tickSeed).
  Residuals.register("status_chip", function(_ctx) end)
  Residuals.register("leech_seed", function(_ctx) end)

  -- Gen3 partial trap: victim can act; trapper not locked; chip via residual_handlers.
  Residuals.register("partial_trap_chip", function(ctx)
    PartialTrap.applyResidualChip(ctx.adapter, ctx.target)
  end)

  Residuals.register("partial_trap_tick", function(_ctx)
    -- Free message is emitted inside partial_trap_chip when turns hit 0.
  end)

  Residuals.register("volatiles", function(ctx)
    local b = ctx.target
    if not b then return end
    b.expJustEntered = nil

    if b.expTauntedTurns and b.expTauntedTurns > 0 then
      b.expTauntedTurns = b.expTauntedTurns - 1
      if b.expTauntedTurns <= 0 then b.expTauntedTurns = nil end
    end

    if b.expYawnTurns and b.expYawnTurns > 0 then
      b.expYawnTurns = b.expYawnTurns - 1
      if b.expYawnTurns <= 0 then
        b.expYawnTurns = nil
        if ctx.adapter:hp(b) > 0 and not ctx.adapter:status(b) then
          ctx.adapter:applyStatus(b, "sleep", nil, { source = "YAWN" })
        end
      end
    end

    if b.expCursed and ctx.adapter:hp(b) > 0 then
      local dmg = math.max(1, math.floor(ctx.adapter:maxHp(b) / 4))
      ctx.adapter:applyHpLoss(b, dmg)
      ctx.adapter:say(Strings("%s is afflicted\nby the CURSE!",
        ctx.adapter:displayName(b)))
    end

    if b.expNightmare and ctx.adapter:hp(b) > 0 then
      if not ctx.adapter:hasStatus(b, "SLP", "sleep") then
        b.expNightmare = nil
      else
        local dmg = math.max(1, math.floor(ctx.adapter:maxHp(b) / 4))
        ctx.adapter:applyHpLoss(b, dmg)
        ctx.adapter:say(Strings("%s is locked\nin a NIGHTMARE!",
          ctx.adapter:displayName(b)))
      end
    end

    if ctx.adapter:hp(b) > 0 and (b.expIngrain or b.expAquaRing) then
      if (b.expHealBlockTurns or 0) <= 0 then
        local maxHp = ctx.adapter:maxHp(b)
        local cur = ctx.adapter:hp(b)
        if cur < maxHp then
          local heal = math.max(1, math.floor(maxHp / 16))
          ctx.adapter:heal(b, math.min(heal, maxHp - cur))
          ctx.adapter:say(Strings("%s restored a little\nHP!",
            ctx.adapter:displayName(b)))
        end
      end
    end

    if b.expEmbargoTurns and b.expEmbargoTurns > 0 then
      b.expEmbargoTurns = b.expEmbargoTurns - 1
      if b.expEmbargoTurns <= 0 then b.expEmbargoTurns = nil end
    end

    if b.expHealBlockTurns and b.expHealBlockTurns > 0 then
      b.expHealBlockTurns = b.expHealBlockTurns - 1
      if b.expHealBlockTurns <= 0 then b.expHealBlockTurns = nil end
    end

    if b.expUproarTurns and b.expUproarTurns > 0 then
      b.expUproarTurns = b.expUproarTurns - 1
      if b.expUproarTurns <= 0 then
        b.expUproarTurns = nil
        local other = ctx.adapter:foeOf(b)
        if not (other and other.expUproarTurns) then
          ctx.adapter:fieldSet("expUproarActive", nil)
        end
        ctx.adapter:say(Strings("%s calmed down!", ctx.adapter:displayName(b)))
      end
    end

    if b.expPerishTurns and ctx.adapter:hp(b) > 0 then
      b.expPerishTurns = b.expPerishTurns - 1
      ctx.adapter:say(Strings("%s's perish count\nfell to %d!",
        ctx.adapter:displayName(b), math.max(0, b.expPerishTurns)))
      if b.expPerishTurns <= 0 then
        local mon = ctx.adapter:mon(b)
        if mon then mon.hp = 0 end
        ctx.adapter:emitFaint(b)
      end
    end

    local side = ctx.adapter:ownSide(b)
    if side then
      if side.expSafeguardTurns and side.expSafeguardTurns > 0 then
        side.expSafeguardTurns = side.expSafeguardTurns - 1
        if side.expSafeguardTurns <= 0 then
          side.expSafeguardTurns = nil
          if ctx.adapter:isGen2() then
            ctx.adapter:say(Strings("%s is no longer\nprotected by SAFEGUARD!",
              ctx.adapter:displayName(b)))
          end
        end
      end
      if side.expLuckyChantTurns and side.expLuckyChantTurns > 0 then
        side.expLuckyChantTurns = side.expLuckyChantTurns - 1
        if side.expLuckyChantTurns <= 0 then side.expLuckyChantTurns = nil end
      end
      if side.expTailwindTurns and side.expTailwindTurns > 0 then
        side.expTailwindTurns = side.expTailwindTurns - 1
        if side.expTailwindTurns <= 0 then side.expTailwindTurns = nil end
      end
      if side.tokens then
        local kept = {}
        for _, tok in ipairs(side.tokens) do
          tok.turns = (tok.turns or 1) - 1
          if tok.turns <= 0 then
            if tok.id == "EXP_WISH" and ctx.adapter:hp(b) > 0 then
              local maxHp = ctx.adapter:maxHp(b)
              local cur = ctx.adapter:hp(b)
              if cur < maxHp then
                ctx.adapter:heal(b, math.min(tok.heal or math.floor(maxHp / 2), maxHp - cur))
                ctx.adapter:say(Strings("%s's WISH\ncame true!",
                  ctx.adapter:displayName(b)))
              end
            elseif tok.id == "EXP_FUTURE_SIGHT" and ctx.adapter:hp(b) > 0 then
              local label = tok.label or "FUTURE SIGHT"
              ctx.adapter:say(Strings("%s took the\n%s attack!",
                ctx.adapter:displayName(b), label))
              ctx.adapter:applyHpLoss(b, tok.damage or 1)
              if ctx.adapter:isFainted(b) then
                ctx.adapter:emitFaint(b)
              end
            elseif tok.onExpire then
              local battle = ctx.adapter._battle
              tok.onExpire(battle, side)
            end
          else
            kept[#kept + 1] = tok
          end
        end
        side.tokens = kept
      end
    end

    local trick = ctx.adapter:fieldGet("expTrickRoomTurns")
    if trick and trick > 0 and b == ctx.adapter:activeBattlers()[1] then
      trick = trick - 1
      if trick <= 0 then
        ctx.adapter:fieldSet("expTrickRoomTurns", nil)
        ctx.adapter:say(Strings("The twisted dimensions\nreturned to normal!"))
      else
        ctx.adapter:fieldSet("expTrickRoomTurns", trick)
      end
    end
  end)

  Residuals.register("held_items", function(ctx)
    local b = ctx.target
    if ctx.adapter:hp(b) <= 0 then return end
    local mon = ctx.adapter:mon(b)
    if not mon then return end
    local id = ctx.adapter:heldItemOf(b)
    local def = id and HeldItems.def(id)
    -- Gen2 Leftovers is handled by Battle:tickHeldItem; Gen1 needs KR.
    if def and def.holdEffect == "leftovers" and not ctx.adapter:isGen2() then
      local maxHp = ctx.adapter:maxHp(b)
      local cur = ctx.adapter:hp(b)
      if cur < maxHp then
        local heal = math.max(1, math.floor(maxHp / 16))
        ctx.adapter:heal(b, math.min(heal, maxHp - cur))
        ctx.adapter:say(Strings("%s restored a little\nHP using its LEFTOVERS!",
          ctx.adapter:displayName(b)))
      end
    end
    if b.expLifeOrbPending then
      b.expLifeOrbPending = nil
      if id == "LIFE_ORB" and ctx.adapter:hp(b) > 0 then
        local maxHp = ctx.adapter:maxHp(b)
        local recoil = math.max(1, math.floor(maxHp / 10))
        ctx.adapter:applyHpLoss(b, recoil)
        ctx.adapter:say(Strings("%s is hurt\nby its LIFE ORB!",
          ctx.adapter:displayName(b)))
      end
    end
  end)

  Residuals.register("abilities_eot", function(ctx)
    local b = ctx.target
    if ctx.adapter:hp(b) <= 0 then return end
    ctx.adapter:onTurnEnded(b)
    if ctx.adapter:status(b) and ctx.adapter:abilityOf(b) == "SHED_SKIN" then
      local rng = ctx.adapter:rng()
      local roll = type(rng) == "function" and rng(0, 99) or math.random(0, 99)
      if roll < 30 and ctx.adapter:clearStatus(b) then
        ctx.adapter:say(Strings("%s's SHED SKIN\ncured its status!",
          ctx.adapter:displayName(b)))
      end
    end
  end)
end

return Handlers
