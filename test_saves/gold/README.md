# Kanto Rocket campaign test saves

Built from Gold `slot2.lua`. Campaign progress flags only.
**Does not set or clear `level_caps_on`.**

| File | Slot | Where | Flags |
|---|---|---|---|
| `01_pre_moon.lua` | `slot10` | `ROUTE_3` (50,4) | 3005 + 1 Kanto badges |
| `02_pre_tunnel.lua` | `slot11` | `ROCK_TUNNEL_1F_KR` (15,29) | 3005, 3001 + 3 Kanto badges |
| `03_pre_safari.lua` | `slot12` | `FUCHSIA_CITY` (18,5) | 3005, 3001, 3002, 3003 + 5 Kanto badges |
| `04_pre_silver.lua` | `slot13` | `MT_MOON_B2F_KR` (5,5) | 3005, 3001, 3002, 3003, 3004 + 8 Kanto badges |

Regenerate:
```
luajit mods/Kanto-Reforged/tools/make_campaign_test_saves.lua --install
```

Slots 10–13 are written only with `--install` (does not change active slot).
