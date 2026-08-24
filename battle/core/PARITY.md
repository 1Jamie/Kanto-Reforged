# Battle Mechanics Parity Spec

Canonical Gen3 MODERN rules for both Gen1 and Gen2 hosts.

## Residual phase order

Phases run via `battle/core/residuals.lua` on `battle.turn_ended`.

| Phase | Owner | Notes |
|-------|-------|-------|
| 1. `weather_continue` | KR `Weather.tick` | Message + chip + duration (merged chip/tick) |
| 2. `weather_chip` | no-op | Merged into `weather_continue` |
| 3. `weather_tick` | no-op | Merged into `weather_continue` |
| 4. `status_chip` | **engine** | Gen1 `Status.residual` / Gen2 `tickStatus` |
| 5. `leech_seed` | **engine** | Gen1 residual / Gen2 `tickSeedAndCurse` |
| 6. `partial_trap_chip` | **KR** | Gen3 1/16 chip; free message when turns hit 0 |
| 7. `partial_trap_tick` | no-op | Free handled in chip phase |
| 8. `volatiles` | KR | Curse, Nightmare, Yawn→sleep, Ingrain, Perish, Embargo, Uproar, side timers |
| 9. `held_items` | KR (+ Gen2 engine Leftovers) | Life Orb recoil; Gen1 Leftovers |
| 10. `abilities_eot` | KR | Speed Boost, Shed Skin |

### Faint-interaction matrix

| Phase | Fainted battler | Notes |
|-------|-----------------|-------|
| weather_continue | skip remaining for that battler after chip | via Weather.tick |
| status_chip | engine | |
| leech_seed | engine | |
| partial_trap_chip | skip remaining | emitFaint before next phase |
| volatiles | skip | no Yawn sleep on corpse |
| held_items | skip | no Leftovers on 0 HP |
| abilities_eot | skip | |

Battle-wide halt when `adapter:isBattleDecided()`.

## Effect parity

- **Gen1-only (18):** Protect, Encore, Endure, Belly Drum, Fury Cutter, Future Sight, Mirror Coat, Perish Song, Rollout, Spite, Variable Power, weather moves (Gen2 remaps many to natives), Attract, Baton Pass, Curse.
- **Gen2-only (1):** Wake-Up Slap.
- **Semantic mismatches:** see `parity.lua` `SEMANTIC_MISMATCH` table.

## Re-entrancy inventory

Nested synchronous effects must use `adapter:invokeEffect` / `adapter:useMove` with the context stack (`effect_ctx.push`/`pop`):

- Sleep Talk, Snore, Assist, Copycat, Metronome, Nature Power, Me First
- Magic Coat, Snatch (bounce-back)
- Synchronize, Rough Skin, Cute Charm (mid-resolution status)

## Adapter contract

Core effects must call adapter methods only (see `battle/adapters/api.lua`).
Do not touch Gen1 `BattleState` / Gen2 `Battle` fields from `battle/core/effects/*`.

Host bridges allowed only in:

- `battle/adapters/_base.lua`, `battle/adapters/gen1.lua`, `battle/adapters/gen2.lua`
- `battle/adapters/register.lua` (engine move_effects registry per host)
- `battle/battle_compat.lua`
- `battle/partial_trap.lua` (install patches)
- Gen1/Gen2 `move_effects*.lua` install shims

## Weather + Forecast dialog (FRLG)

Weather-setting move (Sunny Day / Rain Dance / Sandstorm / Hail):

1. "{Name} used SUNNY DAY!"
2. Apply weather
3. "The sunlight turned harsh!"
4. Forecast: "{Castform} transformed!" and form sprite

Not during the next attack, and not after the end-of-turn continue line.

End of turn (after both Pokémon acted), pret/pokefirered `HandleEndTurn_Weather`:

1. Continue or end the weather ("The sunlight is strong." / faded)
2. Sandstorm / hail chip
3. Status / Leech Seed / etc.
4. Forecast only if weather *changed* (expiry reverts Castform after the fade line)

Gold `Battle:tickWeather` still owns sun/rain/sand continue+chip. KR overlays hail and Forecast *inside that wrap* (before `takeEvents`). Do not Forecast from `battle.turn_ended` on Gen2 — that event fires after the queue is drained, so "transformed!" would appear at the start of the next turn. Weather *moves* Forecast from a wrap on `MOVE_EFFECT_RECORDS` / merged `gen2MoveEffects` (after StartSun), not from the live `MOVE_EFFECTS` table alone (records are snapshotted at load) and not from `move_used` (Gold emits that before StartSun).

## Crit stages (Gen3)

| Source | Stage delta |
|--------|-------------|
| Base | 0 |
| High-crit move | +1 |
| Focus Energy | +2 |
| Scope Lens | +1 |
| Lucky Punch (Chansey) | +2 |
| Stick / Leek (Farfetch'd) | +2 |
| Cap | 4 |

## Partial trap (Gen3)

Both hosts: victim can act; trapper not locked; 1/16 max-HP chip; 2–5 turns; Ghost immune; ends on switch / Rapid Spin / turn count. Gen2 keeps a `wrapCount=1` shadow for canSwitch/flee only; `tickWrap` chip is suppressed.

## Integration surface

See `parity.lua` `INTEGRATION.events` and `INTEGRATION.hooks`.

Gen1Patch battle sites: `battle_compat`, `weather`, `partial_trap`, `move_effects_gen2`, `castform_fx`, `trainer_ai`.
