-- quad copied from course file
local num_items = THEME:GetMetric("MusicWheel", "NumWheelItems")
-- subtract 2 from the total number of MusicWheelItems
-- one MusicWheelItem will be offsceen above, one will be offscreen below
local num_visible_items = num_items - 2

local item_width = _screen.w / 2.125

local af = Def.ActorFrame{
	-- the MusicWheel is centered via metrics under [ScreenSelectMusic]; offset by a slight amount to the right here
	InitCommand=function(self) self:x(WideScale(28,33)) end,

	Def.Quad{ InitCommand=function(self) self:horizalign(left):diffuse(0, 10/255, 17/255, 0.5)
		:zoomto(item_width, _screen.h/num_visible_items) end },
	Def.Quad{ InitCommand=function(self) self:horizalign(left):diffuse(DarkUI() and {1,1,1,0.5}
		or {10/255, 20/255, 27/255, 1}):zoomto(item_width, (_screen.h/num_visible_items)-1) end }
}

local stepstype = GAMESTATE:GetCurrentStyle():GetStepsType()
local players = GAMESTATE:GetHumanPlayers()
local lastsong = {}
local curdiff = {}

local abbrevs = WF.ClearTypesShort
local shortrate = nil
if not IsUsingWideScreen() then
	-- abbreviations are impossible to read with the smaller space, so use shorter ones
	abbrevs = {"★","AC","SC","FC","H","C","E","F",""}
	shortrate = "R"
end

-- clear types/grades
for player in ivalues(players) do
    af[#af+1] = LoadActor("Favorites.lua", player)

	local pn = tonumber(player:sub(-1))
	local gradeframe = Def.ActorFrame{
		InitCommand = function(self) self:x(28 + (pn == 1 and -WideScale(20,14) or WideScale(-2, 18))):aux(-1) end,
		SetMessageCommand = function(self, params)
			-- parameter stuff
			local song
			if params then
				if params.Type ~= "Song" then return end
				song = params.Song
				if params.Index then
					self:aux(params.Index)
					lastsong[params.Index] = song
				end
				if self:GetParent():GetParent():GetParent():GetSelectedType() == "WheelItemDataType_Section" then
					self:playcommand("SetSelf", params)
				end
			end
		end,
		["CurrentStepsP"..pn.."ChangedMessageCommand"] = function(self)
			if not GAMESTATE:GetCurrentSteps(player) then return end
			curdiff[pn] = GAMESTATE:GetCurrentSteps(player):GetDifficulty()
			self:playcommand("SetSelf")
		end,
		SetSelfCommand = function(self, params)
			if self:GetParent():GetParent():GetType() ~= 2 then
				return
			end

			-- clear with blank first
			self:playcommand("SetMe")

			local song = (params and params.Song) or lastsong[self:getaux()]
			if not song then return end

			local cursteps = GAMESTATE:GetCurrentSteps(player)

			local diff = curdiff[pn]
			local editindex = 1
			if diff == "Difficulty_Edit" and cursteps then
				editindex = WF.GetEditIndex(GAMESTATE:GetCurrentSong(), cursteps)
 			end
 			local steps
 			local ei = 1
			local all_steps_in_song = song:GetStepsByStepsType(stepstype)
			local num_steps = #all_steps_in_song
			for chart in ivalues(all_steps_in_song) do
 				if diff ~= "Difficulty_Edit" then
					if chart:GetDifficulty() == diff or num_steps == 1 then
 						steps = chart
 						break
 					end
				else
					if chart:GetDifficulty() == "Difficulty_Edit" then
						if ei == editindex then
							steps = chart
							break
						else
							ei = ei + 1
						end
					end
				end
			end

			if steps then
				local rate = RateFromNumber(SL.Global.ActiveModifiers.MusicRate)
				local stats = WF.GetMusicWheelSongStats(song, steps, rate, pn)
				if stats then
					self:playcommand("SetMe", stats)
				end
			end
		end
	}

	if not SL["P"..pn].ActiveModifiers.SimulateITGEnv then
		gradeframe[#gradeframe+1] = LoadFont("Common Normal")..{
			Name = "CTText",
			Text = "",
			InitCommand = function(self) self:maxwidth(WideScale(10, 20)) end,
			SetMeCommand = function(self, stats)
                self:visible(false)
				if stats then
					local ct = stats.BestClearType
		                  local grade = WF.Grades[CalculateGrade(stats.BestPercentDP)]
		                  -- local grade = CalculateGrade(stats.BestPercentDP)
					if ct ~= WF.ClearTypes.None then
                        self:settext("")
						self:diffuse(WF.ClearTypeColor(ct))
						if not tonumber(stats.RateMod) == SL.Global.ActiveModifiers.MusicRate then
                            self:visible(true)
							self:settext(shortrate or stats.RateMod)
						end
					else
                        self:visible(true)
						self:diffuse(Color.White)
						self:settext("*")
					end
					self:visible(true)
				else
					self:visible(false)
				end
			end
		}
		gradeframe[#gradeframe+1] = LoadActor(THEME:GetPathG("","_GradesSmall/WheelLetterGrade.lua"), {})..{
			Name = "CTGrade",
			Text = "",
			OnCommand = function(self)
				self:zoom(WideScale(0.18, 0.25))
                self:x(3)
			end,
			SetMeCommand = function(self, stats)
				if stats then
					local ct = stats.BestClearType
                    local grade = CalculateGrade(stats.BestPercentDP)
					if ct ~= WF.ClearTypes.None then
						self:diffuse(WF.ClearTypeColor(ct))
						if tonumber(stats.RateMod) == SL.Global.ActiveModifiers.MusicRate then
                            self:playcommand("SetGrade", {grade})
						else
							self:visible(false)
						end
					else
					    self:playcommand("SetGrade", {99})
                        self:visible(false)
					end
					self:visible(true)
				else
                    self:playcommand("SetGrade", {99})
					self:visible(false)
				end
			end
		}
	else
		gradeframe[#gradeframe+1] = LoadActor(THEME:GetPathG("","_GradesSmall/WheelLetterGrade.lua"), {itg = true})..{
			Name = "ITGGrade",
			OnCommand = function(self)
				self:zoom(WideScale(0.18, 0.3))
			end,
			SetMeCommand = function(self, stats)
				if stats then
					local grade = CalculateGradeITG(stats)
					self:playcommand("SetGrade", {grade})
					self:diffusealpha((tonumber(stats.RateMod) == SL.Global.ActiveModifiers.MusicRate) and 1 or 0.2)
				else
					self:playcommand("SetGrade", {99})
				end
			end
		}
		gradeframe[#gradeframe+1] = LoadFont("Common Normal")..{
			Name = "ITGText",
			Text = "",
			InitCommand = function(self) self:maxwidth(20) end,
			SetMeCommand = function(self, stats)
				if stats then
					if not stats.Cleared_ITG then
						self:settext("*"):visible(true)
					elseif tonumber(stats.RateMod) ~= SL.Global.ActiveModifiers.MusicRate then
						self:settext(shortrate or stats.RateMod):visible(true)
					else
						self:visible(false)
					end
				else
					self:visible(false)
				end
			end
		}
	end

	af[#af+1] = gradeframe
end

return af
