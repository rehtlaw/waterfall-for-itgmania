local Players = GAMESTATE:GetHumanPlayers()
local PaneNames = {"General", "PerPanel", "Timing", "CourseSongs", "HighScores", "GeneralITG", "PerPanelITG", "TimingITG",
	"CourseSongsITG", "HighScoresITG", "FAPlus", "Achievements", "TestInput", "GSQR"}
local SecPaneNames = {"General", "GeneralITG", "PerPanel", "PerPanelITG", "Timing", "TimingITG", "CourseSongs",
	"CourseSongsITG", "HighScores", "HighScoresITG", "FAPlus", "Achievements", "GSQR"}

local playerstats = {}
local iscourse = GAMESTATE:IsCourseMode()

local InputHandler, RpgInputHandler, MenuInputHandler

-- keep track of panes using tables per player
WF.EvalPanes = {}
WF.EvalSecPanes = {}
WF.DefaultPane = {}
WF.DefaultSecPane = "GeneralITG"
WF.ActivePane = {}
WF.ActiveSecPane = "General"
-- EnvView and GraphView only refer to what is "selected" or "preferred" - not necessarily what is shown,
-- since certain panes force environments or graphs
WF.EnvView = {}
WF.GraphView = {}
if not WF.ITGCentricPanes then
	WF.ITGCentricPanes = {"GSQR", "GeneralITG", "PerPanelITG", "TimingITG", "CourseSongsITG", "HighScoresITG"}
	WF.WFCentricPanes = {"General", "PerPanel", "Timing", "CourseSongs", "HighScores"}
end

-- generate hashes once, and pass them down to other things that need them
local hashes = {}

--- update song stats, initialize some stuff
for player in ivalues(Players) do
	local pn = tonumber(player:sub(-1))

	-- Itl File
	
	-- songs played
	WF.CurrentSessionSongsPlayed[pn] = WF.CurrentSessionSongsPlayed[pn] + 1

	-- itg stuff [TODO] eventually might just store the score before getting here. not sure.
	WF.CalculateITGScore(player)

	-- consolidate per panel
	local detailed = SL["P"..pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].detailed_judgments
	WF.ConsolidatePerPanelJudgments(pn, detailed)

	-- update song stats
	if not iscourse then
		local lifevals = WF.GetShortLifeBarTable(pn)
		local stats = WF.BuildStatsObj(STATSMAN:GetCurStageStats():GetPlayerStageStats(player), lifevals)
		WF.CurrentSongStatsObject[pn] = stats
		playerstats[pn] = stats -- we can pass this down to other actors that might need to use it
	end

	local song = (not iscourse) and GAMESTATE:GetCurrentSong() or GAMESTATE:GetCurrentCourse()
	local steps = (not iscourse) and GAMESTATE:GetCurrentSteps(player) or GAMESTATE:GetCurrentTrail(player)
	local profile = PROFILEMAN:GetProfile(player)

	-- get hashes if needed
	if not iscourse then
		local ss, ft = GetSimfileString(steps)
		hashes[pn] = GetHashFromSimfileString(steps, ss, ft)
		if (hashes[pn]) and (hashes[pn] ~= "") then
			local id = WF.GetStepsID(song, steps)
			WF.HashCache[id] = hashes[pn]
		end
	end

	-- high score stats
	local rate = RateFromNumber(SL.Global.ActiveModifiers.MusicRate)
	local songstats = WF.FindProfileSongStatsFromSteps(song, steps, rate, hashes[pn], pn)

	-- pane stuff
	local itg = SL["P"..pn].ActiveModifiers.SimulateITGEnv
	WF.EvalPanes[pn] = {}
	WF.DefaultPane[pn] = (not itg) and "General" or "GeneralITG"

	WF.DefaultSecPane = SL["P"..pn].ActiveModifiers.PreferredSecondPane

	-- "Per Panel Distribution" in doubles mode takes up the entire pane
	-- If a player has this set as their preferred second pane
	-- The screen loads with the panel distribution overlapping the primary
	-- So reset this back to General if they are playing doubles
	-- Waterfall Expanded 0.7.7	
	local styleType = GAMESTATE:GetCurrentStyle():GetStyleType()
	if styleType == "StyleType_OnePlayerTwoSides" then 
		if WF.DefaultSecPane == "PerPanel" then WF.DefaultSecPane = "General" end
	end
	
	if (itg and (WF.DefaultSecPane ~= "General")) or ((not itg) and WF.DefaultSecPane == "General") then
		WF.DefaultSecPane = WF.DefaultSecPane.."ITG"
	end
	WF.EnvView[pn] = (not itg) and "Waterfall" or "ITG"
	WF.GraphView[pn] = SL["P"..pn].ActiveModifiers.PreferredGraph
	WF.ActivePane[pn] = 1 -- this will be set to the "true" index of DefaultPane below if it isn't 1

	-- initialize dual pane view logic
	if #Players == 1 then
