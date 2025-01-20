-- this difficulty grid doesn't support CourseMode
-- CourseContentsList.lua should be used instead
if GAMESTATE:IsCourseMode() then return end
-- ----------------------------------------------

local num_icons = 5

local GetStepsToDisplay = LoadActor("./StepsToDisplay.lua")

local iconw = 30
local iconh = 30

local t = Def.ActorFrame{
	Name="StepsDisplayList",
	InitCommand=function(self)
		self:xy(_screen.cx - 146, _screen.cy + 178) -- 178
		self:rotationz(270)
		self:zoomto(1.8, 1.8)
	end,

	OnCommand=function(self) self:queuecommand("RedrawStepsDisplay") end,
	CurrentSongChangedMessageCommand=function(self)    self:queuecommand("RedrawStepsDisplay") end,
	CurrentStepsP1ChangedMessageCommand=function(self) self:queuecommand("RedrawStepsDisplay") end,
	CurrentStepsP2ChangedMessageCommand=function(self) self:queuecommand("RedrawStepsDisplay") end,

	RedrawStepsDisplayCommand=function(self)

		local song = GAMESTATE:GetCurrentSong()

		if song then
			local steps = SongUtil.GetPlayableSteps( song )

			if steps then
				local StepsToDisplay = GetStepsToDisplay(steps)

				for i=1,num_icons do
					if StepsToDisplay[i] then
						-- if this particular song has a stepchart for this icon, update the Meter
						-- and BlockRow coloring appropriately
						local meter = StepsToDisplay[i]:GetMeter()
						local difficulty = StepsToDisplay[i]:GetDifficulty()
						self:GetChild("Grid"):GetChild("Meter_"..i)
							:playcommand("Set",  {Meter=meter, Difficulty=difficulty})
						self:GetChild("Grid"):GetChild("DiffQuad_"..i)
							:playcommand("Set",  {Meter=meter, Difficulty=difficulty})
						self:GetChild("Grid"):GetChild("CursorP1_"..i)
							:playcommand("Set",  {Meter=meter, Steps=StepsToDisplay[i]})
						self:GetChild("Grid"):GetChild("CursorP2_"..i)
							:playcommand("Set",  {Meter=meter, Steps=StepsToDisplay[i]})

					else
						-- otherwise, set the meter to an empty string and hide this particular colored BlockRow
						self:GetChild("Grid"):GetChild("Meter_"..i):playcommand("Unset")
						self:GetChild("Grid"):GetChild("DiffQuad_"..i):playcommand("Unset")
						self:GetChild("Grid"):GetChild("CursorP1_"..i):playcommand("Unset")
						self:GetChild("Grid"):GetChild("CursorP2_"..i):playcommand("Unset")
					end
				end
			end
		else
			self:playcommand("Unset")
		end
	end,

	-- - - - - - - - - - - - - -

	-- background
	Def.Quad{
		Name="Background",
		InitCommand=function(self)
			self:diffuse(color("#1e282f"))
				:zoomto(iconw + 4, iconh * num_icons + 2 * (num_icons - 1) + 4)
				:vertalign("top")
		end
	},

	-- if an edit exists, show a little arrow icon
	LoadFont("Common Normal")..{
		Name = "EditArrow",
		Text = "^",
		InitCommand = function(self)
			self:y(iconh * num_icons + 2 * (num_icons - 1) + 6)
				:rotationz(180)
				:visible(false)
			end,
		RedrawStepsDisplayCommand = function(self)
			self:visible(false)
			local song = GAMESTATE:GetCurrentSong()
			if not song then return end
			local st = GAMESTATE:GetCurrentStyle():GetStepsType()
			if song:HasEdits(st) then self:visible(true) end
		end
	}
}


local Grid = Def.ActorFrame{
	Name="Grid",
	InitCommand=function(self) end,
}

for IconNumber=1,num_icons do

	-- black background quad for icon
	Grid[#Grid+1] = Def.Quad{
		InitCommand = function(self)
			self:y(IconNumber * (iconh + 2) - iconh/2):zoomto(iconw, iconh):diffuse(Color.Black)
		end
	}
	-- cursors
	for i = 1, 2 do
		Grid[#Grid+1] = Def.Quad{
			Name = "CursorP"..i.."_"..IconNumber,
			InitCommand = function(self)
				self:y(IconNumber * (iconh + 2) - iconh/2)
					:zoomto(iconw/2+2, iconh+2)
					:diffuseshift()
				  :effectcolor1(PlayerColor("PlayerNumber_P"..i))
				  :effectcolor2(Color.White)
				  -- :vertalign(i == 1 and "top" or "bottom")
				  :horizalign(i == 1 and "right" or "left")
					:rotationz(90)
			end,
			SetCommand = function(self, params)
				local player = "PlayerNumber_P"..i
				if not GAMESTATE:IsPlayerEnabled(player) then self:visible(false) end
				local steps = GAMESTATE:GetCurrentSteps(player)
				self:visible(steps == params.Steps)
			end,
			UnsetCommand = function(self)
				self:visible(false)
			end
		}
	end
	-- difficulty colored quad for icon
	Grid[#Grid+1] = Def.Quad{
		Name = "DiffQuad_"..IconNumber,
		InitCommand = function(self)
			self:y(IconNumber * (iconh + 2) - iconh/2):zoomto(iconw - 2, iconh - 2):diffuse(0.6,0.6,0.6,1)
		end,
		SetCommand = function(self, params)
			self:diffuse(DifficultyColor(params.Difficulty))
		end,
		UnsetCommand = function(self)
			self:diffuse(0.6,0.6,0.6,1)
		end
	}
	-- difficulty number
	Grid[#Grid+1] = LoadFont("_wendy small")..{
		Name="Meter_"..IconNumber,
		InitCommand=function(self)
			self:y(IconNumber * (iconh + 2) - iconh/2)
			self:zoom(0.5)
			self:diffuse(0,0,0,1)
			self:rotationz(90)
		end,
		SetCommand=function(self, params)
			self:settext(params.Meter)
		end,
		UnsetCommand=function(self) self:settext("") end
	}
end

t[#t+1] = Grid

return t
