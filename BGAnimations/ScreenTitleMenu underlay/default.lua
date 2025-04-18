local TextColor = Color.White

songsRandNum = math.random(6)

-- generate a string like "7741 songs in 69 groups, 10 courses"
local SongStats = ("%i %s %i %s, %i %s"):format(
	SONGMAN:GetNumSongs(),
	THEME:GetString("ScreenTitleMenu", "songs in"),
	SONGMAN:GetNumSongGroups(),
	THEME:GetString("ScreenTitleMenu", "groups"),
	#SONGMAN:GetAllCourses(PREFSMAN:GetPreference("AutogenGroupCourses")),
	THEME:GetString("ScreenTitleMenu", "courses")
)

-- - - - - - - - - - - - - - - - - - - - -
local game = GAMESTATE:GetCurrentGame():GetName();
if game ~= "dance" and game ~= "pump" then
	game = "techno"
end

-- - - - - - - - - - - - - - - - - - - - -
-- People commonly have multiple copies of SL installed – sometimes different forks with unique features
-- sometimes due to concern that an update will cause them to lose data, sometimes accidentally, etc.

-- It is important to display the current theme's name to help users quickly assess what version of SL
-- they are using right now.  THEME:GetCurThemeName() provides the name of the theme folder from the
-- filesystem, so we'll show that.  It is guaranteed to be unique and users are likely to recognize it.
local sl_name = THEME:GetCurThemeName()

-- - - - - - - - - - - - - - - - - - - - -
-- ProductFamily() returns "StepMania"
-- ProductVersion() returns the (stringified) version number (like "5.0.12" or "5.1.0")
-- so, start with a string like "StepMania 5.0.12" or "StepMania 5.1.0"
local sm_version = ("%s %s"):format(ProductFamily(), ProductVersion())

-- GetThemeVersion() is defined in ./Scripts/SL-Helpers.lua and returns the SL version from ThemeInfo.ini
local sl_version = GetThemeVersion()

-- "git" appears in ProductVersion() for non-release builds of StepMania.
-- If a non-release executable is being used, append date information about when it
-- was built to potentially help non-technical cabinet owners submit bug reports.
if ProductVersion():find("git") then
	local date = VersionDate()
	local year = date:sub(1,4)
	local month = date:sub(5,6)
	if month:sub(1,1) == "0" then month = month:gsub("0", "") end
	month = THEME:GetString("Months", "Month"..month)
	local day = date:sub(7,8)

	sm_version = ("%s, Built %s %s %s"):format(sm_version, day, month, year)
end

-- - - - - - - - - - - - - - - - - - - - -

local af = Def.ActorFrame{
	Name="GameInfo",
	InitCommand=function(self)
		--see: ./Scripts/SL_Init.lua
		InitializeSimplyLove()

		self:Center()
	end,
	OffCommand=function(self) self:linear(0.5):diffusealpha(0) end,
}

local InputHandler = function( event )

	-- if (somehow) there's no event, bail
	if not event then return end

	if event.type == "InputEventType_FirstPress" then

		Trace(event.DeviceInput.button)

		if event.DeviceInput.button == "DeviceButton_1" then
			SCREENMAN:SetNewScreen("ScreenTestReflex")
		elseif event.DeviceInput.button == "DeviceButton_2" then
			SCREENMAN:SetNewScreen("ScreenTestReflex2")
		end

	end

end

af[#af+1] = Def.Actor {
	OnCommand=function()
		local screen = SCREENMAN:GetTopScreen()
		screen:AddInputCallback( InputHandler )
	end
}

-- WF logo
af[#af+1] = LoadActor(THEME:GetPathG("", "_logos/WFLogo.png"))..{
	InitCommand=function(self) self:y(-80):zoom((SCREEN_WIDTH*2/3)/1486):shadowlength(0.75) end,
	OffCommand=function(self) self:linear(0.5):shadowlength(0) end
}

-- SM version, SL version, song stats
af[#af+1] = Def.ActorFrame{
	InitCommand=function(self) self:zoom(0.8):xy(-132, -144):diffusealpha(0) end,
	OnCommand=function(self) self:sleep(0.2):linear(0.4):diffusealpha(1) end,

	LoadFont("Common Normal")..{
		Text=sm_version .. "       " .. sl_name .. (sl_version and (" v" .. sl_version) or ""),
		InitCommand=function(self) self:y(-20):diffuse(TextColor):maxwidth(240) end,
	},
	LoadFont("Common Normal")..{
		Text=SongStats,
		InitCommand=function(self) self:diffuse(TextColor) end,
	}
}

-- backing quad for menu
af[#af+1] = Def.Quad{
	InitCommand = function(self)
		if IsArcade() then self:visible(false) end
		self:y(_screen.h/3.8):zoomto(180, 120):diffuse(0,0,0,0.8)
	end
}

-- always reset player profile stuff here
WF.InitPlayerProfiles()

return af
