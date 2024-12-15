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
local lastcourse = {}
local curdiff = {}

local abbrevs = WF.ClearTypesShort
local shortrate = nil

-- clear types/grades
for player in ivalues(players) do
	local pn = tonumber(player:sub(-1))
	local gradeframe = Def.ActorFrame{
		InitCommand = function(self) self:x(28 + (pn == 1 and -WideScale(20,14) or WideScale(-2, 18))):aux(-1) end,
		SetMessageCommand = function(self, params)
			-- parameter stuff
			local course
			if params then
				if params.Type ~= "Course" then return end
				course = params.Course
				if params.Index then
					self:aux(params.Index)
					lastcourse[params.Index] = course
				end
				if self:GetParent():GetParent():GetParent():GetSelectedType() == "WheelItemDataType_Section" then
					self:playcommand("SetSelf", params)
				end
			end
		end,
		["CurrentTrailP"..pn.."ChangedMessageCommand"] = function(self)
			if not GAMESTATE:GetCurrentTrail(player) then return end
			curdiff[pn] = GAMESTATE:GetCurrentTrail(player):GetDifficulty()
			self:playcommand("SetSelf")
		end,
		SetSelfCommand = function(self, params)
			if self:GetParent():GetParent():GetType() ~= 6 then
				return
			end

			-- clear with blank first
			self:playcommand("SetMe")

			local course = (params and params.Course) or lastcourse[self:getaux()]
			if not course then return end

			local curtrail = GAMESTATE:GetCurrentTrail(player)

			local diff = curdiff[pn]
			if diff == "Difficulty_Edit" then
				return
			end
			local trail
			for trl in ivalues(course:GetAllTrails()) do
				if trl:GetDifficulty() == diff and trl:GetStepsType() == stepstype then
					trail = trl
					break
				end
			end

			if trail then
				local rate = RateFromNumber(SL.Global.ActiveModifiers.MusicRate)
				local stats = WF.GetMusicWheelCourseStats(course, trail, rate, pn)
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
				if stats then
					local ct = stats.BestClearType
					if ct ~= WF.ClearTypes.None then
						self:diffuse(WF.ClearTypeColor(ct))
						if tonumber(stats.RateMod) == SL.Global.ActiveModifiers.MusicRate then
							self:settext(abbrevs[ct])
						else
							self:settext(shortrate or stats.RateMod)
						end
					else
						self:diffuse(Color.White)
						self:settext("*")
					end
					self:visible(true)
				else
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
