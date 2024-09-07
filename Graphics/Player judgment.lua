local player = Var "Player"
local pn = ToEnumShortString(player)
local mods = SL[pn].ActiveModifiers
local sprite
local text

------------------------------------------------------------
-- A profile might ask for a judgment graphic that doesn't exist
-- If so, use the first available Judgment graphic
-- If that fails too, fail gracefully and do nothing

local useitg = SL[pn].ActiveModifiers.SimulateITGEnv
local available_judgments = GetJudgmentGraphics(useitg and "ITG" or nil)

local file_to_load = (FindInTable(mods.JudgmentGraphic, available_judgments) ~= nil and mods.JudgmentGraphic or available_judgments[1]) or "None"

if file_to_load == "None" then
	return Def.Actor{ InitCommand=function(self) self:visible(false) end }
end

local usetext = (file_to_load == "Plain Text")

if useitg and (not usetext) then file_to_load = "itg/"..file_to_load end

local threshold = mods.FAPlus
if (not useitg) and threshold == 0.015 then threshold = 0 end

------------------------------------------------------------

local TNSFrames = {
	TapNoteScore_W1 = 0,
	TapNoteScore_W2 = 2,
	TapNoteScore_W3 = 3,
	TapNoteScore_W4 = 4,
	TapNoteScore_W5 = 5,
	TapNoteScore_Miss = 6
}

local af = Def.ActorFrame{
	Name="Player Judgment",
	InitCommand=function(self)
		local kids = self:GetChildren()
		sprite = kids.JudgmentWithOffsets
		if usetext then
			text = kids.PlainTextJudgment
		end
	end,
	JudgmentMessageCommand=function(self, param)
		if param.Player ~= player or not param.TapNoteScore or param.HoldNoteScore then return end

		local TNSToUse = param.TapNoteScore
		if useitg and TNSToUse ~= "TapNoteScore_Miss" and TNSToUse ~= "TapNoteScore_AvoidMine" and TNSToUse ~= "TapNoteScore_HitMine" then
			local window = DetermineTimingWindow(param.TapNoteOffset, "ITG")
			TNSToUse = "TapNoteScore_W"..window
		end
        if TNSToUse == "TapNoteScore_AvoidMine" or TNSToUse == "TapNoteScore_HitMine" then return end
		
		local judgement = usetext and text or sprite
		local TNO = param.TapNoteOffset or 0

		if mods.JudgementTilt then
			judgement:rotationz(TNO * 300 * mods.JudgementTiltMultiplier)
		end
		
		if not usetext then
			local frame = TNSFrames[TNSToUse]
			-- most judgment sprite sheets have 12 or 14 frames; 6/7 for early judgments, 6/7 for late judgments
			-- some (the original 3.9 judgment sprite sheet for example) do not visibly distinguish
			-- early/late judgments, and thus only have 6/7 frames
			if sprite:GetNumStates() == 12 or sprite:GetNumStates() == 14 then
				frame = frame * 2
				if not param.Early then frame = frame + 1 end
			end
			if not frame then return end

			if TNSToUse == "TapNoteScore_W1" and threshold > 0 and math.abs(TNO) > threshold then
				if sprite:GetNumStates() == 14 then
					if param.Early then frame = 2 else frame = 3 end
                elseif sprite:GetNumStates() == 7 then
                    frame = 1
				end
			end

			self:playcommand("Reset")
			sprite:visible(true):setstate(frame)
			
			local wild = 1
			local ez = 0
			
			sprite:zoom(0.8*wild):decelerate(0.1):zoom(0.75*wild):sleep(0.6):accelerate(0.2):zoom(ez)
		else
			local mode = useitg and "ITG" or "Waterfall"
			local ind = ToEnumShortString(TNSToUse)
			local word = WF.PlainTextJudgmentNames[mode][ind]
			if not word then return end
			self:playcommand("Reset")
			local cind = ind ~= "Miss" and tonumber(ind:sub(-1)) or 6
			text:settext(word)
			if threshold > 0 and ind == "W1" and math.abs(TNO) > threshold then
				text:diffuse(Color.White)
			else
				text:diffuse(SL.JudgmentColors[mode][cind])
			end
			text:visible(true)
			local bz = WF.PlainTextJudgmentBaseZoom
			local ez = 0
			text:zoom(0.8*bz):decelerate(0.1):zoom(0.75*bz):sleep(0.6):accelerate(0.2):zoom(ez)
		end

	end,
	
	Def.Sprite{
		Name="JudgmentWithOffsets",
		InitCommand=function(self)
			self:animate(false):visible(false)

			if string.match(tostring(SCREENMAN:GetTopScreen()), "ScreenEdit") then
				self:Load(THEME:GetPathG("", "_judgments/Optimus Dark"))
			elseif file_to_load ~= "Plain Text" then
				self:Load(THEME:GetPathG("", "_judgments/" .. file_to_load))
			end
		end,
		ResetCommand=function(self) self:finishtweening():stopeffect():visible(false) end
	}
}

if usetext then
	af[#af+1] = LoadFont(WF.PlainTextJudgmentFont)..{
		Name = "PlainTextJudgment",
		InitCommand = function(self)
			self:visible(false)
		end,
		ResetCommand = function(self)
			self:finishtweening():stopeffect():visible(false)
		end
	}
end

return af
