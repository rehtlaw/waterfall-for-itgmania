local args = ...
local pn = args.player or args

local stats = STATSMAN:GetCurStageStats():GetPlayerStageStats(pn)
local PercentDP = stats:GetPercentDancePoints()
local percent = FormatPercentScore(PercentDP)
if args.mode and args.mode == "ITG" then
	percent = WF.ITGScore[tonumber(pn:sub(-1))]
end
-- Format the Percentage string, removing the % symbol
percent = percent:gsub("%%", "")

return Def.ActorFrame{
	Name="PercentageContainer"..ToEnumShortString(pn),
	InitCommand=function(self)
		self:x( -115 )
		self:y( _screen.cy-40 )
	end,

	-- dark background quad behind player percent score
	Def.Quad{
		InitCommand=function(self)
			self:diffuse( color("#101519") )
				:y(-2)
				:zoomto(70, 28)
		end
	},

	LoadFont("raxye/_raxye numbers")..{
		Text=percent,
		Name="Percent",
		InitCommand=function(self) self:horizalign(right):zoom(0.175):xy( 30, -10) end,
	}
}
