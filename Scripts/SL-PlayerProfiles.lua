-- It's possible for players to edit their Simply Love UserPrefs.ini file
-- in various ways that might break the theme.  Also, sometimes theme-specific mods
-- are deprecated or change their internal name, leaving old values behind in player profiles
-- that might break the theme as well. Use this table to validate settings read in
-- from and written out to player profiles.
--
-- For now, this table is local to this file, but might be moved into the SL table (or something)
-- in the future to facilitate type checking in ./Scripts/SL-PlayerOptions.lua and elsewhere.

local profile_whitelist = {
	SpeedModType = "string",
	SpeedMod = "number",
	Mini = "string",
	NoteSkin = "string",
	JudgmentGraphic = "string",
    HeldGraphic = "string",
	EarlyLate = "string",
	EarlyLateColor = "string",
	BackgroundFilter = "string",
	NoteFieldOffsetX = "number",
	NoteFieldOffsetY = "number",
    VisualDelay = "string",

	HideTargets = "boolean",
	HideSongBG = "boolean",
	HideCombo = "boolean",
	HideLifebar = "boolean",
	HideScore = "boolean",
	HideDanger = "boolean",

	LifeMeterType = "string",
	DataVisualizations = "string",
	--TargetScore = "number",
	--ActionOnMissedTarget = "string",

	MeasureCounter = "string",
	MeasureCounterLeft = "boolean",
	MeasureCounterUp = "boolean",
	HideLookahead = "boolean",

    MeasureLines = "string",

	ColumnFlashOnMiss = "boolean",
	SubtractiveScoring = "string",
	SubtractiveExtra = "boolean",
	SubtractiveType = "string",
	--MissBecauseHeld = "boolean",
	NPSGraphAtTop = "boolean",

    ErrorBarCap = "number",

	ReceptorArrowsPosition = "string",

	PlayerOptionsString = "string",

	-- waterfall/bistro
	PreferredLifeBar = "string",
	EarlyLateThreshold = "string",
	FAPlus = "number",
	ProfileCardInfo = "string",
	PreferredSecondPane = "string",
	PreferredGraph = "string",
	PreferredSecondGraph = "string",
	PreferredGameEnv = "string",
	PreferredFaultWindow = "number",
	GSOverride = "boolean",
    AlwaysGS = "boolean",

	-- Waterfall expanded stuff
	catJAM = "boolean",
	StepInfo = "boolean",
	Groovestats = "boolean",
	TimeElapsed = "boolean",

	GIF = "string",
	GIFResponsive = "boolean",
	GIFDVD = "boolean",
	GIFRandom = "boolean",

	ComboEffectsWild = "boolean",
	ComboEffectsNice = "boolean",

	ComboStretchHorizontal = "boolean",
	ComboStretchVertical = "boolean",
	ComboStretchGrow = "boolean",
	ComboStretchRandom = "boolean",
	
	ComboRotation = "string",
	ComboRainbow = "string",
	
	NiceSoundCombo = "boolean",
	NiceSoundJudgements = "boolean",
	
	JudgementTilt = "boolean",
    JudgementTiltMultiplier = "number",
	
	MeasureCounterLookahead = "number",
	
	FailNotification = "boolean",
	PacemakerText = "string",
	ScreenDarken = "number",
	
	EXScoring = "boolean",
	SubtractiveEnvironment = "string",
	ColumnCues = "boolean",
    ColumnCountdown = "boolean",
	OffsetDisplay = "boolean",

}

local blacklist = {
	"NoFakes","NoHands","NoHolds","NoJumps","NoLifts","NoQuads","NoRolls","NoStretch","Little","Mines",
	"Planted","Quick","Stomp","Skippy"
}

-- ------------------------------------------

local theme_name = THEME:GetThemeDisplayName()
local filename =  theme_name .. " UserPrefs.ini"

