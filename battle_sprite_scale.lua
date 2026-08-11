-- Cross-game battle pic scale math (Gen1 Red ↔ Gold).
--
-- Defaults differ by game even when pixel sizes match:
--   Gen1: front 1×, back 2×, backs are 32×32 → on-screen back 64 px
--   Gold: front 1×, back 1×, backs are 48×48 → on-screen back 48 px
--
-- KR / Hoenn art is Gen1-shaped (32×32 backs). On Gold that reads tiny
-- unless battleScaleBack compensates (32 × 1.5 = 48). Gold Johto art is
-- 48×48; on Gen1 that reads huge at 2× unless resampled or scaled
-- (48 × 4/3 ≈ 64).
--
-- Author pokemon_data in Gen1 absolute scales (what you tune while playing
-- Red). Convert at the Gen2 bridge — never copy raw battleScaleBack to Gold.

local BattleSpriteScale = {}

BattleSpriteScale.GEN1 = {
  frontDefault = 1,
  backDefault = 2,
  backPx = 32,
}

BattleSpriteScale.GOLD = {
  frontDefault = 1,
  backDefault = 1,
  backPx = 48,
}

local function clampScale(n)
  if n == nil then return nil end
  if n < 0.25 then return 0.25 end
  if n > 4.0 then return 4.0 end
  return n
end

--- Artistic size as a fraction of "normal" on-screen size (1 = normal).
-- Returns Gen1 absolute battleScaleFront, battleScaleBack.
function BattleSpriteScale.gen1FromFraction(frontFrac, backFrac)
  frontFrac = frontFrac or 1
  backFrac = backFrac or frontFrac
  local g = BattleSpriteScale.GEN1
  return clampScale(frontFrac * g.frontDefault),
         clampScale(backFrac * g.backDefault)
end

--- Same fraction → Gold absolute scales for a given source back pixel size.
-- backPx defaults to Gen1 (32): Hoenn / KR assets on Gold.
function BattleSpriteScale.goldFromFraction(frontFrac, backFrac, backPx)
  frontFrac = frontFrac or 1
  backFrac = backFrac or frontFrac
  backPx = backPx or BattleSpriteScale.GEN1.backPx
  local g = BattleSpriteScale.GOLD
  local front = frontFrac * g.frontDefault
  -- on-screen target = goldBackPx * backFrac; scale = target / sourcePx
  local back = (g.backPx / backPx) * backFrac * g.backDefault
  return clampScale(front), clampScale(back)
end

--- Invert Gen1 absolute scales into artistic fractions.
function BattleSpriteScale.fractionFromGen1(scaleFront, scaleBack)
  local g = BattleSpriteScale.GEN1
  local ff = (scaleFront or g.frontDefault) / g.frontDefault
  local bf = (scaleBack or g.backDefault) / g.backDefault
  return ff, bf
end

--- Gen1 absolute → Gold absolute for art whose back is `backPx` wide.
function BattleSpriteScale.gen1ToGold(scaleFront, scaleBack, backPx)
  local ff, bf = BattleSpriteScale.fractionFromGen1(scaleFront, scaleBack)
  return BattleSpriteScale.goldFromFraction(ff, bf, backPx)
end

--- Gold absolute → Gen1 absolute for art whose back is `backPx` wide.
function BattleSpriteScale.goldToGen1(scaleFront, scaleBack, backPx)
  backPx = backPx or BattleSpriteScale.GOLD.backPx
  local g1, g2 = BattleSpriteScale.GEN1, BattleSpriteScale.GOLD
  local ff = (scaleFront or g2.frontDefault) / g2.frontDefault
  -- Gold on-screen back = backPx * scaleBack; fraction vs Gold normal 48:
  local bf = (backPx * (scaleBack or g2.backDefault)) / g2.backPx
  return clampScale(ff * g1.frontDefault),
         clampScale(bf * g1.backDefault)
end

--- Gen1 on-screen match for a Gold-sized (48px) back: scale so 48×s ≈ 64×frac.
function BattleSpriteScale.gen1ScaleForGoldBack(backFrac, backPx)
  backFrac = backFrac or 1
  backPx = backPx or BattleSpriteScale.GOLD.backPx
  local g = BattleSpriteScale.GEN1
  return clampScale((g.backPx * g.backDefault / backPx) * backFrac)
end

--- Default Gold scales when drawing Gen1-sized (32px back) art with no overrides.
-- front stays default (nil/1); back → 1.5.
function BattleSpriteScale.defaultsForGen1ArtOnGold()
  return BattleSpriteScale.goldFromFraction(1, 1, BattleSpriteScale.GEN1.backPx)
end

--- Write Gold battleScale* onto a Gen2 register payload from a Gen1 KR record.
-- Always sets battleScaleBack when the art is Gen1-sized so Hoenn doesn't go tiny.
function BattleSpriteScale.applyGen1RecordToGold(out, gen1Record, backPx)
  backPx = backPx or BattleSpriteScale.GEN1.backPx
  local sf = gen1Record and gen1Record.battleScaleFront
  local sb = gen1Record and gen1Record.battleScaleBack
  local gf, gb = BattleSpriteScale.gen1ToGold(sf, sb, backPx)
  if sf ~= nil then
    out.battleScaleFront = gf
  end
  -- Back always compensated for 32→48 (even when Gen1 used the default 2×).
  out.battleScaleBack = gb
  return out
end

--- When Gen1 is showing a Gold-derived 48×48 back, set battleScaleBack via the
-- API so on-screen size matches Gen1 normals (and artistic fractions).
-- `record` may already hold Gen1 absolutes authored against 32×32 KR art;
-- those are converted to the equivalent scale for a 48px source.
function BattleSpriteScale.applyGoldBackOnGen1(record, backPx)
  backPx = backPx or BattleSpriteScale.GOLD.backPx
  local _, backFrac = BattleSpriteScale.fractionFromGen1(
    record.battleScaleFront, record.battleScaleBack)
  record.battleScaleBack = BattleSpriteScale.gen1ScaleForGoldBack(backFrac, backPx)
  return record
end

return BattleSpriteScale
