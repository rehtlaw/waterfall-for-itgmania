local displayexscore = true -- TODO

local player = ...
local pn = tonumber(player:sub(-1))

local mods = SL[ToEnumShortString(player)].ActiveModifiers

local mode = (not mods.SimulateITGEnv) and "Waterfall" or "ITG"

local faplus = mods.FAPlus

if faplus == 0 then
	faplus = false
end

local options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")

local windows = DeepCopy(SL.Global.ActiveModifiers.TimingWindows)
if mode == "ITG" and ((not windows[5]) or (math.abs(PREFSMAN:GetPreference("TimingWindowSecondsW5") - 
	(SL.Preferences.ITG.TimingWindowSecondsW3 + SL.Preferences.ITG.TimingWindowAdd)) < 0.00001)) then
	windows = {true,true,true,false,false}
end
if mode == "ITG" and WF.SelectedErrorWindowSetting == 1 then windows[4] = false end

local possible, rv
local StepsOrTrail = (GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player)) or GAMESTATE:GetCurrentSteps(player)
local total_tapnotes = StepsOrTrail:GetRadarValues(player):GetValue( "RadarCategory_Notes" )

-- determine how many digits are needed to express the number of notes in base-10
local digits = (math.floor(math.log10(total_tapnotes)) + 1)
-- display a minimum 4 digits for aesthetic reasons
digits = math.max(4, digits)

-- generate a Lua string pattern that will be used to leftpad with 0s
local pattern = ("%%0%dd"):format(digits)


local TapNoteScores = { 'W1', 'W2', 'W3', 'W4', 'W5', 'Miss' }
local TapNoteJudgments = { W1=0, W2=0, W3=0, W4=0, W5=0, Miss=0 }
local w1plus = 0
local w1minus = 0
local RadarCategories = { 'Holds', 'Mines', 'Rolls' }
local RadarCategoryJudgments = { Holds=0, Mines=0, Rolls=0 }

local leadingZeroAttr
local row_height = 35

local t = Def.ActorFrame{
	Name="JudgementNumbers",
	InitCommand=function(self)
		self:zoom(0.8)
	end
}

-- do "regular" TapNotes first
for index, window in ipairs(TapNoteScores) do

	-- push down for FA+
	local h = (index-1)*row_height - 282
	if (faplus) and index > 1 then h = h + row_height end
	
	-- player performance value
	t[#t+1] = LoadFont("raxye/_raxye main")..{
		Text=(pattern):format(0),
		InitCommand=function(self)
			self:zoom(0.55):horizalign(left)

			if windows[index] or index==#TapNoteScores then
				self:diffuse( SL.JudgmentColors[mode][index] )
				leadingZeroAttr = { Length=(digits-1), Diffuse=Brightness(self:GetDiffuse(), 0.35) }
				self:AddAttribute(0, leadingZeroAttr )
			else
				self:diffuse(Brightness({1,1,1,1},0.25))
			end
		end,
		BeginCommand=function(self)
			self:x( 106 )
			self:y(h)

			-- horizontally squishing the numbers isn't pretty, but I'm not sure what else to do
			-- when people want to play "24 hours of 100 bpm stream" on a 4:3 monitor
			if not IsUsingWideScreen() and digits > 5 then
				self:x(104):maxwidth(185)
			end
		end,
		JudgmentMessageCommand=function(self, params)
			if params.Player ~= player then return end
			if params.HoldNoteScore then return end

			local checkjudgment = params.TapNoteScore
			if mode == "ITG" and checkjudgment ~= "TapNoteScore_AvoidMine" and checkjudgment ~= "TapNoteScore_Miss"
			and checkjudgment ~= "TapNoteScore_HitMine" and params.TapNoteOffset then
				checkjudgment = "TapNoteScore_W"..(DetermineTimingWindow(params.TapNoteOffset, "ITG"))
			end

			if checkjudgment and ToEnumShortString(checkjudgment) == window then
				TapNoteJudgments[window] = TapNoteJudgments[window] + 1

				-- condition for fa+
				local numtouse = TapNoteJudgments[window]
				if (faplus) and window == "W1" then
					if math.abs(params.TapNoteOffset) <= faplus then w1plus = w1plus + 1
					else
						w1minus = w1minus + 1
						MESSAGEMAN:Broadcast("UpdateW1Minus", {Player = player, n = w1minus})
					end
					numtouse = w1plus
				end
				self:settext( (pattern):format(numtouse) )

				leadingZeroAttr = {
					Length=(digits - (math.floor(math.log10(numtouse))+1)),
					Diffuse=Brightness(SL.JudgmentColors[mode][index], 0.35)
				}
				self:AddAttribute(0, leadingZeroAttr )

				MESSAGEMAN:Broadcast("UpdateFAPlus", {Player = player})
			end
		end
	}

	-- add text for FA+
	if (faplus) and index == 1 then
		t[#t+1] = LoadFont("_ScreenEvaluation numbers")..{
			Text=(pattern):format(0),
			InitCommand=function(self)
				self:zoom(0.5):horizalign(left)
	
				self:diffuse( Color.White )
				leadingZeroAttr = { Length=(digits-1), Diffuse=Brightness(self:GetDiffuse(), 0.35) }
				self:AddAttribute(0, leadingZeroAttr )
			end,
			BeginCommand=function(self)
				self:x( 108 )
				self:y(h + row_height)
	
				if not IsUsingWideScreen() and digits > 5 then
					self:x(104):maxwidth(185)
				end
			end,
			UpdateW1MinusMessageCommand=function(self, params)
				if params.Player ~= player then return end
				
				local whites = params.n
	
				self:settext( (pattern):format(whites) )

				leadingZeroAttr = {
					Length=(digits - (math.floor(math.log10(whites))+1)),
					Diffuse=Brightness(Color.White, 0.35)
				}
				self:AddAttribute(0, leadingZeroAttr )
			end
		}
	end

