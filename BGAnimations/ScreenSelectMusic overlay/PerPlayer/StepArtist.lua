local player = ...
local pn = ToEnumShortString(player)
local p = PlayerNumber:Reverse()[player]

local infowidth = WideScale(310, 318)
local infoheight = 15
local iconsize = 42
local graphwidth = infowidth - iconsize
local p1x = _screen.cx - (IsUsingWideScreen() and 337 or 327)
local p2x = _screen.cx - (IsUsingWideScreen() and 337 or 327) + 1
local p1y = _screen.cy - 9 + infoheight
local p2y = p1y + iconsize + infoheight * 3 + 1

local amvw = infowidth
local amvrh = infoheight
local amvc1 = {0,0,0,0.8}
local amvc2 = {0.1,0.1,0.1,0.8}

-- i'm eventually going to rebuild the song menu so making this look nice for courses is probably
-- not worth it for now
if GAMESTATE:IsCourseMode() then return end

local af = Def.ActorFrame{
	Name="StepArtistAF_" .. pn,

	-- song and course changes
	OnCommand=function(self) self:queuecommand("Reset")  end,
	["CurrentSteps"..pn.."ChangedMessageCommand"]=function(self) self:queuecommand("Reset") end,
	CurrentSongChangedMessageCommand=function(self) self:queuecommand("Reset") end,
	CurrentCourseChangedMessageCommand=function(self) self:queuecommand("Reset") end,

	PlayerJoinedMessageCommand=function(self, params)
		self:queuecommand("Reset")
		if params.Player == player then
			self:queuecommand("Appear" .. pn)
		end
	end,

	-- Simply Love doesn't support player unjoining (that I'm aware of!) but this
	-- animation is left here as a reminder to a future me to maybe look into it.
	PlayerUnjoinedMessageCommand=function(self, params)
		if params.Player == player then
			self:diffusealpha(0)
		end
	end,

	-- depending on the value of pn, this will either become
	-- an AppearP1Command or an AppearP2Command when the screen initializes
	["Appear"..pn.."Command"]=function(self) self:visible(true)
		:y(player == PLAYER_1 and (p1y) or (p2y)) end,

	InitCommand=function(self)
		self:visible( false ):halign( p )

		if player == PLAYER_1 then

			self:y(p1y)
			self:x(p1x)

		elseif player == PLAYER_2 then

			self:y(p2y)
			self:x(p2x)
		end

		if GAMESTATE:IsHumanPlayer(player) then
			self:queuecommand("Appear" .. pn)
		end
	end,

	-- chart info

	Def.ActorFrame{
		InitCommand = function(self) self:xy(7, 10 - infoheight*3) end,
		ResetCommand = function(self)
			local songorcourse = (not GAMESTATE:IsCourseMode())
				and GAMESTATE:GetCurrentSteps(player) or GAMESTATE:GetCurrentTrail(player)
			local ctable
			if songorcourse then ctable = GetStepsCredit(player) end
			self:playcommand("SetCreditText", ctable)
		end,

		Def.ActorMultiVertex{
			InitCommand = function(self)
				self:SetDrawState({Mode="DrawMode_Quads"})
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
		},

		LoadFont("Common Normal")..{
			InitCommand = function(self) self:xy(2, 7):horizalign("left"):zoom(0.7):maxwidth((infowidth-4)/0.7) end,
			SetCreditTextCommand = function(self, ct)
				self:settext("")
				if (not ct) or (not ct[3]) then return end
				local songname = GAMESTATE:GetCurrentSong(player)
				if songname ~= nil then self:settext(ct[3])
				else self:settext("")
				end
			end,
			SetTechTextMessageCommand = function(self, arg)
				if arg.PlayerNumber == player then self:visible(false) end
			end,
			SetInfoTextMessageCommand = function(self, arg)
				if arg.PlayerNumber == player then self:visible(true) end
			end
		},

		LoadFont("Common Normal")..{
			InitCommand = function(self) self:xy(2, 22):horizalign("left"):zoom(0.7):maxwidth((infowidth-4)/0.7) end,
			SetCreditTextCommand = function(self, ct)
				self:settext("")
				if (not ct) or (not ct[2]) then return end
				--self:settext(ct[2])
				local songname = GAMESTATE:GetCurrentSong(player)
				if songname ~= nil then self:settext(ct[2])
				else self:settext("")
				end
			end,
			SetTechTextMessageCommand = function(self, arg)
				if arg.PlayerNumber == player then self:visible(false) end
			end,
			SetInfoTextMessageCommand = function(self, arg)
				if arg.PlayerNumber == player then self:visible(true) end
			end
		},

		LoadFont("Common Normal")..{
			InitCommand = function(self) self:xy(2, 37):horizalign("left"):zoom(0.7):maxwidth((infowidth-4)/0.7) end,
			SetCreditTextCommand = function(self, ct)
				self:settext("")
				if (not ct) or (not ct[1]) then return end
				--self:settext(ct[1])
				local songname = GAMESTATE:GetCurrentSong(player)
				if songname ~= nil then self:settext(ct[1])
				else self:settext("")
				end
			end,
			SetTechTextMessageCommand = function(self, arg)
				if arg.PlayerNumber == player then self:visible(false) end
			end,
			SetInfoTextMessageCommand = function(self, arg)
				if arg.PlayerNumber == player then self:visible(true) end
			end
		}
	},

	-- chart difficulty icon
	Def.ActorFrame{
		Name = "DifficultyIcon",
		InitCommand = function(self) self:xy((player == PLAYER_1 and 0 or graphwidth) + 28, 31) end,
		Def.Quad{
			InitCommand = function(self) self:diffuse(0,0,0,1):zoom(iconsize) end
		},
		Def.Quad{
			InitCommand = function(self) self:zoom(iconsize - 4):queuecommand("Reset") end,
			ResetCommand = function(self)
				local SongOrCourse = (GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse()) or GAMESTATE:GetCurrentSong()
				local StepsOrTrail = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)
				if not SongOrCourse then self:diffuse(Color.Black) return end
				if StepsOrTrail then self:diffuse(DifficultyColor(StepsOrTrail:GetDifficulty())) end
			end
		},
		LoadFont("Common Normal")..{
			Name = "DifficultyName",
			InitCommand = function(self) self:xy(-18,-18):horizalign("left"):vertalign("top"):zoom(0.65):diffuse(Color.Black):queuecommand("Set") end,
			ResetCommand = function(self)
				local StepsOrTrail = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)
				if StepsOrTrail then
					local diff = ToEnumShortString(StepsOrTrail:GetDifficulty())
					self:settext(THEME:GetString("Difficulty", diff))
				end
			end
		},
		LoadFont("_wendy small")..{
			Name="DifficultyMeter",
			InitCommand=function(self) self:horizalign(right):diffuse(Color.Black):zoom(0.6):xy(19,5):queuecommand("Reset") end,
			ResetCommand=function(self)
				local SongOrCourse = (GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse()) or GAMESTATE:GetCurrentSong()
				if not SongOrCourse then self:settext(""); return end

				local StepsOrTrail = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)
				local meter = StepsOrTrail and StepsOrTrail:GetMeter() or "?"
				self:settext( meter )
			end
		}
	},

	-- density graph
	Def.Quad{
		InitCommand = function(self)
			self:xy((player == PLAYER_1 and iconsize or 0) + 7, 10):horizalign("left"):vertalign("top")
			:zoomto(graphwidth, iconsize):diffuse(0.2,0.2,0.2,1)
		end
	},
	MusicWheel_NPS_Histogram(player, graphwidth, iconsize)..{
		OnCommand = function(self)
			self:xy((player == PLAYER_1 and iconsize or 0) + 7, 52)
		end,
		ResetCommand = function(self)
			self:xy((player == PLAYER_1 and iconsize or 0) + 7, 52)
		end
	},

    -- Peak NPS/eBPM
    Def.ActorFrame{
        LoadFont("Common Normal")..{
            Name = "NPS",
            Text = "",
            InitCommand = function(self)
                self:zoom(0.7)
                self:settext("Peak NPS: \nPeak eBPM: ")
                self:horizalign(left)
                self:y(-5)
                self:x(250)
                self:visible(true)
            end,
            HideCommand = function(self)
                self:settext("Peak NPS: \nPeak eBPM: ")
                self:visible(false)
            end,
            PeakNPSUpdatedMessageCommand = function(self)
                if SL[pn].Streams.PeakNPS ~= nil then
                    local nps = SL[pn].Streams.PeakNPS * SL.Global.ActiveModifiers.MusicRate
                    self:horizalign("left")
                    self:y(-5)
                    self:x(250)
                    self:settext(("Peak NPS: %.1f\nPeak eBPM: %.0f"):format(nps, nps * 15))
                    self:visible(true)
                end
            end,
            SetTechTextMessageCommand = function(self, arg)
                if arg.PlayerNumber == player then self:visible(false) end
            end,
            SetInfoTextMessageCommand = function(self, arg)
                if arg.PlayerNumber == player then self:visible(true) end
            end,
            OffCommand = function(self)
                leaving_screen = true
                self:stoptweening()
            end,
        }
    },

	-- conditional quad with breakdown at the bottom of density graph
	-- put it underneath for single player, but bump it up in multiplayer
	Def.ActorFrame{
		InitCommand = function(self)
			self:xy((player == PLAYER_1 and iconsize or 0) + 7, 52)
			if #GAMESTATE:GetHumanPlayers() == 2 then self:y(37):diffusealpha(0.8) end
		end,
		ResetCommand = function(self)
			if #GAMESTATE:GetHumanPlayers() == 2 then self:y(37):diffusealpha(0.8) end
			self:visible(false)
		end,
		["StreamsChanged"..pn.."MessageCommand"] = function(self)
			if not GAMESTATE:IsHumanPlayer(player) then return end
			local bdstr = GenerateBreakdownText(pn, 0)
			if bdstr == "No Streams!" then return end
			self:playcommand("SetBD", {bdstr}):visible(true)
		end,

		Def.Quad{
			InitCommand = function(self) self:zoomto(graphwidth, infoheight):diffuse(0,0,0,0.7)
				:horizalign("left"):vertalign("top") end
		},
		LoadFont("Common Normal")..{
			Text = "",
			InitCommand = function(self) self:xy(2, 7):horizalign("left"):zoom(0.7):maxwidth((graphwidth-4)/0.7) end,
			SetBDCommand = function(self, bd)
				self:settext(bd and bd[1])
				local minlevel = 1
				while self:GetWidth() > (graphwidth-4)/0.7 and minlevel < 4 do
					self:settext(GenerateBreakdownText(pn, minlevel))
					minlevel = minlevel + 1
				end
			end
		}
	}
}

