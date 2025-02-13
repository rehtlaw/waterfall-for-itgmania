local player = ...
local pn = ToEnumShortString(player)

-- for some reason Kerpa wants the density graph at the top despite playing reverse. It's kinda weird.
-- I'll add it as an option if other people ask for it.
-- In the meantime, hi Kerpa! Enjoy your easter egg :)

local isKerpa = false 
local profilename = PROFILEMAN:GetPlayerName(pn)
if profilename == "Kerpa" then isKerpa = true end


if not SL[pn].ActiveModifiers.NPSGraphAtTop then
	return
end

local styletype = ToEnumShortString(GAMESTATE:GetCurrentStyle():GetStyleType())
local width = GetNotefieldWidth() - 30
local height = 30

-- support double, double8, and routine by constraining the UpperNPSGraph to have the same width as in single
if styletype == "OnePlayerTwoSides" or styletype == "TwoPlayersSharedSides" then
	width = width/2
end

local song_percent, first_second, last_second

local ystart = 71
if GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred"):UsingReverse() and not isKerpa then
	ystart = SCREEN_HEIGHT - 71 + height + 12
end

return Def.ActorFrame{
	InitCommand=function(self)
		self:y(ystart)
		if PREFSMAN:GetPreference("Center1Player") and #GAMESTATE:GetHumanPlayers()==1 then
			self:x(_screen.cx - width/2)
		else
			self:x((player==PLAYER_1 and WideScale(50, 105)) or _screen.cx+WideScale(45, 95))
		end
	end,
	-- called at the start of each new song in CourseMode, and once at the start of regular gameplay
	CurrentSongChangedMessageCommand=function(self)
		local song = GAMESTATE:GetCurrentSong()
		first_second = math.min(song:GetTimingData():GetElapsedTimeFromBeat(0), 0)
		last_second = song:GetLastSecond()

		self:queuecommand("Size")
	end,

	Def.Quad{ InitCommand=function(self) self:setsize(width, height):diffuse(color("#1E282F")):align(0,1) end },

	NPS_Histogram(player, width, height)..{
		SizeCommand=function(self)
			self:zoomtoheight(1)

			if #GAMESTATE:GetHumanPlayers()==2 and SL.P1.ActiveModifiers.NPSGraphAtTop and SL.P2.ActiveModifiers.NPSGraphAtTop then
				local my_peak = GAMESTATE:Env()[pn.."PeakNPS"]
				local their_peak = GAMESTATE:Env()[ToEnumShortString(OtherPlayer[player]).."PeakNPS"]

				if my_peak < their_peak then
					self:zoomtoheight(my_peak/their_peak)
				end
			end
		end
	},

	Def.Quad{
		Name="ProgressQuad",
		InitCommand=function(self)
			self:setsize(width, height)
				:align(0,1)
				:diffuse(0,0,0,0.85)
				:queuecommand("Update")
		end,
		UpdateCommand=function(self)
			song_percent = scale( GAMESTATE:GetCurMusicSeconds(), first_second, last_second, 0, width )
			self:zoomtowidth(clamp(song_percent, 0, width)):sleep(0.25):queuecommand("Update")
		end,
		CurrentSongChangedMessageCommand=function(self) self:zoomto(0, height) end
	}
}
