-- There's a lot of Lua in ./BGAnimations/ScreenGameplay overlay
-- and a LOT of Lua in ./BGAnimations/ScreenGameplay underlay
--
-- I'm using files in overlay for logic that *does* stuff without directly drawing
-- any new actors to the screen.
--
-- I've tried to title each file helpfully and partition the logic found in each accordingly.
-- Inline comments in each should provide insight into the objective of each file.
--
-- Def.Actor will be used for each underlay file because I still need some way to listen
-- for events broadcast by the engine.
--
-- I'm using files in Gameplay's underlay for actors that get drawn to the screen.  You can
-- poke around in those to learn more.
------------------------------------------------------------

local af = Def.ActorFrame{}

af[#af+1] = LoadActor("./WhoIsCurrentlyWinning.lua")

for player in ivalues( GAMESTATE:GetHumanPlayers() ) do

	local pn = ToEnumShortString(player)

	-- Use this opportunity to create an empty table for this player's gameplay stats for this stage.
	-- We'll store all kinds of data in this table that would normally only exist in ScreenGameplay so that
	-- it can persist into ScreenEvaluation to eventually be processed, visualized, and complained about.
	-- For example, per-column judgments, judgment offset data, highscore data, and so on.
	--
	-- Sadly, this Stages.Stats[stage_index] data structure is not documented anywhere. :(
	SL[pn].Stages.Stats[SL.Global.Stages.PlayedThisGame+1] = {}

	af[#af+1] = LoadActor("./TrackTimeSpentInGameplay.lua", player)
	af[#af+1] = LoadActor("./DetailedJudgmentTracking.lua", player)
	af[#af+1] = LoadActor("./PerColumnJudgmentGraphics.lua", player)
	af[#af+1] = LoadActor("./MineCount.lua", player)
	
	-- FIXME: refactor PerColumnJudgmentTracking to not be inside this loop
	--        the Lua input callback logic shouldn't be duplicated for each player
	-- gotchu :) - steve
end

af[#af+1] = LoadActor("./MissBCHeld.lua")
af[#af+1] = LoadActor("./QuickRestart.lua")

-- Input handler for logging button presses
local InputHandler = function(event) 
	if event.button == "Left" and (event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat") then MESSAGEMAN:Broadcast("ButtonPress",{ Button="Left", Player=event.PlayerNumber }) end
	if event.button == "Right" and (event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat") then MESSAGEMAN:Broadcast("ButtonPress",{ Button="Right", Player=event.PlayerNumber }) end
	if event.button == "Up" and (event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat") then MESSAGEMAN:Broadcast("ButtonPress",{ Button="Up", Player=event.PlayerNumber }) end
	if event.button == "Down" and (event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat") then MESSAGEMAN:Broadcast("ButtonPress",{ Button="Down", Player=event.PlayerNumber }) end
end

local buttonpresses = Def.ActorFrame{
	OnCommand=function(self) SCREENMAN:GetTopScreen():AddInputCallback( InputHandler ) end
}

af[#af+1] = buttonpresses



return af
