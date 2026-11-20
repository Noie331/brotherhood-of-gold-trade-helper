-- Loading item data for many items in batches, with progress. Pure Lua: the caller passes
-- isCached(id) and request(id), and calls Step on a timer.
local _, ns = ...
local Preload = {}
ns.Preload = Preload

function Preload.New(ids)
  return { queue = ids, nextIndex = 1, total = #ids }
end

-- Asks for up to `batch` more uncached items. Returns done (all asked and all loaded), loaded count.
function Preload.Step(st, isCached, request, batch)
  local asked = 0
  while st.nextIndex <= st.total and asked < batch do
    local id = st.queue[st.nextIndex]
    st.nextIndex = st.nextIndex + 1
    if not isCached(id) then request(id); asked = asked + 1 end
  end
  local loaded = 0
  for _, id in ipairs(st.queue) do if isCached(id) then loaded = loaded + 1 end end
  return st.nextIndex > st.total and loaded >= st.total, loaded
end
