local player = ...
local pn = PlayerNumber:Reverse()[player]
local infotable = GetStepsCredit(player)
local currentSteps = GAMESTATE:GetCurrentSteps(player)
local doubles = false
local DrawNinePanelPad = LoadActor( THEME:GetPathB("ScreenSelectStyle", "underlay/pad.lua") )

--determine 1 or 2 player mode
local style = GAMESTATE:GetCurrentStyle()
local styleType = style:GetStyleType()
if styleType == "StyleType_OnePlayerTwoSides" then doubles = true end

local af = Def.ActorFrame{

	-- all this difficulty icon stuff should probably be in its own lua file, but i'm likely gonna make it
	-- graphical down the line anyway so it probably doesn't matter

	-- outline for diff icon
	Def.Quad{
		InitCommand=function(self)
			self:zoomto(48,48)
			self:y( _screen.cy-48 )
			self:x(126 * (player==PLAYER_1 and -1 or 1))

			if currentSteps then
				local currentDifficulty = currentSteps:GetDifficulty()
				self:diffuse( 0,0,0,1 )
			end
		end
	},

	-- colored square as the background for the difficulty meter
	Def.Quad{
		InitCommand=function(self)
			self:zoomto(44,44)
			self:y( _screen.cy-48 )
			self:x(126 * (player==PLAYER_1 and -1 or 1))

			if currentSteps then
				local currentDifficulty = currentSteps:GetDifficulty()
				self:diffuse( DifficultyColor(currentDifficulty) )
			end
		end
	},

	-- difficulty name
	LoadFont("Common Normal")..{
		Text = "",
		InitCommand = function(self)
			self:x((126 * (player==PLAYER_1 and -1 or 1)) - 20)
			self:y(_screen.cy-68)
			self:horizalign("left")
			self:vertalign("top")
			self:zoom(0.75)
			self:diffuse(0,0,0,1)
			if currentSteps then
				local diff = ToEnumShortString(currentSteps:GetDifficulty())
				self:settext(THEME:GetString("Difficulty", diff))
			end
		end
	},

	-- numerical difficulty meter
	LoadFont("raxye/_numbers")..{
		InitCommand=function(self)
			self:diffuse(Color.Black):zoom( 0.24 )
			self:y( _screen.cy-50 )
			self:x((126 * (player==PLAYER_1 and -1 or 1)) + 20)
			self:horizalign("right")

			local meter
			if GAMESTATE:IsCourseMode() then
				local trail = GAMESTATE:GetCurrentTrail(player)
				if trail then meter = trail:GetMeter() end
			else
				local steps = GAMESTATE:GetCurrentSteps(player)
				if steps then meter = steps:GetMeter() end
			end

			if meter then self:settext(meter) end
		end
	},
}

-- little gradient backing for chart info sections
local amvw = 252
local amvrh = 16
local amvc1 = {0,0,0,0.8}
local amvc2 = {0.1,0.1,0.1,0.8}
af[#af+1] = Def.ActorMultiVertex{
	InitCommand = function(self)
		self:SetDrawState({Mode="DrawMode_Quads"})
			:x(player == PLAYER_1 and -102 or -150)
			:y(_screen.cy-72)
			:SetVertices({
				{{0,0,0},amvc1},
				{{amvw,0,0},amvc1},
				{{amvw,amvrh,0},amvc2},
				{{0,amvrh,0},amvc2},

				{{0,amvrh,0},amvc1},
				{{amvw,amvrh,0},amvc1},
				{{amvw,amvrh*2,0},amvc2},
				{{0,amvrh*2,0},amvc2},

				{{0,amvrh*2,0},amvc1},
				{{amvw,amvrh*2,0},amvc1},
				{{amvw,amvrh*3,0},amvc2},
				{{0,amvrh*3,0},amvc2}
			})
	end
}

-- Doubles mode is not obvious, and not everyone knows about 
-- the top right icon, so make it more obvious
-- Waterfall Expanded 0.7.7	
if doubles then
	-- Background quad
	af[#af+1] = Def.Quad{
		InitCommand=function(self)
			self:zoomto(62,48)
			self:y( _screen.cy-48 )
			self:x(-119 * (player==PLAYER_1 and -1 or 1))
			self:diffuse( 0,0,0,1 )
		end
	}

	-- P1 pad
	af[#af+1] = DrawNinePanelPad()..{
		InitCommand=function(self)
			self:y( _screen.cy-46 )
			self:x((-104 * (player==PLAYER_1 and -1 or 1)))
			self:horizalign("right")
			self:zoom(0.3)
			if doubles then self:playcommand("Set", {Player=PLAYER_1})	end
		end
	}

	-- P2 pad
	af[#af+1] = DrawNinePanelPad()..{
		InitCommand=function(self)
			self:y( _screen.cy-46 )
			self:x((-134 * (player==PLAYER_1 and -1 or 1)))
			self:horizalign("right")
			self:zoom(0.3)
			if doubles then self:playcommand("Set", {Player=PLAYER_2})	end
		end
	}
	
	-- Doubles Text
	af[#af+1] = LoadFont("Common Normal")..{
		Text = "Doubles",
		InitCommand = function(self)
			self:y( _screen.cy-33 )
			self:x((-119 * (player==PLAYER_1 and -1 or 1)))
			self:horizalign("center")
			self:zoom(0.85)
		end
	}

end

-- loop through info table and create texts from bottom to top
for i = #infotable, 1, -1 do
	local text = infotable[i] 

	-- if the song is from the itl 2022 pack display the points earned
	-- only modify the text if we're in the itl 2022 pack
	-- do this by checking if the suffix of any infotable element is " pts" 
	if string.sub(text, string.len(text) - 3, string.len(text)) == " pts" then
		local max_points = string.sub(text, 1, string.len(text) - 4)
		local exscore = tonumber(WF.GetEXScore(player))
		local max_point_multiplier = 0
		if exscore <= 75 then
			max_point_multiplier = math.log(math.min(exscore, 75)+1) / math.log(1.0638215) / 100
		else
			max_point_multiplier = (math.exp(math.log(31) * ((math.max(0, exscore-75)/25))) + 69) / 100 -- nice
		end

		local points = max_point_multiplier * max_points
		points = math.floor(points)
		text = points .. "/" .. text
	end

	af[#af+1] = LoadFont("Common Normal")..{
		Text = text,
		InitCommand = function(self)
			self:y(_screen.cy - 32 - (i-1)*16)
			self:x(98 * (player==PLAYER_1 and -1 or 1))
			self:horizalign(player == PLAYER_1 and "left" or "right")
			self:zoom(0.85)
			-- Reduce the maxwidth if in doubles mode to not overlap the new doubles display
			-- Waterfall Expanded 0.7.7
			self:maxwidth((doubles and 182 or 242)/0.85) 
		end
	}
end

return af
