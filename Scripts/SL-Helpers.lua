-- -----------------------------------------------------------------------
-- NOTE: This is the preferred way to check for RTT support, but we cannot rely on it to
--   accurately tell us whether the current system atually supports RTT!
--   Some players on Linux and [some version of] SM5.1-beta reported that DISPLAY:SupportsRenderToTexture()
--   returned false, when render to texture was definitely working for them.
--   I'm leaving this check here, but commented out, both as "inline instruction" for current SM5 themers
--   and so that it can be easily uncommented and used ~~when we are trees again~~ at a future date.

-- SupportsRenderToTexture = function()
-- 	-- ensure the method exists and, if so, ensure that it returns true
-- 	return DISPLAY.SupportsRenderToTexture and DISPLAY:SupportsRenderToTexture()
-- end


-- -----------------------------------------------------------------------
-- SM5's d3d implementation does not support render to texture. The DISPLAY
-- singleton has a method to check this but it doesn't seem to be implemented
-- in RageDisplay_D3D which is, ironically, where it's most needed.  So, this.

SupportsRenderToTexture = function()
	-- This is not a sensible way to assess this; it is a hack and should be removed at a future date.
	if HOOKS:GetArchName():lower():match("windows")
	and PREFSMAN:GetPreference("VideoRenderers"):sub(1,3):lower() == "d3d" then
		return false
	end

	return true
end

-- -----------------------------------------------------------------------
-- use StepManiaVersionIsSupported() to define supported SM5 versions

--[[
Seems to be stable with 5.3 so far, so I'm allowing it by default now.
]]

VersionNumber=function()
	return ProductID(), ProductVersion()
end

local getProductVersion = function()
  if type(ProductVersion) ~= "function" then
    return {}
  end

  -- get the version string, e.g. "5.0.11" or "5.1.0" or "5.2-git-96f9771" or etc.
  local version = ProductVersion()
  if type(version) ~= "string" then
    return {}
  end

  -- remove the build suffix from the version string
  -- debug build are suffixed with "-git-$something" or "-UNKNOWN" if the
  -- git hash is not available for some reason
  version = version:gsub("-.*", "")

  -- parse the version string into a table
  local v = {}
  for i in version:gmatch("[^%.]+") do
    table.insert(v, tonumber(i))
  end

  return v
end

function IsMinimumProductVersion(...)
  local version = getProductVersion()

  for i = 1, select("#", ...) do
    local n = select(i, ...)
    if not version[i] or version[i] < n then
      return false
    elseif version[i] > n then
      return true
    end
  end

  return true
end

StepManiaVersionIsSupported = function()
	--SM(ProductID())
    -- outfox renamed away from 5.3 as of v0.4.14, if productID contains outfox we know it has full support
	if type(ProductID) == "function" and ProductID():find("ITGmania") then 
        return IsMinimumProductVersion(1, 0, 1)
    end
end