-- tech info. show all the time for 1 player, make visible when select held for 2 player
local techaf = Def.ActorFrame{
	InitCommand = function(self)
		self:x((player == PLAYER_1 and iconsize or 0) + 7)
		self:y((player == PLAYER_1 and (p2y-p1y+18) or (p1y-p2y+iconsize)) - infoheight*2.5)
		if #GAMESTATE:GetHumanPlayers() == 2 then self:visible(false) end
	end,
	["StreamsChanged"..pn.."MessageCommand"] = function(self)
		self:playcommand("SetTech")
	end,
	SetTechTextMessageCommand = function(self, arg)
		if arg.PlayerNumber == player then self:visible(true) end
	end,
	SetInfoTextMessageCommand = function(self, arg)
		if arg.PlayerNumber == player then self:visible(false) end
	end,
	ResetCommand = function(self)
		if #GAMESTATE:GetHumanPlayers() == 2 then
			self:xy(7, 10 - infoheight*3)
			self:visible(false)
		end
	end,

	Def.Quad{
		InitCommand = function(self)
			self:zoomto(graphwidth, infoheight*3):horizalign("left"):vertalign("top"):diffuse(0,0,0,0.7)
			if #GAMESTATE:GetHumanPlayers() == 2 then self:visible(false) end
		end,
		ResetCommand = function(self)
			if #GAMESTATE:GetHumanPlayers() == 2 then self:visible(false) end
		end
	}
}