end

-- remove holds/mines/rolls
-- then handle holds, mines, hands, rolls
for index, RCType in ipairs(RadarCategories) do

	-- player performance value
	t[#t+1] = LoadFont("_ScreenEvaluation numbers")..{
		Name="HoldMineRoll_bg_"..index,
		Text="000",
		InitCommand=function(self) self:zoom(0.5):horizalign(right) end,
		BeginCommand=function(self)
			self:y((index-1)*row_height - 178)
			self:x( -54 )

			leadingZeroAttr = { Length=2, Diffuse=color("#5A6166") }
			self:AddAttribute(0, leadingZeroAttr )
		end,
		JudgmentMessageCommand=function(self, params)
			if params.Player ~= player then return end
			if not params.TapNoteScore then return end

			if RCType=="Mines" and params.TapNoteScore == "TapNoteScore_AvoidMine" then
				RadarCategoryJudgments.Mines = RadarCategoryJudgments.Mines + 1
				if not options:NoMines() then 
				self:settext( string.format("%03d", RadarCategoryJudgments.Mines) )
				end

			elseif RCType=="Holds" and params.TapNote and params.TapNote:GetTapNoteSubType() == "TapNoteSubType_Hold" then
				RadarCategoryJudgments.Holds = RadarCategoryJudgments.Holds + 1
				self:settext( string.format("%03d", RadarCategoryJudgments.Holds) )

			elseif RCType=="Rolls" and params.TapNote and params.TapNote:GetTapNoteSubType() == "TapNoteSubType_Roll" then
				RadarCategoryJudgments.Rolls = RadarCategoryJudgments.Rolls + 1
				self:settext( string.format("%03d", RadarCategoryJudgments.Rolls) )
			end

			leadingZeroAttr = { Length=(3-tonumber(tostring(RadarCategoryJudgments[RCType]):len())), Diffuse=color("#5A6166") }
			self:AddAttribute(0, leadingZeroAttr )
		end
	}

	--  slash
	t[#t+1] = LoadFont("Common Normal")..{
		Name="HoldMineRoll_slash_"..index,
		Text="/",
		InitCommand=function(self) self:diffuse(color("#5A6166")):zoom(1.25):horizalign(right) end,
		BeginCommand=function(self)
			self:y((index-1)*row_height - 178)
			self:x(-40)
		end
	}

	-- possible value
	t[#t+1] = LoadFont("_ScreenEvaluation numbers")..{
		Name="HoldMineRoll_value_"..index,
		InitCommand=function(self) self:zoom(0.5):horizalign(right) end,
		BeginCommand=function(self)

			possible = 0
			StepsOrTrail = (GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player)) or GAMESTATE:GetCurrentSteps(player)

			if StepsOrTrail then
				rv = StepsOrTrail:GetRadarValues(player)
				possible = rv:GetValue( RCType )
				-- non-static courses (for example, "Most Played 1-4") will return -1 here
				if possible < 0 then possible = 0 end
			end

			self:y((index-1)*row_height - 178)
			self:x( 16 )
			self:settext( string.format("%03d", possible) )
			local leadingZeroAttr = { Length=3-tonumber(tostring(possible):len()); Diffuse=color("#5A6166") }
			self:AddAttribute(0, leadingZeroAttr )
		end
	}
end

-- If player has mines disabled and there are mines in the chart
-- draw cross through the mine line to show they are disabled



local num_mines = StepsOrTrail:GetRadarValues(player):GetValue("RadarCategory_Mines")
			
if options:NoMines() and num_mines > 0 then
	t[#t+1] = Def.Quad {
		Name="NoMines1",
		InitCommand=function(self)
			self:zoomto(120,3)
			self:y(row_height - 178)
			self:x(-45)
			self:rotationz(10)
			self:diffuse(1,0,0,1)
		end		
	}
	t[#t+1] = Def.Quad {
		Name="NoMines2",
		InitCommand=function(self)
			self:zoomto(120,3)
			self:y(row_height - 178)
			self:x(-45)
			self:rotationz(-10)
			self:diffuse(1,0,0,1)
		end		
	}
end


-- fa+ percent
if faplus then
	t[#t+1] = LoadFont("_ScreenEvaluation numbers")..{
		Text = "0.00",
		InitCommand=function(self) self:zoom(0.5) end,
		BeginCommand = function(self)
			local x = -56
			local y = 142
			self:x(x):y(3*row_height - y) -- TODO align the numbers better maybe
			
		end,
		UpdateFAPlusMessageCommand = function(self, params)
			if params.Player ~= player then return end

			local totalj = (TapNoteJudgments.W1 + TapNoteJudgments.W2 + TapNoteJudgments.W3 + TapNoteJudgments.W4
				+ TapNoteJudgments.W5 + TapNoteJudgments.Miss)

			local raw = (totalj > 0) and w1plus/totalj or 0

			self:settext(string.format("%0.2f", math.floor(raw*10000)/100))
		end
	}
end

return t