-- 		local removepanes = (SL["P"..pn].ActiveModifiers.SimulateITGEnv) and WF.WFCentricPanes or WF.ITGCentricPanes
-- 		for name in ivalues(removepanes) do
-- 			if FindInTable(name, PaneNames) then
-- 				table.remove(PaneNames, FindInTable(name, PaneNames))
-- 			end
-- 		end
		local otherp = (pn == 1) and 2 or 1
		WF.DefaultPane[otherp] = WF.DefaultSecPane
		WF.EvalPanes[otherp] = WF.EvalSecPanes
		WF.ActivePane[otherp] = 1
		WF.EnvView[otherp] = WF.EnvView[pn]
		WF.GraphView[otherp] = SL["P"..pn].ActiveModifiers.PreferredSecondGraph
	end
end

-- consolidate course stats (see WF-Scoring.lua)
WF.ConsolidateCourseStats()
if iscourse then
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local pn = tonumber(player:sub(-1))
		playerstats[pn] = WF.CurrentCourseStatsObjects[pn][1]
	end
end

-- evaluate all profile stuff
-- see WF-Profiles.lua for the data structure returned here
local hsdata = WF.UpdateProfilesOnEvaluation((not iscourse) and hashes or nil)

-- Start by loading actors that would be the same whether 1 or 2 players are joined.
local t = Def.ActorFrame{
	Name = "ScreenEval Common",

	-- add a lua-based InputCalllback to this screen so that we can navigate
	-- through multiple panes of information; pass a reference to this ActorFrame
	-- and the number of panes there are to InputHandler.lua
	OnCommand=function(self)
		InputHandler = LoadActor("./InputHandler.lua", {af=self, num_panes=NumPanes})
		RpgInputHandler = LoadActor("./RpgInputHandler.lua")
		MenuInputHandler = LoadActor("./MenuInputHandler.lua")
		SCREENMAN:GetTopScreen():AddInputCallback(InputHandler)
	end,
	DirectInputToEngineCommand=function(self)
		SCREENMAN:GetTopScreen():RemoveInputCallback(RpgInputHandler)
		SCREENMAN:GetTopScreen():RemoveInputCallback(MenuInputHandler)
		SCREENMAN:GetTopScreen():AddInputCallback(InputHandler)

		for player in ivalues(PlayerNumber) do
			SCREENMAN:set_input_redirected(player, false)
		end
	end,
	DirectInputToRpgHandlerCommand=function(self)
		SCREENMAN:GetTopScreen():RemoveInputCallback(InputHandler)
		SCREENMAN:GetTopScreen():RemoveInputCallback(MenuInputHandler)
		SCREENMAN:GetTopScreen():AddInputCallback(RpgInputHandler)
		
		for player in ivalues(PlayerNumber) do
			SCREENMAN:set_input_redirected(player, true)
		end
	end,
	DirectInputToMenuCommand = function(self)
		SCREENMAN:GetTopScreen():RemoveInputCallback(InputHandler)
		SCREENMAN:GetTopScreen():RemoveInputCallback(RpgInputHandler)
		SCREENMAN:GetTopScreen():AddInputCallback(MenuInputHandler)

		for player in ivalues(PlayerNumber) do
			SCREENMAN:set_input_redirected(player, true)
		end
	end,

	-- code for triggering a screenshot and animating a "screenshot" texture
	LoadActor("./ScreenshotHandler.lua"),

	-- the song info and its graphical banner, if there is one
	LoadActor("./TitleAndBanner.lua"),

	-- store some attributes of this playthrough of this song in the global SL table
	-- for later retrieval on ScreenEvaluationSummary
	LoadActor("./GlobalStorage.lua"),	
}

