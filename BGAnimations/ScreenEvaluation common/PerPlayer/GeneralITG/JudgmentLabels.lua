local args = ...
local player = args.player
local side = player
if args.sec then side = (player == PLAYER_1) and PLAYER_2 or PLAYER_1 end
local pn = ToEnumShortString(player)

local faplus = SL[pn].ActiveModifiers.FAPlus
if faplus == 0 then faplus = 0.015 end

local tns_string = "TapNoteScore"

local firstToUpper = function(str)
    return (str:gsub("^%l", string.upper))
end

local getStringFromTheme = function( arg )
	return THEME:GetString(tns_string, arg);
end

local RadarCategories = {
	THEME:GetString("ScreenEvaluation", 'Holds'),
	THEME:GetString("ScreenEvaluation", 'Mines'),
	THEME:GetString("ScreenEvaluation", 'Rolls')
}

local t = Def.ActorFrame{
	InitCommand=function(self)
		self:xy(50 * (side==PLAYER_1 and 1 or -1), _screen.cy-24)
	end,
}

local boys = (SL.Global.ActiveModifiers.TimingWindows[5]) and (math.abs(PREFSMAN:GetPreference("TimingWindowSecondsW5") -
	(SL.Preferences.ITG.TimingWindowSecondsW3 + SL.Preferences.ITG.TimingWindowAdd)) >= 0.00001)
local windows = {true,true,true,boys,boys}
if WF.SelectedErrorWindowSetting == 1 then windows[4] = false end

--  labels: W1 ---> Miss
for i=1, 6 do
	-- no need to add BitmapText actors for TimingWindows that were turned off
	if windows[i] or (i == 6) then

		local label = WF.ITGJudgments[i]:upper()

		if (i == 3 and PREFSMAN:GetPreference("TimingWindowSecondsW5") <= SL.Preferences.Waterfall.TimingWindowSecondsW4)
		or (i == 5 and math.abs(PREFSMAN:GetPreference("TimingWindowSecondsW5") -
		(SL.Preferences.ITG.TimingWindowSecondsW5 + SL.Preferences.ITG.TimingWindowAdd)) >= 0.00001) then
			label = label.." *"
		end

		-- push ex-decent down if fa+ and #boysoff
		local pushdown = ((faplus) and (not windows[4]) and i > 1 and i < 6) and 28 or 0
		if i == 5 and WF.SelectedErrorWindowSetting == 1 then pushdown = 0 end

		t[#t+1] = LoadFont("Common Normal")..{
			Text=label,
			InitCommand=function(self) self:zoom(0.833):horizalign(right):maxwidth(76) end,
			BeginCommand=function(self)
				self:x( (side == PLAYER_1 and 28) or -28 )
				self:y((i-1)*28 -16 + pushdown)
				-- diffuse the JudgmentLabels the appropriate colors
				self:diffuse( SL.JudgmentColors.ITG[i] )
				--if i == 4 and WF.SelectedErrorWindowSetting == 1 then self:visible(false) end
			end
		}

		-- Blue/white Fantastic -- if using FA+ _and_ boys are off, we have room to show both
		if (faplus) and (i == 1) and (not windows[4]) then
			t[#t+1] = LoadFont("Common Normal")..{
				Text=label,
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

-- labels: holds, mines, hands, rolls
for index, label in ipairs(RadarCategories) do
	t[#t+1] = LoadFont("Common Normal")..{
		Text=label,
		InitCommand=function(self) self:zoom(0.833):horizalign(right) end,
		BeginCommand=function(self)
			self:x( (side == PLAYER_1) and -160 or 80 )
			self:y((index-1)*28 + 41)
		end
	}
end

-- FA+ label
if faplus then
	local f = string.format("%d", faplus*1000)
	t[#t+1] = LoadFont("Common Normal")..{
		Text="FA+ ("..f.."ms)",
		InitCommand=function(self) self:zoom(0.8) end,
		BeginCommand=function(self)
			self:x( (side == PLAYER_1 and -161) or 76 )
			self:y(3 * 28 + 43)
		end
	}
end

return t
