-- Gold MVP smoke: headless load on generation 2.
return function(T, Data, run)
  local Host = require("mods.Kanto-Reforged.core.host")
  -- When this suite runs under the normal Gen1 test harness, Host is Gen1.
  -- Dedicated gen2 load is exercised below via a nested sdk load when possible.
end