local EvalChanged = function(actor, args, pn, itg, sec)
	-- moving this out to an external function because it's reused a lot
	local side = pn
	if sec then side = (pn == 1) and 2 or 1 end
	if args.pn ~= side then return end
	local playeditg = SL["P"..pn].ActiveModifiers.SimulateITGEnv
	if (sec) and ((playeditg and itg) or ((not playeditg) and (not itg))) then
		return
	end
	actor:finishtweening()
	local pane = WF.EvalPanes[side][args.activepane]
	local hidepanes = (itg) and WF.WFCentricPanes or WF.ITGCentricPanes
	local showpanes = (itg) and WF.ITGCentricPanes or WF.WFCentricPanes
	local name = (pane:GetName():gsub("2", ""))

	if pane and FindInTable(name, hidepanes) then
		actor:queuecommand("Hide")
	elseif pane and FindInTable(name, showpanes) then
		actor:queuecommand("Show")
	elseif not sec then
		if SL["P"..pn].ActiveModifiers.SimulateITGEnv then
			if itg then actor:queuecommand("Show") else actor:queuecommand("Hide") end
		else
			if itg then actor:queuecommand("Hide") else actor:queuecommand("Show") end
		end
	else
		actor:queuecommand("Hide")
	end
end



-- Then, load the player-specific actors.
for player in ivalues(Players) do
	local pn = tonumber(player:sub(-1))

	-- Generate the .itl file for the player.
	-- When the event isn't active, this actor is nil.
	t[#t+1] = LoadActor("./PerPlayer/ItlFile.lua", player)
		
	-- the upper half of ScreenEvaluation
	t[#t+1] = Def.ActorFrame{
		Name=ToEnumShortString(player).."_AF_Upper",
		OnCommand=function(self)
			if player == PLAYER_1 then
				self:x(_screen.cx - 155)
			elseif player == PLAYER_2 then
				self:x(_screen.cx + 155)
			end
		end,

		-- store player stats for later retrieval on EvaluationSummary and NameEntryTraditional
		LoadActor("./PerPlayer/Storage.lua", {player = player, stats = playerstats[pn]}),

		-- letter grade
		LoadActor("./PerPlayer/LetterGrade.lua", {player=player, stats=playerstats[pn]})..{
			Name = "LetterGrade",
			InitCommand = function(self)
				self:x(WideScale(2,34) * (player==PLAYER_1 and -1 or 1))
				self:y(_screen.cy-144)
				if FindInTable(WF.DefaultPane[pn], WF.ITGCentricPanes) then
					self:zoom(0)
				end
			end,
			EvalPaneChangedMessageCommand = function(self, args)
				EvalChanged(self, args, pn, false)
			end,
			ShowCommand = function(self)
				self:linear(0.08)
				self:zoom(1)
			end,
			HideCommand = function(self)
				self:linear(0.08)
				self:zoom(0)
			end
		},

		-- itg grade
		LoadActor("./PerPlayer/ITGGrade.lua", player)..{
			Name = "ITGGrade",
			InitCommand = function(self)
				self:x(WideScale(2,34) * (player==PLAYER_1 and -1 or 1))
				self:y(_screen.cy-144)
				if not FindInTable(WF.DefaultPane[pn], WF.ITGCentricPanes) then
					self:zoom(0)
				end
			end,
			EvalPaneChangedMessageCommand = function(self, args)
				EvalChanged(self, args, pn, true)
			end,
			ShowCommand = function(self)
				self:linear(0.08)
				self:zoom(1)
			end,
			HideCommand = function(self)
				self:linear(0.08)
				self:zoom(0)
			end
		},

		-- profile card
		LoadActor(THEME:GetPathG("", "_profilecard/profilecard.lua"), {player = player, 
			loweraf = WF.ProfileCardLowerAF(pn)})..{
			InitCommand = function(self) self:xy((player == PLAYER_1 and -1 or 1) * WideScale(104,168),100) end
		},

		-- temporary: cleartype text
		Def.Quad{
			Name = "CTBack",
			InitCommand = function(self)
				self:xy(WideScale(2,34) * (player==PLAYER_1 and -1 or 1),_screen.cy - 104)
					:zoomto(90,16):diffuse(0,0,0,0.8)
				if FindInTable(WF.DefaultPane[pn], WF.ITGCentricPanes) then
					self:diffusealpha(0)
				end
			end,
			EvalPaneChangedMessageCommand = function(self, args)
				EvalChanged(self, args, pn, false)
			end,
			ShowCommand = function(self)
				self:linear(0.08)
				self:diffusealpha(0.8)
			end,
			HideCommand = function(self)
				self:linear(0.08)
				self:diffusealpha(0)
			end
		},
		LoadFont("Common Normal")..{
			Name = "CTText",
			Text = "",
			InitCommand = function(self)
				self:x(WideScale(2,34) * (player==PLAYER_1 and -1 or 1))
				self:y(_screen.cy - 104)
				self:zoom(0.75)
				local ct = playerstats[pn]:GetClearType()
				if ct == WF.ClearTypes.Fail then
					local s = playerstats[pn]:GetSkipped() and " (skipped)" or ""
					self:settext("Failed"..s)
					self:diffuse(1,0,0,1)
				else
					self:settext(WF.ClearTypes[ct])
					if ct <= 4 then
						-- full combo tiers. colorize to judgment color.
						self:diffuse(SL.JudgmentColors["Waterfall"][ct])
					else
						-- lifebar clear tiers. colorize to lifebar color.
						local c = WF.LifeBarColors[4 - (ct - 4)]
						self:diffuse(c[1],c[2],c[3],1)
					end
				end
				if FindInTable(WF.DefaultPane[pn], WF.ITGCentricPanes) then
					self:diffusealpha(0)
				end
			end,
			EvalPaneChangedMessageCommand = function(self, args)
				EvalChanged(self, args, pn, false)
			end,
			ShowCommand = function(self)
				self:linear(0.08)
				self:diffusealpha(1)
			end,
			HideCommand = function(self)
				self:linear(0.08)
				self:diffusealpha(0)
			end
		},

		-- significant mod icons
		LoadActor(THEME:GetPathG("", "_SignificantMods/iconrow.lua"), player)..{
			InitCommand = function(self)
				self:xy((player == PLAYER_1 and -1 or 1) * math.min(98,WideScale(52,116)), _screen.cy - 84):zoom(0.625)
			end
		},

		-- chart info
		-- This also handles the doubles pad icon because the maxwidth also changes
		LoadActor("./PerPlayer/ChartInfo.lua", player),
		

		-- Record Texts (Machine and/or Personal)
		LoadActor("./PerPlayer/RecordTexts.lua", {player = player, hsdata = hsdata[pn]}),

		-- GS WR
		LoadActor("./PerPlayer/GSWR.lua", player)..{
			InitCommand = function(self)
				if FindInTable(WF.DefaultPane[pn], WF.WFCentricPanes) then
					self:visible(false)
				end
				self:x(player == PLAYER_1 and WideScale(-42, -84) or WideScale(-36, -10))
				self:zoom(WideScale(0.85, 1))
			end,
			OnCommand = function(self) self:y( 50 ) end,
			EvalPaneChangedMessageCommand = function(self, args)
				EvalChanged(self, args, pn, true)
			end
		},

		-- GrooveStats notification
		LoadActor("./PerPlayer/GSNotification.lua", player)
	}

	-- the lower half of ScreenEvaluation
	local lower = Def.ActorFrame{
		Name=ToEnumShortString(player).."_AF_Lower",
		OnCommand=function(self)
			self:x(_screen.cx + (player==PLAYER_1 and -155 or 155))

			-- move lower part down a litle
			self:y(32)

			-- add all panes to EvalPanes table
			local defp
			for name in ivalues(PaneNames) do
				local pane = self:GetChild(name)
				if pane then
					table.insert(WF.EvalPanes[pn], pane)
					pane:visible(false)
					if pane:GetName() == WF.DefaultPane[pn] then
						pane:visible(true)
						defp = pane
					end
				end
			end
			if defp then
				WF.ActivePane[pn] = FindInTable(defp, WF.EvalPanes[pn])
			end
		end,

		-- background quad for player stats
		Def.Quad{
			Name="LowerQuad",
			InitCommand=function(self)
				self:diffuse(color("#1E282F")):y(_screen.cy+34):zoomto( 300,180 )
			end,
			-- this background Quad may need to shrink and expand if we're playing double
			-- and need more space to accommodate more columns of arrows;  these commands
			-- are queued as needed from the InputHandler
			ExpCommand = function(self)
				self:zoomto(610,180):x(player == PLAYER_1 and 155 or -155)
			end,
			ShrCommand = function(self)
				self:zoomto(300,180):x(0)
			end,
			ShrinkP1Command=function(self)
				self:queuecommand("Shr")
			end,
			ExpandP1Command=function(self)
				if player == PLAYER_1 then self:queuecommand("Exp") else self:zoom(0) end
			end,
			ShrinkP2Command=function(self)
				self:queuecommand("Shr")
			end,
			ExpandP2Command=function(self)
				if player == PLAYER_1 then self:zoom(0) else self:queuecommand("Exp") end
			end
		},

		-- "Look at this graph."  –Some sort of meme on The Internet
		LoadActor("./PerPlayer/Graphs.lua", {player = player}),

		-- little rectangle at the bottom of the graphs
		Def.Quad{
			InitCommand=function(self)
				self:diffuse(color("#1E282F")):y(_screen.cy+188):vertalign("top"):zoomto(300, 8)
			end
		}
	}

	-- add available Panes to the lower ActorFrame via a loop
	-- Note(teejusb): Some of these actors may be nil. This is not a bug, but
	-- a feature for any panes we want to be conditional (e.g. the QR code).
	for name in ivalues(PaneNames) do
		local arg = {player = player}
		local loadname = name
		if (not loadname:find("General")) then loadname = (loadname:gsub("ITG", "")) end
		if name == "GSQR" then
			arg.hash = hashes[pn]
		elseif name:find("HighScores") or name == "Achievements" then
			arg.hsdata = hsdata
		end
		if name:find("ITG") then arg.mode = "ITG" end
		local pane = LoadActor("./PerPlayer/"..loadname, arg)
		if pane then
			pane.ShowCommand = function(self)
				self:visible(true)
			end
			pane.HideCommand = function(self)
				self:visible(false)
			end
			lower[#lower+1] = pane
		end
	end
	-- load the GS leaderboard pane, but don't actually add it to the list in the same way
	--if SL["P"..pn].ActiveModifiers.SimulateITGEnv or (#Players == 2) then
	lower[#lower+1] = LoadActor("./PerPlayer/GSLeaderboard.lua", {player = player})..{
		ShowCommand = function(self) self:visible(true) end,
		HideCommand = function(self) self:visible(false) end
	}

	lower[#lower+1] = LoadActor("./PerPlayer/GSLeaderboardEX.lua", {player = player})..{
		ShowCommand = function(self) self:visible(true) end,
		HideCommand = function(self) self:visible(false) end
	}

	lower[#lower+1] = LoadActor("./PerPlayer/GSLeaderboard_ITL.lua", {player = player})..{
		ShowCommand = function(self) self:visible(true) end,
		HideCommand = function(self) self:visible(false) end
	}

	lower[#lower+1] = LoadActor("./PerPlayer/GSLeaderboard_RPG.lua", {player = player})..{
		ShowCommand = function(self) self:visible(true) end,
		HideCommand = function(self) self:visible(false) end
	}
	--end

	-- secondary pane stuff
	local upper2, lower2
	if #Players == 1 then
		upper2 = Def.ActorFrame{
			Name=ToEnumShortString(player).."_AF_Upper2",
			OnCommand=function(self)
				if player == PLAYER_1 then
					self:x(_screen.cx + 155)
				elseif player == PLAYER_2 then
					self:x(_screen.cx - 155)
				end
			end,

			-- letter grade
			LoadActor("./PerPlayer/LetterGrade.lua", {player=player, stats=playerstats[pn]})..{
				Name = "LetterGrade2",
				InitCommand = function(self)
					self:x(108 * (player==PLAYER_1 and 1 or -1))
					self:y(_screen.cy-52)
					if WF.EnvView[pn] == "Waterfall"
					or (WF.EnvView[pn] == "ITG" and WF.DefaultSecPane ~= "General") then
						self:zoom(0)
					else
						self:zoom(0.75)
					end
				end,
				EvalPaneChangedMessageCommand = function(self, args)
					EvalChanged(self, args, pn, false, true)
				end,
				ShowCommand = function(self)
					self:linear(0.08)
					self:zoom(0.75)
				end,
				HideCommand = function(self)
					self:linear(0.08)
					self:zoom(0)
				end
			},

			-- itg grade
			LoadActor("./PerPlayer/ITGGrade.lua", player)..{
				Name = "ITGGrade2",
				InitCommand = function(self)
					self:x(108 * (player==PLAYER_1 and 1 or -1))
					self:y(_screen.cy-52)
					if WF.EnvView[pn] == "ITG"
					or (WF.EnvView[pn] == "Waterfall" and WF.DefaultSecPane ~= "GeneralITG") then
						self:zoom(0)
					else
						self:zoom(0.75)
					end
				end,
				EvalPaneChangedMessageCommand = function(self, args)
					EvalChanged(self, args, pn, true, true)
				end,
				ShowCommand = function(self)
					self:linear(0.08)
					self:zoom(0.75)
				end,
				HideCommand = function(self)
					self:linear(0.08)
					self:zoom(0)
				end
			},

			-- cleartype text
			Def.Quad{
				Name = "CTBack2",
				InitCommand = function(self)
					self:xy(20 * (player==PLAYER_1 and 1 or -1),_screen.cy - 40)
						:zoomto(90,16):diffuse(0,0,0,0.8)
					if WF.EnvView[pn] == "Waterfall"
					or (WF.EnvView[pn] == "ITG" and WF.DefaultSecPane ~= "General") then
						self:diffusealpha(0)
					end
				end,
				EvalPaneChangedMessageCommand = function(self, args)
					EvalChanged(self, args, pn, false, true)
				end,
				ShowCommand = function(self)
					self:linear(0.08)
					self:diffusealpha(0.8)
				end,
				HideCommand = function(self)
					self:linear(0.08)
					self:diffusealpha(0)
				end
			},
			LoadFont("Common Normal")..{
				Name = "CTText",
				Text = "",
				InitCommand = function(self)
					self:x(20 * (player==PLAYER_1 and 1 or -1))
					self:y(_screen.cy - 40)
					self:zoom(0.75)
					local ct = playerstats[pn]:GetClearType()
					if ct == WF.ClearTypes.Fail then
						local s = playerstats[pn]:GetSkipped() and " (skipped)" or ""
						self:settext("Failed"..s)
						self:diffuse(1,0,0,1)
					else
						self:settext(WF.ClearTypes[ct])
						if ct <= 4 then
							-- full combo tiers. colorize to judgment color.
							self:diffuse(SL.JudgmentColors["Waterfall"][ct])
						else
							-- lifebar clear tiers. colorize to lifebar color.
							local c = WF.LifeBarColors[4 - (ct - 4)]
							self:diffuse(c[1],c[2],c[3],1)
						end
					end
					if WF.EnvView[pn] == "Waterfall" 
					or (WF.EnvView[pn] == "ITG" and WF.DefaultSecPane ~= "General") then
						self:diffusealpha(0)
					end
				end,
				EvalPaneChangedMessageCommand = function(self, args)
					EvalChanged(self, args, pn, false, true)
				end,
				ShowCommand = function(self)
					self:linear(0.08)
					self:diffusealpha(1)
				end,
				HideCommand = function(self)
					self:linear(0.08)
					self:diffusealpha(0)
				end
			}
		}

		-- add secondary gs wr if not on itg mode
		if not SL["P"..pn].ActiveModifiers.SimulateITGEnv then
			upper2[#upper2+1] = LoadActor("./PerPlayer/GSWR.lua", player)..{
				InitCommand = function(self)
					if FindInTable(WF.DefaultSecPane[pn], WF.WFCentricPanes) then
						self:visible(false)
					end
					self:x(player == PLAYER_2 and -64 or -30) --WideScale(-30, -64) or WideScale(-64, -30))
					self:zoom(WideScale(0.85, 1))
				end,
				OnCommand = function(self) self:y( _screen.cy - 44 ) end,
				EvalPaneChangedMessageCommand = function(self, args)
					EvalChanged(self, args, pn, true, true)
				end
			}
		end

		lower2 = Def.ActorFrame{
			Name=ToEnumShortString(player).."_AF_Lower2",
			OnCommand = function(self)
				local otherp = (player == PLAYER_1) and 2 or 1
				self:x(_screen.cx + (player==PLAYER_1 and 155 or -155))

				-- move lower part down a litle
				self:y(32)

				-- add all panes to EvalPanes table
				local defp
				for name in ivalues(SecPaneNames) do
					local pane = self:GetChild(name.."2")
					if pane then
						table.insert(WF.EvalSecPanes, pane)
						pane:visible(false)
						if pane:GetName():sub(0,-2) == WF.DefaultSecPane then
							pane:visible(true)
							defp = pane
						end
					end
				end
				if defp then
					WF.ActivePane[otherp] = FindInTable(defp, WF.EvalSecPanes)
				end
			end,

			-- bgquad for second pane
			Def.Quad{
				Name = "SecLowerQuad",
				InitCommand = function(self)
					if #Players > 1 then self:visible(false) return end
					self:diffuse(color("#1E282F")):y(_screen.cy+34)
					:zoomto( 300,180 )
				end,
				ExpCommand = function(self)
					self:zoomto(610,180):x(player == PLAYER_2 and 155 or -155)
				end,
				ShrCommand = function(self)
					self:zoomto(300,180):x(0)
				end,
				ShrinkP1Command=function(self)
					self:queuecommand("Shr")
				end,
				ExpandP1Command=function(self)
					if player == PLAYER_2 then self:queuecommand("Exp") else self:zoom(0) end
				end,
				ShrinkP2Command=function(self)
					self:queuecommand("Shr")
				end,
				ExpandP2Command=function(self)
					if player == PLAYER_2 then self:zoom(0) else self:queuecommand("Exp") end
				end
			},

			-- bottom rect:)
			Def.Quad{
				InitCommand=function(self)
					self:diffuse(color("#1E282F")):y(_screen.cy+188):vertalign("top"):zoomto(300, 8)
				end
			},

			-- giraffes
			LoadActor("./PerPlayer/Graphs.lua", {player = player, sec = true})
		}

		for name in ivalues(SecPaneNames) do
			local arg = {player = player, sec = true}
			local aname = name.."2"
			local loadname = name
			if (not loadname:find("General")) then loadname = (loadname:gsub("ITG", "")) end
			if name == "GSQR" then
				arg.hash = hashes[pn]
			elseif name:find("HighScores") or name == "Achievements" then
				arg.hsdata = hsdata
			end
			if name:find("ITG") then arg.mode = "ITG" end
			local pane = LoadActor("./PerPlayer/"..loadname, arg)
			if pane then
				pane.ShowCommand = function(self)
					self:visible(true)
				end
				pane.HideCommand = function(self)
					self:visible(false)
				end
				lower2[#lower2+1] = pane
			end
		end

		-- add secondary side gs leaderboard
		lower2[#lower2+1] = LoadActor("./PerPlayer/GSLeaderboard.lua", {player = player, sec = true})..{
			ShowCommand = function(self) self:visible(true) end,
			HideCommand = function(self) self:visible(false) end
		}

		lower2[#lower2+1] = LoadActor("./PerPlayer/GSLeaderboardEX.lua", {player = player, sec = true})..{
			ShowCommand = function(self) self:visible(true) end,
			HideCommand = function(self) self:visible(false) end
		}
		
		lower2[#lower2+1] = LoadActor("./PerPlayer/GSLeaderboard_ITL.lua", {player = player, sec = true})..{
			ShowCommand = function(self) self:visible(true) end,
			HideCommand = function(self) self:visible(false) end
		}

		lower2[#lower2+1] = LoadActor("./PerPlayer/GSLeaderboard_RPG.lua", {player = player, sec = true})..{
			ShowCommand = function(self) self:visible(true) end,
			HideCommand = function(self) self:visible(false) end
		}
	end

	-- add lower ActorFrames to the primary ActorFrame
	t[#t+1] = lower
	if upper2 then t[#t+1] = upper2 end
	if lower2 then t[#t+1] = lower2 end
end

--[[
    "it's not much different from digging through SM code by anyone else, but I get the added bonus of occasionally
    running into variables named tonyhawk and going " :smile: "" - TaroNuke
]]

local tonyhawk = Def.Sound{
    File = THEME:GetPathS("", "WR.ogg"),
    GSWorldRecordMessageCommand = function(self)
        self:play()
    end
}
t[#t+1] = tonyhawk

-- menu overlay
local ustbl
if iscourse then
	ustbl = {}
	for player in ivalues(Players) do
		local pn = tonumber(player:sub(-1))
		if hsdata and hsdata[pn] then
			ustbl[pn] = {WF = hsdata[pn].UpscoreSongIndList, ITG = hsdata[pn].UpscoreSongIndList_ITG}
		end
	end
end
t[#t+1] = LoadActor("./MenuOverlay.lua", {CourseUpscores = ustbl})

-- The actor that will automatically upload scores to GrooveStats.
-- This is only added in "dance" mode and if the service is available.
-- Since this actor also spawns the RPG overlay it must go on top of everything else
t[#t+1] = LoadActor("./AutoSubmitScore.lua")


return t