-- -----------------------------------------------------------------------
-- game types like "kickbox" and "lights" aren't supported in Simply Love, so we
-- use this function to hardcode a list of game modes that are supported, and use it
-- in ScreenInit overlay.lua to redirect players to ScreenSelectGame if necessary.
--
-- (Because so many people have accidentally gotten themselves into lights mode without
-- having any idea they'd done so, and have then messaged me saying the theme was broken.)

CurrentGameIsSupported = function()
	-- a hardcoded list of games that this theme supports
	local support = {
		dance  = true,
		pump   = true,
		techno = false,
		para   = false,
		kb7    = false
	}
	-- return true or nil
	return support[GAMESTATE:GetCurrentGame():GetName()]
end

-- -----------------------------------------------------------------------
-- There's surely a better way to do this.  I need to research this more.

local is8bit = function(text)
	return text:len() == text:utf8len()
end


-- Here's what inline comments in BitmapText.cpp currently have to say about wrapwidthpixels
------
-- // Break sText into lines that don't exceed iWrapWidthPixels. (if only
-- // one word fits on the line, it may be larger than iWrapWidthPixels).
--
-- // This does not work in all languages:
-- /* "...I can add Japanese wrapping, at least. We could handle hyphens
-- * and soft hyphens and pretty easily, too." -glenn */
------
--
-- So, wrapwidthpixels does not have great support for East Asian Languages.
-- Without whitespace characters to break on, the text just... never wraps.  Neat.
--
-- Here are glenn's thoughts on the topic as of June 2019:
------
-- For Japanese specifically I'd convert the string to WString (so each character is one character),
-- then make it split "words" (potential word wrap points) based on each character type.  If you
-- were splitting "text あああ", it would split into "text " (including the space), "あ", "あ", "あ",
-- using a mapping to know which language each character is.  Then just follow the same line fitting
-- and recombine without reinserting spaces (since they're included in the array).
--
-- It wouldn't be great, you could end up with things like periods being wrapped onto a line by
-- themselves, ugly single-character lines, etc.  There are more involved language-specific word
-- wrapping algorithms that'll do a better job:
-- ( https://en.wikipedia.org/wiki/Line_breaking_rules_in_East_Asian_languages ),
-- or a line balancing algorithm that tries to generate lines of roughly even width instead of just
-- filling line by line, but those are more involved.
--
-- A simpler thing to do is implement zero-width spaces (&zwsp), which is a character that just
-- explicitly marks a place where word wrap is allowed, and then you can insert them strategically
-- to manually word-wrap text.  Takes more work to insert them, but if there isn't a ton of text
-- being wrapped, it might be simpler.
------
--
-- I have neither the native intelligence nor the brute-force-self-taught-CS-experience to achieve
-- any of the above, so here is some laughably bad code that is just barely good enough to meet the
-- needs of JP text in Simply Love.  Feel free to copy+paste this method to /r/shittyprogramming,
-- private Discord servers, etc., for didactic and comedic purposes alike.

BitmapText._wrapwidthpixels = function(bmt, w)
	local text = bmt:GetText()

	if not is8bit(text) then
		-- a range of bytes I'm considering to indicate JP characters,
		-- mostly derived from empirical observation and guesswork
		-- >= 240 seems to be emojis, the glyphs for which are as wide as Miso in SL, so don't include those
		-- FIXME: If you know more about how this actually works, please submit a pull request.
		local lower = 200
		local upper = 240
		bmt:settext("")

		for i=1, text:utf8len() do
			local c = text:utf8sub(i,i)
			local b = c:byte()

			-- if adding this character causes the displayed string to be wider than allowed
			if bmt:settext( bmt:GetText()..c ):GetWidth() > w then
				-- and if that character just added was in the jp range (...maybe)
				if b < upper and b >= lower then
					-- then insert a newline between the previous character and the current
					-- character that caused us to go over
					bmt:settext( bmt:GetText():utf8sub(1,-2).."\n"..c )
				else
					-- otherwise it's trickier, as romance languages only really allow newlines
					-- to be inserted between words, not in the middle of single words
					-- we'll have to "peel back" a character at a time until we hit whitespace
					-- or something in the jp range
					local _text = bmt:GetText()

					for j=i,1,-1 do
						local _c = _text:utf8sub(j,j)
						local _b = _c:byte()

						if _c:match("%s") or (_b < upper and _b >= lower) then
							bmt:settext( _text:utf8sub(1,j) .. "\n" .. _text:utf8sub(j+1) )
							break
						end
					end
				end
			end
		end
	else
		bmt:wrapwidthpixels(w)
	end

	-- return the BitmapText actor in case the theme is chaining actor commands
	return bmt
end

BitmapText.Truncate = function(bmt, m)
	local text = bmt:GetText()
	local l = text:len()

	-- With SL's Miso and JP fonts, english characters (Miso) tend to render 2-3x less wide
	-- than JP characters. If the text includes JP characters, it is (probably) desired to
	-- truncate the string earlier to achieve the same effect.
	-- Here, we are arbitrarily "weighting" JP characters to count 4x as much as one Miso
	-- character and then scaling the point at which we truncate accordingly.
	-- This is, of course, a VERY broad over-generalization, but It Works For Now™.
	if not is8bit(text) then
		l = 0

		local lower = 200
		local upper = 240

		for i=1, text:utf8len() do
			local b = text:utf8sub(i,i):byte()
			l = l + ((b < upper and b >= lower) and 4 or 1)
		end
		m = math.floor(m * (m/l))
	end

	-- if the length of the string is less than the specified truncate point, don't do anything
	if l <= m then return end
	-- otherwise, replace everything after the truncate point with an ellipsis
	bmt:settext( text:utf8sub(1, m) .. "…" )

	-- return the BitmapText actor in case the theme is chaining actor commands
	return bmt
end

-- -----------------------------------------------------------------------
-- call this to draw a Quad with a border
-- arguments are: width of quad, height of quad, and border width, in pixels

Border = function(width, height, bw)
	width  = width  or 2
	height = height or 2
	bw     = bw     or 1

	return Def.ActorFrame {
		Def.Quad { InitCommand=function(self) self:zoomto(width-2*bw, height-2*bw):MaskSource(true) end },
		Def.Quad { InitCommand=function(self) self:zoomto(width,height):MaskDest() end },
		Def.Quad { InitCommand=function(self) self:diffusealpha(0):clearzbuffer(true) end },
	}
end


SL_WideScale = function(AR4_3, AR16_9)
    return clamp(scale( SCREEN_WIDTH, 640, 854, AR4_3, AR16_9 ), math.min(AR4_3, AR16_9), math.max(AR4_3, AR16_9))
end

-- -----------------------------------------------------------------------
-- determines which timing_window an offset value (number) belongs to
-- used by the judgment scatter plot and offset histogram in ScreenEvaluation

DetermineTimingWindow = function(offset, mode)
	if not mode then mode = "Waterfall" end
	-- i have no intention of supporting TimingWindowScale but i'll leave it here on the weird chance that
	-- it happens to be set
	for i=1,5 do
		if math.abs(offset) <= SL.Preferences[mode]["TimingWindowSecondsW"..i] * PREFSMAN:GetPreference("TimingWindowScale") + SL.Preferences[mode]["TimingWindowAdd"] then
			if mode == "ITG" and i == 4 then return (WF.SelectedErrorWindowSetting == 3) and 4 or 5 end
			return i
		end
	end
	return 5
end

-- -----------------------------------------------------------------------
-- some common information needed by ScreenSystemOverlay's credit display,
-- as well as ScreenTitleJoin overlay and ./Scripts/SL-Branches.lua regarding coin credits

GetCredits = function()
	local coins = GAMESTATE:GetCoins()
	local coinsPerCredit = PREFSMAN:GetPreference('CoinsPerCredit')
	local credits = math.floor(coins/coinsPerCredit)
	local remainder = coins % coinsPerCredit

	return { Credits=credits,Remainder=remainder, CoinsPerCredit=coinsPerCredit }
end

-- -----------------------------------------------------------------------
-- return the x value for the center of a player's notefield
-- used to position various elements in ScreenGameplay

GetNotefieldX = function( player )
	if not player then return end

	local style = GAMESTATE:GetCurrentStyle()
	if not style then return end

	local p = ToEnumShortString(player)
	local game = GAMESTATE:GetCurrentGame():GetName()

	local IsPlayingDanceSolo = (style:GetStepsType() == "StepsType_Dance_Solo")
	local NumPlayersEnabled  = GAMESTATE:GetNumPlayersEnabled()
	local NumSidesJoined     = GAMESTATE:GetNumSidesJoined()
	local IsUsingSoloSingles = PREFSMAN:GetPreference('Center1Player') or IsPlayingDanceSolo or (NumSidesJoined==1 and (game=="techno" or game=="kb7"))

	-- dance solo is always centered
	if IsUsingSoloSingles and NumPlayersEnabled == 1 and NumSidesJoined == 1 then return _screen.cx end
	-- double is always centered
	if style:GetStyleType() == "StyleType_OnePlayerTwoSides" then return _screen.cx end

	local PlayerOffset = SL[p].ActiveModifiers.NoteFieldOffsetX * (player == PLAYER_1 and -1 or 1)

	local NumPlayersAndSides = ToEnumShortString( style:GetStyleType() )
	return THEME:GetMetric("ScreenGameplay","Player".. p .. NumPlayersAndSides .."X") + PlayerOffset
end

-- -----------------------------------------------------------------------
-- this is verbose, but it lets us manage what seem to be
-- quirks/oversights in the engine on a per-game + per-style basis

local NoteFieldWidth = {
	-- dance uses such nice, clean multiples of 64.  It's almost like this game gets the most attention and fixes.
	dance = {
		single  = 256,
		versus  = 256,
		double  = 512,
		solo    = 384,
		routine = 512,
		-- couple and threepanel not supported in Simply Love at this time D:
		-- couple = 256,
		-- threepanel = 192
	},
	-- pump's values are very similar to those used in dance, but curiously smaller
	pump = {
		single  = 250,
		versus  = 250,
		double  = 500,
		routine = 500,
	},
	-- These values for techno, para, and kb7 are the result of empirical observation
	-- of the SM5 engine and should not be regarded as any kind of Truth.
	techno = {
		single8 = 448,
		versus8 = 272,
		double8 = 543,
	},
	para = {
		single = 280,
		versus = 280,
	},
	kb7 = {
		single = 480,
		versus = 270,
	},
}

GetNotefieldWidth = function()
	local game = GAMESTATE:GetCurrentGame()

	if game then
		local game_widths = NoteFieldWidth[game:GetName()]
		local style = GAMESTATE:GetCurrentStyle()
		if style then
			return game_widths[style:GetName()]
		end
	end

	return false
end

-- -----------------------------------------------------------------------
-- Generates the column mapping in case of any turn mods.
-- Returns a table containing the column swaps.
-- Returns nil if we can't compute it
GetColumnMapping = function(player)
	local po = GAMESTATE:GetPlayerState(player):GetPlayerOptions('ModsLevel_Preferred')

	local shuffle = po:Shuffle() or po:SoftShuffle() or po:SuperShuffle()
	local notes_inserted = (po:Wide() or po:Skippy() or po:Quick() or po:Echo() or
													po:BMRize() or po:Stomp() or po:Big())
	local notes_removed = (po:Little()  or po:NoHolds() or po:NoStretch() or
													po:NoHands() or po:NoJumps() or po:NoFakes() or
													po:NoLifts() or po:NoQuads() or po:NoRolls())

	-- If shuffle is used or notes were inserted/removed, we can't compute it
	-- return early
	-- TODO(teejusb): Add support for Backwards()
	if shuffle or notes_inserted or notes_removed or po:Backwards() then
		return nil
	end

	local flip = po:Flip() > 0
	local invert = po:Invert() > 0
	local left = po:Left()
	local right = po:Right()
	local mirror = po:Mirror()
	local udmirror = po:UDMirror()
	local lrmirror = po:LRMirror()

	-- Combining flip and invert results in unusual spacing so ignore it.
	if flip and invert then
		return nil
	end

	local has_turn = flip or invert or left or right or mirror
	local style = GAMESTATE:GetCurrentStyle()
	local num_columns = style:ColumnsPerPlayer()

	-- We only resolve turn mods in 4 and 8 panel.
	if num_columns ~= 4 and num_columns ~= 8 then
		if not has_turn then
			-- Not turn mod used, return 1-to-1 mapping.
			return range(num_columns)
		else
			-- If we are using turn mods in modes without 4 or 8 columns then return
			-- early since we don't try to resolve them.
			return nil
		end
	end

	local column_mapping = {1, 2, 3, 4}

	if flip then
		column_mapping = {column_mapping[4], column_mapping[3], column_mapping[2], column_mapping[1]}
	end

	if invert then
		column_mapping = {column_mapping[2], column_mapping[1], column_mapping[4], column_mapping[3]}
	end

	if left then
		column_mapping = {column_mapping[2], column_mapping[4], column_mapping[1], column_mapping[3]}
	end

	if right then
		column_mapping = {column_mapping[3], column_mapping[1], column_mapping[4], column_mapping[2]}
	end

	if mirror then
		column_mapping = {column_mapping[4], column_mapping[3], column_mapping[2], column_mapping[1]}
	end

	if udmirror then
		column_mapping = {column_mapping[1], column_mapping[3], column_mapping[2], column_mapping[4]}
	end

	if lrmirror then
		column_mapping = {column_mapping[4], column_mapping[2], column_mapping[3], column_mapping[1]}
	end

	if num_columns == 8 then
		for i=1,4 do
			column_mapping[4+i] = column_mapping[i] + 4
		end

		-- Flip, Mirror. and LRMirror all swap left and right sides.
		-- If an odd number of them are set then swap.
		local swapCount = 0
		if flip then swapCount = swapCount + 1 end
		if mirror then swapCount = swapCount + 1 end
		if lrmirror then swapCount = swapCount + 1 end

		if swapCount % 2 == 1 then
			for i=1,4 do
				column_mapping[i] = column_mapping[i] + 4
				column_mapping[i+4] = column_mapping[i+4] - 4
			end
		end
	end

	return column_mapping
end

-- -----------------------------------------------------------------------
-- Define what is necessary to maintain and/or increment your combo, per Gametype.
-- For example, in dance Gametype, TapNoteScore_W3 (window #3) is commonly "Great"
-- so in dance, a "Great" will not only maintain a player's combo, it will also increment it.
--
-- We reference this function in Metrics.ini under the [Gameplay] section.
-- [TODO] no intention of supporting games outside of dance or pump; this function should really just be removed
-- and TapNoteScore_W4 should just be put straight into the metrics
GetComboThreshold = function( MaintainOrContinue )
	return "TapNoteScore_W4"
	--[[
	local CurrentGame = GAMESTATE:GetCurrentGame():GetName()

	local ComboThresholdTable = {
		dance	=	{ Maintain = "TapNoteScore_W3", Continue = "TapNoteScore_W3" },
		pump	=	{ Maintain = "TapNoteScore_W4", Continue = "TapNoteScore_W4" },
		techno	=	{ Maintain = "TapNoteScore_W3", Continue = "TapNoteScore_W3" },
		kb7		=	{ Maintain = "TapNoteScore_W4", Continue = "TapNoteScore_W4" },
		-- these values are chosen to match Deluxe's PARASTAR
		para	=	{ Maintain = "TapNoteScore_W5", Continue = "TapNoteScore_W3" },

		-- I don't know what these values are supposed to actually be...
		popn	=	{ Maintain = "TapNoteScore_W3", Continue = "TapNoteScore_W3" },
		beat	=	{ Maintain = "TapNoteScore_W3", Continue = "TapNoteScore_W3" },
		kickbox	=	{ Maintain = "TapNoteScore_W3", Continue = "TapNoteScore_W3" },

		-- lights is not a playable game mode, but it is, oddly, a selectable one within the operator menu
		-- include dummy values here to prevent Lua errors in case players accidentally switch to lights
		lights =	{ Maintain = "TapNoteScore_W3", Continue = "TapNoteScore_W3" },
	}

	return ComboThresholdTable[CurrentGame][MaintainOrContinue]
	]]
end

-- -----------------------------------------------------------------------

-- FailType is a PlayerOption that can be set using SM5's PlayerOptions interface.
-- If you wanted, you could set FailTyper per-player, prior to Gameplay like
--
-- GAMESTATE:GetPlayerState(PLAYER_1):GetPlayerOptions("ModsLevel_Preferred"):FailSetting("FailType_ImmediateContinue")
-- GAMESTATE:GetPlayerState(PLAYER_2):GetPlayerOptions("ModsLevel_Preferred"):FailSetting("FailType_Off")
--
-- and then P1 and P2 would have different Fail settings during gameplay.
--
-- That sounds kind of chaotic, particularly with saving Machine HighScores, so Simply Love
-- enforces the same FailType for both players and allows machine operators to set a
-- "default FailType" within Advanced Options in the Operator Menu.
--
-- This "default FailType" is sort of handled by the engine, but not in a way that is
-- necessarily clear to me.  Whatever the history there was, it is lost to me now.
--
-- The engine's FailType enum has the following four values:
-- 'FailType_Immediate', 'FailType_ImmediateContinue', 'FailType_EndOfSong', and 'FailType_Off'
--
-- The conf-based OptionRow for "DefaultFailType" presents these^ as the following hardcoded English strings:
-- 'Immediate', 'ImmediateContinue', 'EndOfSong', and 'Off'
--
-- and whichever the machine operator chooses gets saved as a different hardcoded English string in
-- the DefaultModifiers Preference for the current game:
-- '', 'FailContinue', 'FailEndOfSong', or 'FailOff'

-- It is worth pointing out that a default FailType of "FailType_Immediate" is saved to the DefaultModifiers
-- Preference as an empty string!
--
-- so this:
-- DefaultModifiers=FailOff, Overhead, Cel
-- would result in the engine applying FailType_Off to players when they join the game
--
-- while this:
-- DefaultModifiers=Overhead, Cel
-- would result in the engine applying FailType_Immediate to players when they join the game
--
-- Anyway, this is all convoluted enough that I wrote this global helper function find the default
-- FailType setting in the current game's DefaultModifiers Preference and return it as an enum value
-- the PlayerOptions interface can accept.
--
-- I'm pretty sute ZP Theart was wailing about such project bitrot in Lost Souls in Endless Time.

GetDefaultFailType = function()
	return "FailType_ImmediateContinue" -- force this setting
end

-- -----------------------------------------------------------------------

SetGamePreferences = function()
	-- apply the preferences associated with this game environment
	for key,val in pairs(SL.Preferences.Waterfall) do
		PREFSMAN:SetPreference(key, val)
	end

	-- We want all TimingWindows enabled by default.
	--WF.SetErrorWindow("Enabled")
	
	-- loop through human players and apply whatever mods need to be set now
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local player_modslevel = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
		-- using PREFSMAN to set the preference for MinTNSToHideNotes apparently isn't
		-- enough because MinTNSToHideNotes is also a PlayerOption.
		-- so, set the PlayerOption version of it now, too, to ensure that arrows disappear
		-- at the appropriate judgments during gameplay.
		player_modslevel:MinTNSToHideNotes(SL.Preferences.Waterfall.MinTNSToHideNotes)

		-- FailSetting is also a modifier that can be set per-player per-stage in SM5, but I'm
		-- opting to enforce it in Simply Love using what the machine operator sets
		-- as the default FailType in Advanced Options in the operator menu
		player_modslevel:FailSetting( GetDefaultFailType() )
	end
end

--- Function to set all preferences and metrics to "Waterfall" mode; enforce this between title menu and
--- ScreenSelectMusic
function EnforceGameEnvironment()
	SetGamePreferences()
	THEME:ReloadMetrics()
end

-- -----------------------------------------------------------------------
-- Call ResetPreferencesToStockSM5() to reset all the Preferences that SL silently
-- manages for you back to their stock SM5 values.  These "managed" Preferences are
-- listed in ./Scripts/SL_Init.lua, and
-- actively applied (and reapplied) for each new game using SetGamePreferences()
--
-- SL normally calls ResetPreferencesToStockSM5() from
-- ./BGAnimations/ScreenPromptToResetPreferencesToStock overlay.lua
-- but people have requested that the functionality for resetting Preferences be
-- generally accessible (for example, switching themes via a pad code).
-- Thus, this global function.

ResetPreferencesToStockSM5 = function()
	-- loop through all the Preferences and reset them
	for key, value in pairs(SL.Preferences.Waterfall) do
		PREFSMAN:SetPreferenceToDefault(key)
	end
	-- now that those Preferences are reset to default values, write Preferences.ini to disk now
	PREFSMAN:SavePreferences()
end

-- -----------------------------------------------------------------------
-- given a player, return a table of stepartist text for the current song or coursen
-- rearranging these so that they can be iterated through from "bottom to top" in a priority order
-- such that, given all 3 exist, the order will be Name, Artist, Description from top to bottom, but the
-- texts will be bottom aligned
-- also, don't include any repetitions because that looks bad on screeneval and tells you nothing extra
-- noreverse argument makes the table return in forward order, for the marquee on song select.
-- i am mainly only adding this so that Trevor's punchlines work

GetStepsCredit = function(player, noreverse)
	local t = {}

	if GAMESTATE:IsCourseMode() then
		local course = GAMESTATE:GetCurrentCourse()
		-- scripter
		if course:GetScripter() ~= "" then t[#t+1] = course:GetScripter() end
		-- description
		if course:GetDescription() ~= "" then t[#t+1] = course:GetDescription() end
	else
		local steps = GAMESTATE:GetCurrentSteps(player)
		-- description
		local desc = steps:GetDescription()
		if desc ~= "" then t[#t+1] = desc end
		-- credit
		local cred = steps:GetAuthorCredit()
		if cred ~= "" and (not FindInTable(cred, t)) then t[#t+1] = cred end
		-- chart name
		local name = steps:GetChartName()
		if name ~= "" and (not FindInTable(name, t)) then t[#t+1] = name end
	end

	if noreverse then
		local t_rev = {}
		for i = #t, 1, -1 do table.insert(t_rev, t[i]) end
		t = t_rev
	end

	return t
end

DarkUI = function()
	-- dummy function that should ideally not be referenced anywhere
	if THEME:GetCurThemeName() ~= PREFSMAN:GetPreference("Theme") then return false end

	return false
end

GetHeldMissGraphics = function()
	local path = THEME:GetCurrentThemeDirectory().."Graphics/_HeldMiss/"
	local files = FILEMAN:GetDirListing(path)
	local held_miss = {}

	for i,filename in ipairs(files) do
			table.insert(held_miss, filename)
	end
	held_miss[#held_miss+1] = "None"

	return held_miss
end

-- -----------------------------------------------------------------------
-- account for the possibility that emojis shouldn't be diffused to Color.Black

DiffuseEmojis = function(bmt, text)
	text = text or bmt:GetText()

	-- loop through each char in the string, checking for emojis; if any are found
	-- don't diffuse that char to be any specific color by selectively diffusing it to be {1,1,1,1}
	for i=1, text:utf8len() do
		if text:utf8sub(i,i):byte() >= 240 then
			bmt:AddAttribute(i-1, { Length=1, Diffuse={1,1,1,1} } )
		end
	end
end

-- -----------------------------------------------------------------------
-- read the theme version from ThemeInfo.ini to display on ScreenTitleMenu underlay
-- this allows players to more easily identify what version of the theme they are currently using

GetThemeVersion = function()
	local file = IniFile.ReadFile( THEME:GetCurrentThemeDirectory() .. "ThemeInfo.ini" )
	if file then
		if file.ThemeInfo and file.ThemeInfo.Version then
			return file.ThemeInfo.Version
		end
	end
	return false
end

-- -----------------------------------------------------------------------
-- functions handle custom judgment graphic detection/loading

local function FilenameIsMultiFrameSprite(filename)
	-- look for the "[frames wide] x [frames tall]"
	-- and some sort of all-letters file extension
	-- Lua doesn't support an end-of-string regex marker...
	return string.match(filename, " %d+x%d+") and string.match(filename, "%.[A-Za-z]+")
end

function StripSpriteHints(filename)
	-- handle common cases here, gory details in /src/RageBitmapTexture.cpp
	return filename:gsub(" %d+x%d+", ""):gsub(" %(doubleres%)", ""):gsub(".png", "")
end

function GetJudgmentGraphics(mode)
	-- pass nothing in here to just get normal judgments, but we will want to be able to pass "ITG" in too
	if not mode then mode = "Waterfall" end

	local path = THEME:GetPathG('', '_judgments' .. (mode ~= "Waterfall" and "/"..mode or ""))
	local files = FILEMAN:GetDirListing(path .. '/')
	local judgment_graphics = {}

	for i,filename in ipairs(files) do

		-- Filter out files that aren't judgment graphics
		-- e.g. hidden system files like .DS_Store
		if FilenameIsMultiFrameSprite(filename) then

			-- use regexp to get only the name of the graphic, stripping out the extension
			local name = StripSpriteHints(filename)

			-- Fill the table, special-casing Love so that it comes first.
			if name == "Love" then
				table.insert(judgment_graphics, 1, filename)
			else
				judgment_graphics[#judgment_graphics+1] = filename
			end
		end
	end

	-- "Plain Text" will be another specially handled option
	judgment_graphics[#judgment_graphics+1] = "Plain Text"
	
	-- "None" -> no graphic in Player judgment.lua
	judgment_graphics[#judgment_graphics+1] = "None"

	return judgment_graphics
end

-- -----------------------------------------------------------------------
-- Pass in a string from the engine's Difficulty enum like "Difficulty_Beginner"
-- or "Difficulty_Challenge" and this will return the index of that string within
-- the enum (or nil if not found).  This is used by SL's color system to dynamically
-- color theme elements based on difficulty as the primary color scheme changes.

GetDifficultyIndex = function(difficulty)
	-- if we weren't passed a string, return nil now
	if type(difficulty) ~= "string" then return nil end

	-- FIXME: Why is this hardcoded to 5?  I need to look into this and either change
	-- it or leave a note explaining why it's this way.
	if difficulty == "Difficulty_Edit" then return 5 end

	-- Use Enum's reverse lookup functionality to find difficulty by index
	-- note: this is 0 indexed, so Beginner is 0, Challenge is 4, and Edit is 5
	-- for our purposes, increment by 1 here
	local difficulty_index = Difficulty:Reverse()[difficulty]
	if type(difficulty_index) == "number" then return (difficulty_index + 1) end
end


-- -----------------------------------------------------------------------
-- helper function for returning the player AF
-- Works as expected in ScreenGameplay + Edit + Practice Mode
--     arguments:  pn is short string PlayerNumber like "P1" or "P2"
--     returns:    the "PlayerP1" or "PlayerP2" ActorFrame in ScreenGameplay
--                 or, the unnamed equivalent in ScrenEdit
GetPlayerAF = function(pn)
	local topscreen = SCREENMAN:GetTopScreen()
	if not topscreen then
		lua.ReportScriptError("GetPlayerAF() failed to find the player ActorFrame because there is no Screen yet.")
		return nil
	end

	local playerAF = nil

	-- Get the player ActorFrame on ScreenGameplay
	-- It's a direct child of the screen and named "PlayerP1" for P1
	-- and "PlayerP2" for P2.
	-- This naming convention is hardcoded in the SM5 engine.
	--
	-- ScreenEdit does not name its player ActorFrame, but we can still find it.

	-- find the player ActorFrame in edit mode
	local notefields = {}
	if (THEME:GetMetric(topscreen:GetName(), "Class") == "ScreenEdit") then
		-- loop through all nameless children of topscreen
		-- and find the one that contains the NoteField
		-- which is thankfully still named "NoteField"1

		for _,nameless_child in ipairs(topscreen:GetChild("")) do
			if nameless_child:GetChild("NoteField") then
				notefields[#notefields+1] = nameless_child
			end
		end
		-- If there is only one side joined always return the first one.
		if #notefields == 1 then
			return notefields[1]
		-- If there are two sides joined, return the one that matches the player number.
		else
			return notefields[pn == "P1" and 1 or 2]
		end

	-- find the player ActorFrame in gameplay
	else
		local player_af = topscreen:GetChild("Player"..pn)
		if player_af then
			playerAF = player_af
		end
	end

	return playerAF
end
