-- Gen1 Modern UI adapter: no-op without that mod; registers when stubbed.
return function(T, Data, run)
  local install = require("mods.Kanto-Reforged.ui.gen1_modern_ui_adapter")

  local bare = { id = "Kanto-Reforged", exports = {}, find = function() return nil end }
  local ok, err = install(bare)
  T.eq(ok, false, "adapter skips when Modern UI is absent")
  T.check(type(err) == "string" and err:find("not installed", 1, true),
    "skip reason mentions Modern UI missing")
  T.eq(bare.exports.gen1ModernUi, nil, "no contract published without Modern UI")

  local registered
  local fakeUi = {
    exports = {
      registerAdapter = function(opts)
        registered = opts
        return true
      end,
    },
  }
  local optValues = {}
  local withUi = {
    id = "Kanto-Reforged",
    exports = {},
    options = {
      get = function(_, key)
        if optValues[key] ~= nil then return optValues[key] end
        return false
      end,
    },
    find = function(id)
      if id == "gen1_modern_ui" then return fakeUi end
      return nil
    end,
  }

  ok = install(withUi)
  T.eq(ok, true, "adapter registers when Modern UI is present")
  T.check(registered ~= nil, "registerAdapter was called")
  T.eq(registered.owner, "Kanto-Reforged", "adapter owner is KR mod id")
  T.eq(withUi.exports.gen1ModernUi.apiVersion, 1, "contract apiVersion is 1")
  T.check(withUi.exports.gen1ModernUi.screens.UsefulBag, "UsefulBag screen published")
  T.check(withUi.exports.gen1ModernUi.screens.KantoSummary,
    "KantoSummary screen published")

  local bagScreen = withUi.exports.gen1ModernUi.screens.UsefulBag
  T.check(bagScreen.match({
    screenId = "BagMenu",
    items = {},
    __pocketIndex = 1,
    __pocketIds = { "items" },
    title = "ITEMS",
  }), "UsefulBag matches decorated BagMenu")
  T.check(not bagScreen.match({ screenId = "BagMenu", items = {} }),
    "UsefulBag rejects undecorated BagMenu")

  local sumScreen = withUi.exports.gen1ModernUi.screens.KantoSummary
  local mon = {
    species = "PIKACHU",
    nickname = "SPARKY",
    level = 25,
    hp = 40,
    exp = 1000,
    gender = "M",
    heldItem = "MAGNET",
    stats = { hp = 50, attack = 30, defense = 20, speed = 40, special = 30 },
    moves = { { id = "THUNDERSHOCK", pp = 30 } },
    ot = "RED",
    otId = 12345,
  }
  for page = 1, 3 do
    T.check(sumScreen.match({
      screenId = "SummaryMenu",
      _expMaxPage = 3,
      page = page,
      mon = mon,
    }), "summary adapter matches page " .. page)
  end
  T.check(not sumScreen.match({
    screenId = "SummaryMenu",
    page = 1,
    mon = mon,
  }), "summary adapter requires KR _expMaxPage")

  local fakeGame = { data = Data, save = { player = { name = "RED", id = 1 } } }
  local page1 = sumScreen.model(fakeGame, {
    screenId = "SummaryMenu", _expMaxPage = 3, page = 1, mon = mon,
  })
  T.eq(page1.title, "STATUS", "page 1 title")
  T.check(#page1.rows >= 8, "page 1 has status rows")
  local function rowLabel(rows, label)
    for _, r in ipairs(rows) do
      if r.label == label then return r end
    end
    return nil
  end
  T.check(rowLabel(page1.rows, "SPECIAL") ~= nil, "default page 1 shows SPECIAL")
  T.check(rowLabel(page1.rows, "SP.A") == nil, "default page 1 hides SP.A")

  optValues.split_special = true
  local page1Split = sumScreen.model(fakeGame, {
    screenId = "SummaryMenu", _expMaxPage = 3, page = 1, mon = mon,
  })
  T.check(rowLabel(page1Split.rows, "SPECIAL") == nil,
    "split on: page 1 hides SPECIAL")
  T.check(rowLabel(page1Split.rows, "SP.A") ~= nil, "split on: page 1 shows SP.A")
  T.check(rowLabel(page1Split.rows, "SP.D") ~= nil, "split on: page 1 shows SP.D")
  T.check(rowLabel(page1Split.rows, "ATK.") ~= nil, "split on: abbreviated ATK.")
  T.check(rowLabel(page1Split.rows, "DEF.") ~= nil, "split on: abbreviated DEF.")
  T.check(rowLabel(page1Split.rows, "SPD.") ~= nil, "split on: abbreviated SPD.")
  optValues.split_special = false

  local page2 = sumScreen.model(fakeGame, {
    screenId = "SummaryMenu", _expMaxPage = 3, page = 2, mon = mon,
  })
  T.eq(page2.title, "MOVES / EXP", "page 2 title")
  T.check(#page2.rows >= 3, "page 2 has exp/move rows")

  local page3 = sumScreen.model(fakeGame, {
    screenId = "SummaryMenu", _expMaxPage = 3, page = 3, mon = mon,
  })
  T.eq(page3.title, "ABILITY", "page 3 title")
  T.eq(#page3.rows, 4, "page 3 has four rows (gender/item/ability/effect)")
  local effectRow = page3.rows[4]
  T.eq(effectRow.label, "EFFECT", "ability blurb is one EFFECT row")
  T.check(type(effectRow.value) == "string" and effectRow.value:find(" ", 1, true),
    "effect text is joined into one value")
  T.check(not effectRow.value:find("\n", 1, true),
    "effect value has no hard line breaks")
end
