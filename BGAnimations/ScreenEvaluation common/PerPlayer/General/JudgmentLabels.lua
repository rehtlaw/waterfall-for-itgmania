local args = ...
local player = args.player
local side = player
if args.sec then side = (player == PLAYER_1) and PLAYER_2 or PLAYER_1 end
local pn = ToEnumShortString(player)
local stats = STATSMAN:GetCurStageStats():GetPlayerStageStats(pn)

local mods = SL[ToEnumShortString(player)].ActiveModifiers

local faplus = mods.FAPlus
if faplus == 0 or faplus == 0.015 then faplus = false end
local displayExScore = mods.EXScoring

local tns_string = "TapNoteScore"

local firstToUpper = function(str)
    return (str:gsub("^%l", string.upper))
end

local getStringFromTheme = function( arg )
	return THEME:GetString(tns_string, arg);
end

-- Iterating through the enum isn't worthwhile because the sequencing is so bizarre...
local TapNoteScores = {}
TapNoteScores.Types = { 'W1', 'W2', 'W3', 'W4', 'W5', 'Miss' }
TapNoteScores.Names = map(getStringFromTheme, TapNoteScores.Types)

local RadarCategories = {
	THEME:GetString("ScreenEvaluation", 'Holds'),
	THEME:GetString("ScreenEvaluation", 'Mines'),
	THEME:GetString("ScreenEvaluation", 'Rolls')
}

local EnglishRadarCategories = {
	[THEME:GetString("ScreenEvaluation", 'Holds')] = "Holds",
	[THEME:GetString("ScreenEvaluation", 'Mines')] = "Mines",
	[THEME:GetString("ScreenEvaluation", 'Rolls')] = "Rolls",
}

local scores_table = {}
for index, window in ipairs(TapNoteScores.Types) do
	local number = stats:GetTapNoteScores( "TapNoteScore_"..window )
	scores_table[window] = number
end

local t = Def.ActorFrame{
	InitCommand=function(self)
		self:xy(50 * (side==PLAYER_1 and 1 or -1), _screen.cy-24)
	end,
}

local windows = SL.Global.ActiveModifiers.TimingWindows

--  labels: W1 ---> Miss
for i=1, #TapNoteScores.Types do
	-- no need to add BitmapText actors for TimingWindows that were turned off
	if windows[i] or i==#TapNoteScores.Types then

		local window = TapNoteScores.Types[i]
		local label = getStringFromTheme( window )

		-- push aw-ok down if fa+ and #boysoff
		local pushdown = ((faplus) and (not windows[5]) and i > 1 and i < 6) and 28 or 0

		t[#t+1] = LoadFont("Common Normal")..{
			Text=label:upper(),
			InitCommand=function(self) self:zoom(0.833):horizalign(right):maxwidth(76) end,
			BeginCommand=function(self)
				self:x( (side == PLAYER_1 and 28) or -28 )
				self:y((i-1)*28 -16 + pushdown)
				-- diffuse the JudgmentLabels the appropriate colors
				self:diffuse( SL.JudgmentColors.Waterfall[i] )
			end
		}

		-- Pink/white W1 -- if using FA+ _and_ boys are off, we have room to show both
		if (faplus) and (i == 1) and (not windows[5]) then
			t[#t+1] = LoadFont("Common Normal")..{
				Text=label:upper(),
				InitCommand=function(self) self:zoom(0.833):horizalign(right):maxwidth(76) end,
				BeginCommand=function(self)
					self:x( (side == PLAYER_1 and 28) or -28 )
					self:y(12)
					-- diffuse the JudgmentLabels the appropriate colors
					self:diffuse( Color.White )
				end
			}
		end
	end
end

-- labels: holds, mines, rolls
for index, label in ipairs(RadarCategories) do

	local performance = stats:GetRadarActual():GetValue( "RadarCategory_"..firstToUpper(EnglishRadarCategories[label]) )
	local possible = stats:GetRadarPossible():GetValue( "RadarCategory_"..firstToUpper(EnglishRadarCategories[label]) )

	t[#t+1] = LoadFont("Common Normal")..{
		Text=label,
		InitCommand=function(self) self:zoom(0.833):horizalign(right) end,
		BeginCommand=function(self)
			self:x( (side == PLAYER_1) and -160 or 80 )
			self:y((index-1)*28 + 41)
			if displayExScore then
				self:y((index-1) * 28 + 71)
			end
		end,
		SendEventDataMessageCommand=function(self)
			self:y((index-1) * 28 + 71)
		end
	}
end

return t
