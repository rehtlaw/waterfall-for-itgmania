local statustext

local t = Def.ActorFrame{
	-- GameplayReloadCheck is a kludgy global variable used in ScreenGameplay in.lua to check
	-- if ScreenGameplay is being entered "properly" or being reloaded by a scripted mod-chart.
	-- If we're here in SelectMusic, set GameplayReloadCheck to false, signifying that the next
	-- time ScreenGameplay loads, it should have a properly animated entrance.
	InitCommand=function(self) 
        SL.Global.GameplayReloadCheck = false
        generateFavoritesForMusicWheel()
	end,

	PlayerProfileSetMessageCommand=function(self, params)
		if not PROFILEMAN:IsPersistentProfile(params.Player) then
			LoadGuest(params.Player)
		end
		generateFavoritesForMusicWheel()
		ApplyMods(params.Player)
	end,

	PlayerJoinedMessageCommand=function(self, params)
		if not PROFILEMAN:IsPersistentProfile(params.Player) then
			LoadGuest(params.Player)
		end
		ApplyMods(params.Player)
	end,

	-- ---------------------------------------------------
	--  first, load files that contain no visual elements, just code that needs to run

	-- MenuTimer code for preserving SSM's timer value
	LoadActor("./MenuTimer.lua"),
	-- Apply player modifiers from profile
	LoadActor("./PlayerModifiers.lua"),

	-- ---------------------------------------------------
	-- next, load visual elements; the order of the layers matters for most of these

	-- make the MusicWheel appear to cascade down; this should draw underneath P2's PaneDisplay
	LoadActor("./MusicWheelAnimation.lua"),

	-- elements we need two of (one for each player) that draw underneath the StepsDisplayList
	-- this includes the stepartist boxes and the PaneDisplays (number of steps, jumps, holds, etc.)
	LoadActor("./PerPlayer/Under.lua"),

	-- the pane display (new and improved!!)
	LoadActor("./PaneDisplay.lua"),

	-- grid of Difficulty Blocks (normal) or CourseContentsList (CourseMode)
	LoadActor("./StepsDisplayList/default.lua"),

	-- Graphical Banner
	LoadActor("./Banner.lua"),
	-- CD Title
	LoadActor("./CDTitle.lua"),
	-- Song Artist, BPM, Duration (Referred to in other themes as "PaneDisplay")
	LoadActor("./SongDescription.lua"),

	-- ---------------------------------------------------
	-- finally, load the overlay used for sorting the MusicWheel (and more), hidden by default
	LoadActor("./SortMenu/default.lua"),
	-- a Test Input overlay can (maybe) be accessed from the SortMenu
	LoadActor("./TestInput.lua"),

	-- The GrooveStats leaderboard that can (maybe) be accessed from the SortMenu
	-- This is only added in "dance" mode and if the service is available.
	LoadActor("./Leaderboard.lua"),

	-- a yes/no prompt overlay for backing out of SelectMusic when in EventMode can be
	-- activated via "CodeEscapeFromEventMode" under [ScreenSelectMusic] in Metrics.ini
	LoadActor("./EscapeFromEventMode.lua"),

	-- Song Search 
	-- activated from the SortMenu
	LoadActor("./SongSearch/default.lua"),
}

return t
