local num_items = THEME:GetMetric("MusicWheel", "NumWheelItems")
-- subtract 2 from the total number of MusicWheelItems
-- one MusicWheelItem will be offsceen above, one will be offscreen below
local num_visible_items = num_items - 2
local item_width = _screen.w / 2.125

local stepstype = ToEnumShortString(GAMESTATE:GetCurrentStyle():GetStepsType())

local curdiff = {}

local abbrevs = WF.ClearTypesShort

local af = Def.ActorFrame{
	-- the MusicWheel is centered via metrics under [ScreenSelectMusic]; offset by a slight amount to the right here
	InitCommand=function(self) self:x(WideScale(28,33)) end,

	Def.Quad{ InitCommand=function(self) self:horizalign(left):diffuse(color("#000000")):diffusealpha(0.9):zoomto(item_width, _screen.h/num_visible_items) end },
	Def.Quad{ InitCommand=function(self) self:horizalign(left):diffuse(color("#283239")):diffusealpha(0.9):zoomto(item_width, _screen.h/num_visible_items - 1) end }
}

-- clear type/grade stuff
for player in ivalues(GAMESTATE:GetHumanPlayers()) do
	local pn = tonumber(player:sub(-1))
	local gradeframe = Def.ActorFrame{
		InitCommand = function(self) self:x(28 + (pn == 1 and -WideScale(20,14) or WideScale(-2, 18))):aux(-1) end,
		SetMessageCommand = function(self, params)
			-- parameter stuff
			if not WF.PlayerProfileStats[pn] then return end
			if params then
				if params.Type ~= "SectionCollapsed" then return end
				if self:GetParent():GetParent():GetParent():GetSelectedType() == "WheelItemDataType_Section" then
					self:playcommand("SetSelfSC", params)
				end
			end
		end,
		["CurrentStepsP"..pn.."ChangedMessageCommand"] = function(self)
			if not GAMESTATE:GetCurrentSteps(player) then return end
			if self:GetParent():GetParent():GetParent():GetSelectedSection() == self:GetParent():GetParent():GetText() then
				return
			end
			curdiff[pn] = GAMESTATE:GetCurrentSteps(player):GetDifficulty()
			self:playcommand("SetSelfSC")
		end,
		SetSelfSCCommand = function(self)
			if self:GetParent():GetParent():GetType() ~= 1 then
				return
			end

			-- clear with blank first
			self:playcommand("SetMe")
	
			local name = (params and params.Text) or self:GetParent():GetParent():GetText()
			if not name then return end

			local songs = SONGMAN:GetSongsInGroup(name)
			if not songs then return end

			local diff = curdiff[pn]
			if (not diff) or diff == "Difficulty_Edit" then return end

			local rate = RateFromNumber(SL.Global.ActiveModifiers.MusicRate)
			local itg = SL["P"..pn].ActiveModifiers.SimulateITGEnv

			local vals = WF.CheckClearsAndGrades(stepstype, name, diff, rate, pn)
			if not vals then
				vals = WF.CalculateClearsAndGrades(stepstype, name, diff, rate, pn)
			end
			if not vals then return end

			local arg = itg and vals.ITG or vals.WF
			if arg == 0 then return end
			
			self:playcommand("SetMe", {arg})
		end
	}
	gradeframe[#gradeframe+1] = LoadFont("Common Normal")..{
		Name = "CTText",
		InitCommand = function(self) self:maxwidth(WideScale(10, 20)) end,
		SetMeCommand = function(self, param)
			if not param then self:visible(false) return end
			local arg = param[1]
			if arg == 99 then
				self:settext("*"):diffuse(Color.White):visible(true)
			elseif not SL["P"..pn].ActiveModifiers.SimulateITGEnv then
				self:settext(abbrevs[arg]):diffuse(WF.ClearTypeColor(arg)):visible(true)
			else
				self:visible(false)
			end
		end
	}
	if SL["P"..pn].ActiveModifiers.SimulateITGEnv then
		gradeframe[#gradeframe+1] = LoadActor(THEME:GetPathG("","_GradesSmall/WheelLetterGrade.lua"), {itg = true})..{
			Name = "ITGGrade",
			OnCommand = function(self)
				self:zoom(WideScale(0.18, 0.3))
			end,
			SetMeCommand = function(self, param)
				local grade = param and param[1] or 99
				self:playcommand("SetGrade", {grade})
			end
		}
	end

	af[#af+1] = gradeframe
end

return af