-- grid
local griditems = {"Crossovers", "Footswitches", "Sideswitches", "Jacks", "Brackets"}
local gridpos = {{32, 7}, {graphwidth/1.5, 7}, {32, 22}, {graphwidth/1.5, 22}, {32, 37}}

-- Original thing
for i, name in ipairs(griditems) do
	-- number text
	techaf[#techaf+1] = LoadFont("Common Normal")..{
		Text = "",
		InitCommand = function(self)
			self:xy(gridpos[i][1], gridpos[i][2]):horizalign("right"):zoom(0.7):maxwidth(30/0.7)
		end,
		ResetCommand = function(self) self:settext("") end,
		SetTechCommand = function(self)
			self:settext(tostring(SL[pn].Streams[name]))
		end
	}

	-- name text
	techaf[#techaf+1] = LoadFont("Common Normal")..{
		Text = name,
		InitCommand = function(self)
			self:xy(gridpos[i][1] + 4, gridpos[i][2]):horizalign("left"):zoom(0.7)
		end
	}
end

techaf[#techaf+1] = LoadFont("Common normal")..{
	Text="Total Stream",
	Name="Value",
	InitCommand=function(self)
		local textHeight = 17
		local textZoom = 0.8
		self:zoom(textZoom):horizalign(right)
		self:maxwidth(100)
		self:xy(graphwidth/1.5,37):horizalign("right"):zoom(0.7):maxwidth(80/0.7)
	end,
	ResetCommand = function(self) self:settext("") end,
	SetTechCommand = function(self)
			if not GAMESTATE:IsPlayerEnabled(player) then self:settext("0")
			else
				local streamMeasures, breakMeasures = GetTotalStreamAndBreakMeasures(pn)
				local totalMeasures = streamMeasures + breakMeasures
				if streamMeasures == 0 then
					self:settext("None (0.00%)")
				else
					self:settext(string.format("%d/%d (%0.1f%%)", streamMeasures, totalMeasures, streamMeasures/totalMeasures*100))
				end					
			end
	end
}

techaf[#techaf+1] = LoadFont("Common Normal")..{
	Text="Total Stream",
	Name="Value",
	InitCommand=function(self)
		local textHeight = 17
		local textZoom = 0.8
		self:maxwidth(graphwidth/textZoom):zoom(textZoom):horizalign(left)
		self:xy(graphwidth/1.5 + 4, 37):horizalign("left"):zoom(0.7)
		self:settext("Total Stream")
	end,
}

af[#af+1] = techaf

return af