-- function assigned to "CustomLoadFunction" under [Profile] in metrics.ini
LoadProfileCustom = function(profile, dir)

	-- hack thing
	if WF.SwitchPrefixFlag then return true end

	local path =  dir .. filename
	local player, pn, filecontents

	-- we've been passed a profile object as the variable "profile"
	-- see if it matches against anything returned by PROFILEMAN:GetProfile(player)
	for p in ivalues( GAMESTATE:GetHumanPlayers() ) do
		if profile == PROFILEMAN:GetProfile(p) then
			player = p
			pn = ToEnumShortString(p)
			break
		end
	end

	if pn and FILEMAN:DoesFileExist(path) then
		filecontents = IniFile.ReadFile(path)[theme_name]

		-- for each key/value pair read in from the player's profile
		for k,v in pairs(filecontents) do
			-- ensure that the key has a corresponding key in profile_whitelist
			if profile_whitelist[k]
			--  ensure that the datatype of the value matches the datatype specified in profile_whitelist
			and type(v)==profile_whitelist[k] then
				-- if the datatype is string and this key corresponds with an OptionRow in ScreenPlayerOptions
				-- ensure that the string read in from the player's profile
				-- is a valid value (or choice) for the corresponding OptionRow
				if type(v) == "string" and CustomOptionRow(k) and FindInTable(v, CustomOptionRow(k).Values or CustomOptionRow(k).Choices)
				or type(v) ~= "string" then
					SL[pn].ActiveModifiers[k] = v
				end

				-- special-case PlayerOptionsString for now
				-- it is saved to and read from profile as a string, but doesn't have a corresponding
				-- OptionRow in ScreenPlayerOptions, so it will fail validation above
				-- we want engine-defined mods (e.g. dizzy) to be applied as well, not just SL-defined mods
				if k=="PlayerOptionsString" and type(v)=="string" then
					-- v here is the comma-delimited set of modifiers the engine's PlayerOptions interface understands

					-- update the SL table so that this PlayerOptionsString value is easily accessible throughout the theme
					SL[pn].PlayerOptionsString = v

					-- use the engine's SetPlayerOptions() method to set a whole bunch of mods in the engine all at once
					GAMESTATE:GetPlayerState(player):SetPlayerOptions("ModsLevel_Preferred", v)

					-- turn off bad mods that might have carried over from another theme
					local mods = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
					for m in ivalues(blacklist) do
						mods[m](mods, false)
					end
					SL[pn].PlayerOptionsString = GAMESTATE:GetPlayerState(player):GetPlayerOptionsString("ModsLevel_Preferred")

					-- However! It's quite likely that a FailType mod could be in that^ string, meaning a player could
					-- have their own setting for FailType saved to their profile.  I think it makes more sense to allow
					-- machine operators specify a default FailType at a global/machine level, so use this opportunity to
					-- use the PlayerOptions interface to set FailSetting() using the default FailType setting from
					-- the operator menu's Advanced Options
					GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred"):FailSetting( GetDefaultFailType() )
				end
			end
		end
	end

	return true
end

-- function assigned to "CustomSaveFunction" under [Profile] in metrics.ini
SaveProfileCustom = function(profile, dir)

	-- hack thing
	if WF.SwitchPrefixFlag then return true end
	
	local path =  dir .. filename
	local machine = true

	for player in ivalues( GAMESTATE:GetHumanPlayers() ) do
		if profile == PROFILEMAN:GetProfile(player) then
			local pn = ToEnumShortString(player)
			local output = {}
			for k,v in pairs(SL[pn].ActiveModifiers) do
				if profile_whitelist[k] and type(v)==profile_whitelist[k] then
					output[k] = v
				end
			end

			-- PlayerOptionsString is saved outside the SL[pn].ActiveModifiers tables
			-- and thus won't be handled in the loop above
			output.PlayerOptionsString = SL[pn].PlayerOptionsString

			IniFile.WriteFile( path, {[theme_name]=output} )
			
			WF.SavePlayerProfileStats(tonumber(pn:sub(-1)))
			machine = false
			break
		end
	end

	if machine then
		WF.SaveMachineProfileStats()
	end

	return true
end
