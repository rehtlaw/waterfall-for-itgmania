local player = ...
local pn = ToEnumShortString(player)
local mods = SL[pn].ActiveModifiers
-- if the conditions aren't right, don't bother
if mods.DataVisualizations ~= "Step Statistics"
or GAMESTATE:GetCurrentStyle():GetName() ~= "single"
or (PREFSMAN:GetPreference("Center1Player") and not IsUsingWideScreen())
then
	return
end

local bg_and_judgments = Def.ActorFrame{
	Name="bg_and_judgements",
	InitCommand=function(self)
		if (PREFSMAN:GetPreference("Center1Player") and IsUsingWideScreen()) then
			-- 16:9 aspect ratio (approximately 1.7778)
			if GetScreenAspectRatio() > 1.7 then
				self:zoom(0.925)

			-- if 16:10 aspect ratio
			else
				self:zoom(0.825)
			end
		end
	end,

	LoadActor("./BackgroundAndBanner.lua", player),
	LoadActor("./GIF.lua", player),
	LoadActor("./StepsInfo.lua", player),
	LoadActor("./Time.lua", player),
	LoadActor("./JudgmentLabels.lua", player),
	LoadActor("./JudgmentNumbers.lua", player),
	LoadActor("./GSOverlay.lua", player),
}

return Def.ActorFrame{
	Name="StepStatistics"..pn,
	InitCommand=function(self)
		local aspectRatio = GetScreenAspectRatio()
		local offset = (aspectRatio > 1.7) and {x=71.5, y=0.5} or {x=64.5, y=2}
		local direction = (player == PLAYER_1) and 1 or -1
		
		local x = _screen.w/4 * (player == PLAYER_1 and 3 or 1) + (PREFSMAN:GetPreference("Center1Player") and IsUsingWideScreen() and offset.x or 0) * direction
		local y = 80 + (PREFSMAN:GetPreference("Center1Player") and IsUsingWideScreen() and offset.y or 0)

		self:xy(x, _screen.cy + y)
	end,

	bg_and_judgments,
	LoadActor("./DensityGraph.lua", player),
}
