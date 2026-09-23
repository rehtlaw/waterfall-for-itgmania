local tweentime = 0.325
local check

return Def.ActorFrame{
	InitCommand=function(self)
		self:Center():draworder(101)
	end,
	OffCommand=function(self)
		-- by the time this screen's OffCommand is called, player mods should already have been read from file
		-- and applied to the SL[pn].ActiveModifiers table, so it is now safe to call ApplyMods() on any human players
		for player in ivalues(GAMESTATE:GetHumanPlayers()) do
			ApplyMods(player)
		end
	end,

	Def.Quad{
		Name="FadeToBlack",
		InitCommand=function(self)
			self:horizalign(right):vertalign(bottom):FullScreen()
			self:diffuse( Color.Black ):diffusealpha(0)
		end,
		OnCommand=function(self)
			self:sleep(tweentime):linear(tweentime):diffusealpha(1)
		end
	},

	Def.Quad{
		Name="HorizontalWhiteSwoosh",
		InitCommand=function(self)
			self:horizalign(center):vertalign(middle)
				:diffuse( Color.White )
				:zoomto(_screen.w + 100,50):faderight(0.1):fadeleft(0.1):cropright(1)
		end,
		OnCommand=function(self)
			self:linear(tweentime):cropright(0):sleep(tweentime)
			self:linear(tweentime):cropleft(1)
			self:sleep(0.1):queuecommand("Load")
		end,
		LoadCommand=function(self)
			SCREENMAN:GetTopScreen():Continue()
		end
	},

	Def.BitmapText{
		Font="raxye/_main",
		Text=THEME:GetString("ScreenProfileLoad","Loading Profiles..."),
		InitCommand=function(self)
			self:diffuse( Color.Black ):zoom(0.4):y(-5)
		end
	},

	-- Message indicating stuff is being imported
	--[[ should not need this anymore
	LoadFont("Common Normal")..{
		Name = "ImportMessage",
		Text = "",
		InitCommand = function(self)
			self:y(96):diffusealpha(0)
		end,
		ShowCommand = function(self, param)
			local t = "Importing stats for the following profiles:"
			for i = 1, 2 do
				if param[i] then t = t.."\nPlayer "..i end
			end
			if param[3] then t = t.."\nMachine Profile" end
			t = t.."\nThis may take a few minutes, but will only happen once per profile."
			Trace(string.format("CHECK TABLE %s %s %s", tostring(param[1]),tostring(param[2]),tostring(param[3])))
			self:settext(t)
			self:linear(0.05):diffusealpha(1)
		end,
		HideCommand = function(self)
			self:linear(0.05):diffusealpha(0)
		end,
		FallbackCommand = function(self)
			self:settext("If this screen seems to hang, profile stats are being imported.\n"..
			"This may take a few minutes, but will only happen once per profile.")
			self:linear(0.05):diffusealpha(1)
		end
	}
	]]
}
