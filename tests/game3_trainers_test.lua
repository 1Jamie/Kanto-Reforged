-- Test suite for Gen 3 trainer roster overhauls and VS Seeker continuity.

local TrainersGame3 = require("mods.Kanto-Reforged.battle.trainers_game3")

local function runTests()
  print("--- Testing Gen 3 Expanded Trainer Rosters ---")

  local fakeMod = {
    log = { info = function() end }
  }

  local okT, Trainers = pcall(require, "src.core.game3.scripting.trainers")
  assert(okT and Trainers, "src.core.game3.scripting.trainers must exist")

  -- Set up mock ROM pack for trainers if pack is not loaded
  if not Trainers._pack then
    Trainers._pack = {
      trainers = {
        [414] = {
          scriptKey = "TRAINER_LEADER_BROCK",
          className = "LEADER",
          name = "BROCK",
          party = {
            { species = 74, level = 12 },
            { species = 95, level = 14 },
          }
        },
        [415] = {
          scriptKey = "TRAINER_LEADER_MISTY",
          className = "LEADER",
          name = "MISTY",
          party = {
            { species = 120, level = 18 },
            { species = 121, level = 21 },
          }
        },
        [412] = {
          scriptKey = "TRAINER_ELITE_FOUR_LANCE",
          className = "ELITE FOUR",
          name = "LANCE",
          party = {
            { species = 130, level = 56 },
            { species = 148, level = 54 },
            { species = 142, level = 58 },
            { species = 149, level = 60 },
          }
        },
        -- Youngster Ben stage 1 (ID 89) and stage 4 rematch (ID 499)
        [89] = {
          scriptKey = "TRAINER_YOUNGSTER_BEN",
          className = "YOUNGSTER",
          name = "BEN",
          lastLevel = 11,
          party = {
            { species = 19, level = 11 },
            { species = 16, level = 11 },
          }
        },
        [326] = {
          scriptKey = "TRAINER_RIVAL_OAKS_LAB_SQUIRTLE",
          className = "RIVAL",
          class = 81,
          name = "GREEN",
          lastLevel = 5,
          party = {
            { species = 7, level = 5 },
          },
        },
        [499] = {
          scriptKey = "TRAINER_YOUNGSTER_BEN_4",
          className = "YOUNGSTER",
          name = "BEN",
          lastLevel = 45,
          party = {
            { species = 20, level = 45 },
            { species = 18, level = 45 },
          }
        },
      }
    }
  end

  TrainersGame3.install(fakeMod)

  -- 1. Test Tier 1 Boss Overrides: Brock
  local brock = Trainers.get(414)
  assert(brock ~= nil, "Brock must be returned")
  assert(#brock.party == 4, "Brock party must have 4 Pokémon (Geodude, Sudowoodo, Aron, Onix)")
  assert(brock.party[2].species == 185 or tostring(brock.party[2].species):upper() == "SUDOWOODO", "Brock slot 2 should be Sudowoodo")
  assert(brock.party[3].species == 329 or brock.party[3].species == 304 or tostring(brock.party[3].species):upper() == "ARON", "Brock slot 3 should be Aron")

  -- 2. Test Tier 1 Boss Overrides: Misty
  local misty = Trainers.get(415)
  assert(misty ~= nil, "Misty must be returned")
  assert(#misty.party == 4, "Misty party must have 4 Pokémon (Staryu, Marill, Corphish, Starmie)")

  -- 3. Test Tier 1 Boss Overrides: Lance
  local lance = Trainers.get(412)
  assert(lance ~= nil, "Lance must be returned")
  assert(#lance.party == 6, "Lance party must have 6 Pokémon")

  -- Oak's lab rival stays a single starter. Later rival fights still gain a partner.
  local lab = Trainers.get(326)
  assert(lab ~= nil, "Oak's lab rival must be returned")
  assert(#lab.party == 1, "Oak's lab rival keeps a single starter")

  -- 4. Test Tier 2: Programmatic injection on Youngster Ben (ID 89)
  local ben1 = Trainers.get(89)
  assert(ben1 ~= nil, "Youngster Ben stage 1 must be returned")
  assert(#ben1.party == 3, "Youngster Ben stage 1 should have 3rd slot injected from YOUNGSTER pool")

  -- 5. Test VS Seeker Rematch Continuity on Youngster Ben Stage 4 (ID 499)
  local ben4 = Trainers.get(499)
  assert(ben4 ~= nil, "Youngster Ben stage 4 must be returned")
  assert(#ben4.party == 3, "Youngster Ben stage 4 should have 3rd slot injected")
  -- Injected slot on high level should be evolved form of the same species line
  assert(ben4.party[3].level == 45, "Injected slot should match trainer's level")

  print("✓ Gen 3 Expanded Trainer Rosters tests passed!")
end

runTests()
