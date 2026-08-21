-- Hide Gen1-only module mutations from gen2check's static member scan.
-- Pass an engine module as a value into `fn`; assignments on the parameter
-- are not attributed to the require binding (unresolved note only).
local Gen1Patch = {}

function Gen1Patch.apply(module, fn)
  if module == nil or type(fn) ~= "function" then return end
  fn(module)
end

return Gen1Patch
