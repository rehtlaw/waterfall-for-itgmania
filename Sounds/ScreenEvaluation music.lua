local passed = false -- We want to know if at least one player passed

local players = GAMESTATE:GetHumanPlayers()
for player in ivalues(players) do
	local pn = ToEnumShortString(player) 
	
	--Global Variable set in BGAnimations\ScreenGameplay underlay\PerPlayer\FailTracker.lua
	if not GAMESTATE:Env()["Fail" .. pn] then passed = true end 

end

-- Plays a random sound based on pass/fail
-- (theme dir)/Sounds/Evaluation Pass/
-- (theme dir)/Sounds/Evaluation Fail/
-- Name your files in numerical order 1.ogg / 2.ogg / etc
-- Currently does not support looping
-- findFiles function in Scripts/Z-NewFunctions.lua
local dir = THEME:GetCurrentThemeDirectory() .. "Sounds/Evaluation Fail/"

if passed then
	dir = THEME:GetCurrentThemeDirectory() .. "Sounds/Evaluation Pass/"
end

local evaluation_sounds = findFiles(dir)
if #evaluation_sounds > 0 then
	return evaluation_sounds[math.random(#evaluation_sounds)]
end

