local args = ...
local player = args.player
local side = player
if args.sec then side = (player == PLAYER_1) and PLAYER_2 or PLAYER_1 end
local p = tonumber(player:sub(-1))
local pn = ToEnumShortString(player)
local sn = ToEnumShortString(side)
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)

-- If player has mines disabled, total mine count shows 0. Get actual number from
-- global variable set in BGAnimations\ScreenGameplay overlay\MineCount.lua
local num_mines = GAMESTATE:Env()["TotalMines" .. pn]
local options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")

local faplus = 0.015

-- FA+ stuff
local blues = WF.FAPlusCount[p][3]

local TapNoteScores = {
	Types = { 'W1', 'W2', 'W3', 'W4', 'W5', 'Miss' },
	-- x values for P1 and P2
	x = { P1=64, P2=94 }
}

local RadarCategories = {
	Types = { 'Holds', 'Mines', 'Rolls' },
	-- x values for P1 and P2
	x = { P1=-180, P2=218 }
}


local t = Def.ActorFrame{
	InitCommand=function(self)self:zoom(0.8):xy(90,_screen.cy-24) end,
	OnCommand=function(self)
		-- shift the x position of this ActorFrame to -90 for PLAYER_2
		if side == PLAYER_2 then
			self:x( self:GetX() * -1 )
		end
	end
}

-- do "regular" TapNotes first
local gmods = SL.Global.ActiveModifiers
local boys = (gmods.TimingWindows[5]) and (math.abs(PREFSMAN:GetPreference("TimingWindowSecondsW5") -
(SL.Preferences.ITG.TimingWindowSecondsW3 + SL.Preferences.ITG.TimingWindowAdd)) >= 0.00001)
local dummywindows = {true,true,true,boys,boys}
if WF.SelectedErrorWindowSetting == 1 then dummywindows[4] = false end
local showfaplus = true
for i=1,#TapNoteScores.Types do
	local window = TapNoteScores.Types[i]
	local number = WF.ITGJudgmentCounts[p][i]

	if (showfaplus) and i == 1 then number = blues end
	local zerorow = not dummywindows[i] and i ~= 6
	local pushdown = (i > 1) and 33 or 0

	-- actual numbers
	t[#t+1] = Def.RollingNumbers{
		Font="_ScreenEvaluation numbers",
		InitCommand=function(self)
			self:zoom(0.5):horizalign(right):maxwidth(76/0.5)

			self:diffuse( SL.JudgmentColors.ITG[i] )

			-- if some TimingWindows were turned off, the leading 0s should not
			-- be colored any differently than the (lack of) JudgmentNumber,
			-- so load a unique Metric group.
			if zerorow then
				self:Load("RollingNumbersEvaluationNoDecentsWayOffs")
				self:diffuse(color("#444444"))

			-- Otherwise, We want leading 0s to be dimmed, so load the Metrics
			-- group "RollingNumberEvaluationA"	which does that for us.
			elseif not (showfaplus and i == 5 and WF.SelectedErrorWindowSetting ~= 1) then
				self:Load("RollingNumbersEvaluationA")
			else
				-- extra text, hide
				self:Load("RollingNumbersEvaluationA")
				-- self:visible(false)
			end
		end,
		BeginCommand=function(self)
			self:x( TapNoteScores.x[sn] )
			self:y((i-1) * 30 - 20 + pushdown)
			self:targetnumber(number)
		end
	}

	-- FA+ number, if shown
	if i == 1 then
		t[#t+1] = Def.RollingNumbers{
			Font="_ScreenEvaluation numbers",
			InitCommand = function(self)
				self:zoom(0.5):horizalign(right)
				self:diffuse(Color.White)
				self:Load("RollingNumbersEvaluationA")
			end,
			BeginCommand = function(self)
				self:x( TapNoteScores.x[sn] )
				self:y(11)
				self:targetnumber(WF.ITGJudgmentCounts[p][1] - blues)
			end
		}
	end

end


-- then handle holds, mines, rolls
for index, RCType in ipairs(RadarCategories.Types) do

	local performance = pss:GetRadarActual():GetValue( "RadarCategory_"..RCType )
	local possible = pss:GetRadarPossible():GetValue( "RadarCategory_"..RCType )

	-- If player has mines disabled, total mine count shows 0. Display actual number
	if options:NoMines() and RCType == 'Mines' then
		performance = num_mines
		possible = num_mines
	end

	-- player performance value
	t[#t+1] = Def.RollingNumbers{
		Font="_ScreenEvaluation numbers",
		InitCommand=function(self) self:zoom(0.5):horizalign(right):Load("RollingNumbersEvaluationB") end,
		BeginCommand=function(self)
			self:y((index-1)*35 + 89)
			self:x( RadarCategories.x[sn] )
			self:targetnumber(performance)
		end
	}

	--  slash
	t[#t+1] = LoadFont("Common Normal")..{
		Text="/",
		InitCommand=function(self) self:diffuse(color("#5A6166")):zoom(1.25):horizalign(right) end,
		BeginCommand=function(self)
			self:y((index-1)*35 + 89)
			self:x( ((side == PLAYER_1) and -168) or 230 )
		end
	}

	-- possible value
	t[#t+1] = LoadFont("_ScreenEvaluation numbers")..{
		InitCommand=function(self) self:zoom(0.5):horizalign(right) end,
		BeginCommand=function(self)
			self:y((index-1)*35 + 89)
			self:x( ((side == PLAYER_1) and -114) or 286 )
			self:settext(("%03.0f"):format(possible))
			local leadingZeroAttr = { Length=math.max(3-tonumber(tostring(possible):len()),0), Diffuse=color("#5A6166") }
			self:AddAttribute(0, leadingZeroAttr )
		end
	}

end

-- If player has mines disabled and there are mines in the chart
-- draw cross through the mine line to show they are disabled
if options:NoMines() and num_mines > 0 then
	t[#t+1] = Def.Quad {
		Name="NoMines1",
		InitCommand=function(self)
			self:zoomto(120,3)
			self:y(35+89)
			self:x( ((side == PLAYER_1) and -173) or 226 )
			self:rotationz(10)
			self:diffuse(1,0,0,1)
		end
	}
	t[#t+1] = Def.Quad {
		Name="NoMines2",
		InitCommand=function(self)
			self:zoomto(120,3)
			self:y(35+89)
			self:x( ((side == PLAYER_1) and -173) or 226 )
			self:rotationz(-10)
			self:diffuse(1,0,0,1)
		end
	}
end

return t
