-- Quests tab: profession quests from the data file, with whether you have done them.
local _, ns = ...
local Quests = {}
ns.Quests = Quests

-- 'done', 'active' (in your quest log) or nil.
function Quests.Status(id)
  local Q = C_QuestLog
  if Q and Q.IsQuestFlaggedCompleted and Q.IsQuestFlaggedCompleted(id) then return 'done' end
  if Q and Q.GetLogIndexForQuestID and Q.GetLogIndexForQuestID(id) then return 'active' end
  return nil
end

local function faction() return ({ Alliance = 'A', Horde = 'H' })[UnitFactionGroup('player') or ''] end

-- Your professions that have quests in the data file.
function Quests.Professions()
  local data = ns.RecipeData
  return ns.View.QuestProfessions(ns.Recipes.TrainedNames(true), data and data.quests)
end

-- The Quests tab lines for one profession (View.QuestLines).
function Quests.Lines(profession)
  local data = ns.RecipeData or {}
  local f = faction()
  return ns.View.QuestLines(data.quests, profession, f, Quests.Status,
    function(q) return ns.RecipeSource.QuestText(q, data.npcs or {}, f) end)
end

-- Done or picked up a quest: redraw the tab.
local ev = CreateFrame('Frame')
for _, e in ipairs({ 'QUEST_TURNED_IN', 'QUEST_ACCEPTED', 'QUEST_REMOVED' }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript('OnEvent', function()
  if ns.Window and ns.Window.Selected and ns.Window.Selected() == ns.View.QUESTS_TAB and ns.Refresh then
    C_Timer.After(0.5, ns.Refresh) -- the completed flag lands a moment after the event
  end
end)
