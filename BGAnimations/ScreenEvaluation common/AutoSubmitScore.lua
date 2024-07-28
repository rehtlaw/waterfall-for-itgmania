WF.RPGData = {}
if not IsServiceAllowed(SL.GrooveStats.AutoSubmit) then return end

local NumEntries = 10

local SetEntryText = function(rank, name, score, date, actor)
	if actor == nil then return end

	actor:GetChild("Rank"):settext(rank)
	actor:GetChild("Name"):settext(name)
	actor:GetChild("Score"):settext(score)
	actor:GetChild("Date"):settext(date)
end

local GetJudgmentCounts = function(player)
	local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
	local pnum = tonumber(player:sub(-1))
    local judgmentCounts = {}

    judgmentCounts["fantasticPlus"] = pss:GetTapNoteScores("TapNoteScore_W1")
    judgmentCounts["fantastic"] = WF.ITGJudgmentCounts[pnum][1]-pss:GetTapNoteScores("TapNoteScore_W1")
	judgmentCounts["excellent"] = WF.ITGJudgmentCounts[pnum][2]
	judgmentCounts["great"] = WF.ITGJudgmentCounts[pnum][3]

	if WF.SelectedErrorWindowSetting == 3 then
		-- Decents are only enabled when fault window is set to "Extended"
		judgmentCounts["decent"] = WF.ITGJudgmentCounts[pnum][4]
	end
	if WF.SelectedErrorWindowSetting ~= 2 then
		-- Way offs are enabled when fault window is either Enabled or Extended
		-- In other words, not disabled
		judgmentCounts["wayOff"] = WF.ITGJudgmentCounts[pnum][5]
	end
	judgmentCounts["miss"] = WF.ITGJudgmentCounts[pnum][6]

	judgmentCounts["totalSteps"] = pss:GetRadarPossible():GetValue("RadarCategory_TapsAndHolds")

	local possible = pss:GetRadarPossible()
	local actual = pss:GetRadarActual()

	judgmentCounts["minesHit"] 		= possible:GetValue("RadarCategory_Mines")-actual:GetValue("RadarCategory_Mines")
	judgmentCounts["totalMines"]	= possible:GetValue("RadarCategory_Mines")
	judgmentCounts["holdsHeld"]		= actual:GetValue("RadarCategory_Holds")
	judgmentCounts["totalHolds"]	= possible:GetValue("RadarCategory_Holds")
	judgmentCounts["rollsHeld"]		= actual:GetValue("RadarCategory_Rolls")
	judgmentCounts["totalRolls"]	= possible:GetValue("RadarCategory_Rolls")
    return judgmentCounts
end

local GetRescoredJudgmentCounts = function(player)
    -- TODO: actual implement recalcs
	local pn = ToEnumShortString(player)

	local translation = {
		["W0"] = "fantasticPlus",
		["W1"] = "fantastic",
		["W2"] = "excellent",
		["W3"] = "great",
		["W4"] = "decent",
		["W5"] = "wayOff",
	}

	local rescored = {
		["fantasticPlus"] = 0,
		["fantastic"] = 0,
		["excellent"] = 0,
		["great"] = 0,
		["decent"] = 0,
		["wayOff"] = 0
	}
	
	-- for i=1,GAMESTATE:GetCurrentStyle():ColumnsPerPlayer() do
	-- 	for window, name in pairs(translation) do
	-- 		rescored[name] = rescored[name] + SL[pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].column_judgments[i]["Early"][window]
	-- 	end
	-- end

	return rescored
end

local AttemptDownloads = function(res)
	local data = JsonDecode(res.body)
	for i=1,2 do
		local playerStr = "player"..i
		local events = {"rpg", "itl"}

		for event in ivalues(events) do
			if data and data[playerStr] and data[playerStr][event] then
				local eventData = data[playerStr][event]
				local eventName = eventData["name"] or "Unknown Event"

				-- See if any quests were completed.
				if eventData["progress"] and eventData["progress"]["questsCompleted"] then
					local quests = eventData["progress"]["questsCompleted"]
					-- Iterate through the quests...
					for quest in ivalues(quests) do
						-- ...and check for any unlocks.
						if quest["songDownloadUrl"] then
							local url = quest["songDownloadUrl"]
							local title = quest["title"] or ""

							if ThemePrefs.Get("SeparateUnlocksByPlayer") then
								local profileName = "NoName"
								local player = "PlayerNumber_P"..i
								if (PROFILEMAN:IsPersistentProfile(player) and
										PROFILEMAN:GetProfile(player)) then
									profileName = PROFILEMAN:GetProfile(player):GetDisplayName()
								end
								title = title.." - "..profileName
								DownloadEventUnlock(url, "["..eventName.."] "..title, eventName.." Unlocks - "..profileName)
							else
								DownloadEventUnlock(url, "["..eventName.."] "..title, eventName.." Unlocks")
							end
						end
					end
				end
			end
		end
	end
end

local AutoSubmitRequestProcessor = function(res, overlay)
	local hasRpg = false
	local showRpg = false
	local rpgname

    local shouldDisplayOverlay = false
	
	local shownotif = {false, false}
	local wrplr = 0
	
	if res.error or res.statusCode ~= 200 then
		local error = res.error and ToEnumShortString(res.error) or nil
		if error == "Timeout" then
            if GAMESTATE:IsSideJoined(PLAYER_1) then overlay:GetChild("P1_AF_Upper"):GetChild("GSNotification"):playcommand("SetTimeout") end
            if GAMESTATE:IsSideJoined(PLAYER_2) then overlay:GetChild("P2_AF_Upper"):GetChild("GSNotification"):playcommand("SetTimeout") end
		elseif error or (res.statusCode ~= nil and res.statusCode ~= 200) then
            if GAMESTATE:IsSideJoined(PLAYER_1) then overlay:GetChild("P1_AF_Upper"):GetChild("GSNotification"):playcommand("SetFail") end
            if GAMESTATE:IsSideJoined(PLAYER_2) then overlay:GetChild("P2_AF_Upper"):GetChild("GSNotification"):playcommand("SetFail") end
		end
		return
	end

    local data = JsonDecode(res.body)
    for i = 1, 2 do
        local playerStr = "player"..i
        local entryNum = 1
        local rivalNum = 1

        if data and data[playerStr] then
            local steps = GAMESTATE:GetCurrentSteps("PlayerNumber_P"..i)
            local loweraf = overlay:GetChild("P"..i.."_AF_Lower")
            local loweraf2 = overlay:GetChild("P"..i.."_AF_Lower2")
            if HashCacheEntry(steps) == data[playerStr]["chartHash"] then
                -- show notification based on result
                if data[playerStr]["result"] == "score-added" or data[playerStr]["result"] == "improved"
                    or data[playerStr]["result"] == "score-not-improved"
                    or data[playerStr]["result"] == "score-improved" then
                    shownotif[i] = true

                    -- set qr panes to "already submitted"
                    if loweraf:GetChild("GSQR") then
                        loweraf:GetChild("GSQR"):playcommand("SetAlreadySubmitted")
                    end
                    if loweraf2 and loweraf2:GetChild("GSQR2") then
                        loweraf2:GetChild("GSQR2"):playcommand("SetAlreadySubmitted")
                    end
                end

                if data[playerStr]["isRanked"] then
                    -- call command for gs leaderboard panes to show
                    if loweraf:GetChild("GSLeaderboard") then
                        loweraf:GetChild("GSLeaderboard"):playcommand("AddGSLeaderboard",
                            data[playerStr]["gsLeaderboard"])
                    end
                    if loweraf2 and loweraf2:GetChild("GSLeaderboard2") then
                        loweraf2:GetChild("GSLeaderboard2"):playcommand("AddGSLeaderboard",
                            data[playerStr]["gsLeaderboard"])
                    end

                    -- wr stuff
                    if data[playerStr]["result"] ~= "score-not-improved" then
                        for gsEntry in ivalues(data[playerStr]["gsLeaderboard"]) do
                            if gsEntry["isSelf"] and gsEntry["rank"] == 1 then
                                -- in the event both leaderboards return a self rank of 1, player 2 is
                                -- more "up to date" so just take the highest player that received it
                                wrplr = i
                                break
                            end
                        end
                    end
                end

                if data[playerStr]["itl"] then
                    -- call command for gs leaderboard panes to show
                    if loweraf:GetChild("ITLLeaderboard") then
                        loweraf:GetChild("ITLLeaderboard"):playcommand("AddITLLeaderboard",
                            data[playerStr]["itl"]["itlLeaderboard"])
                    end
                    if loweraf2 and loweraf2:GetChild("GSLeaderboard2") then
                        loweraf2:GetChild("ITLLeaderboard2"):playcommand("AddITLLeaderboard",
                            data[playerStr]["itl"]["itlLeaderboard"])
                    end
                end

                if data[playerStr]["rpg"] then
                    -- call command for gs leaderboard panes to show
                    if loweraf:GetChild("RPGLeaderboard") then
                        loweraf:GetChild("RPGLeaderboard"):playcommand("AddRPGLeaderboard",
                            data[playerStr]["rpg"]["rpgLeaderboard"])
                    end
                    if loweraf2 and loweraf2:GetChild("GSLeaderboard2") then
                        loweraf2:GetChild("RPGLeaderboard2"):playcommand("AddRPGLeaderboard",
                            data[playerStr]["rpg"]["rpgLeaderboard"])
                    end
                end

                -- Getting this ready for ITL release, but it is not fully functional.
                -- Currently, if you play a song in both RPG and ITL, it will only show 
                -- the results for ITL. Disabling the RPG tree entirely for now.
                -- Hopefully I'll get this ready by the time RPG6 is out
                -- Zarzob

                if data[playerStr]["rpg"] or data[playerStr]["itl"] then
                    hasRpg = true
                    --rpgname = data[playerStr]["rpg"]["name"]
                    WF.RPGData[i] = data[playerStr]["rpg"]

                    -- add option to L+R menu
                    table.insert(WF.MenuSelections[i], 
                        { "View Event stats", true })
                    overlay:GetChild("MenuOverlay"):queuecommand("Update")

                    -- if itg mode, set showrpg flag
                    --if SL["P"..i].ActiveModifiers.SimulateITGEnv then
                    showRpg = true
                    --end
                end

                --if data[playerStr]["itl"] then
                --	hasRpg = true
                --	rpgname = data[playerStr]["itl"]["name"]
                --	WF.RPGData[i] = data[playerStr]["itl"]
                --
                --	-- add option to L+R menu
                --	table.insert(WF.MenuSelections[i], 
                --	{ "View ITL 2022 stats", true })
                --	overlay:GetChild("MenuOverlay"):queuecommand("Update")
                --
                --	-- if itg mode, set showrpg flag
                --	if SL["P"..i].ActiveModifiers.SimulateITGEnv then
                --		showRpg = true
                --	end
                --end
            end
        end
    end

    -- now do one more loop to show the proper notifications
    for i = 1, 2 do
        -- set shownotif to false if player got wr, and broadcast wr message
        if wrplr == i then
            shownotif[i] = false
            MESSAGEMAN:Broadcast("GSWorldRecord", {player = "PlayerNumber_P"..i})
        end

        if shownotif[i] then
            local notifarg = ((hasRpg) and (not showRpg))
            overlay:GetChild("P"..i.."_AF_Upper"):GetChild("GSNotification")
            :playcommand("SetSuccess", {notifarg, rpgname})
        end

        if showRpg then
            local rpgAf = overlay:GetChild("AutoSubmitMaster"):GetChild("RpgOverlay")
            :GetChild("P"..i.."RpgAf")
            if rpgAf and res["data"]["player"..i] and res["data"]["player"..i]["rpg"] then
                rpgAf:playcommand("Show", {data=res["data"]["player"..i]})
            end
        end

        if showRpg then
            local rpgAf = overlay:GetChild("AutoSubmitMaster"):GetChild("RpgOverlay")
            :GetChild("P"..i.."RpgAf")
            if rpgAf and res["data"]["player"..i] and res["data"]["player"..i]["itl"] then
                rpgAf:playcommand("Show", {data=res["data"]["player"..i]})
            end
        end


    end

    -- finally, if we determined to show rpg automatically, do that now
    if showRpg then
        overlay:GetChild("AutoSubmitMaster"):GetChild("RpgOverlay"):visible(true)
        overlay:queuecommand("DirectInputToRpgHandler")
    end

    if ThemePrefs.Get("AutoDownloadUnlocks") then
        AttemptDownloads(res)
    end
end

local CreateCommentString = function(player)
	local pn = ToEnumShortString(player)
	local pnum = tonumber(player:sub(-1))
	local mods = SL[pn].ActiveModifiers
	local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
	local useitg = mods.SimulateITGEnvironment
	local itgscore = FormatPercentScore(WF.GetITGPercentDP(player, WF.GetITGMaxDP(player)))
	
	-- Waterfall score
	local PercentDP = pss:GetPercentDancePoints()
	local wfscore = FormatPercentScore(PercentDP)
	
	-- for FA%, holds, rolls, mines
	local possible = pss:GetRadarPossible()
	local actual = pss:GetRadarActual()	

	-- 10ms and 15ms fa %
	local fa10 = math.floor(WF.FAPlusCount[pnum][1]/possible:GetValue("RadarCategory_TapsAndHolds")*10000)/100
	local fa15 = math.floor(pss:GetTapNoteScores("TapNoteScore_W1")/possible:GetValue("RadarCategory_TapsAndHolds")*10000)/100
	
	-- Dropped holds/rolls, mines
	local drHold = possible:GetValue("RadarCategory_Holds")-actual:GetValue("RadarCategory_Holds")
	local drRoll = possible:GetValue("RadarCategory_Rolls")-actual:GetValue("RadarCategory_Rolls")
	local mines  = possible:GetValue("RadarCategory_Mines")-actual:GetValue("RadarCategory_Mines")
	
	-- Options for speed mod and no mines
	local options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
	
	local itgtable = {}
	local others = {}
	-- various conditions determine what windows are "enabled" or modified for itg.
	-- tap note string is in the format f,e,g,d,w,m
	-- if a window is disabled, replace it with an x. if truncated, add a *.
	local taps = {}
	for i = 1, 6 do
		table.insert(taps, tostring(WF.ITGJudgmentCounts[pnum][i]))
	end
	local unknownw5 = false
	
	-- a lot of the following logic was written specifically with dimo in mind
	local quint15 = false
	local quint10 = false
	
	if wfscore == "100.00%" then 
		local text
		quint15 = true
		if fa10 == 100 then 
			text = "10ms " 
			quint10 = true
		else text = "15ms " end
 		table.insert(itgtable,text.."Quint") 
	end
	
	-- Display white count if they have 10 or 15ms enabled
	-- but only show the 15ms count because that's what people refer to as "whites"
	local whites = taps[1]-pss:GetTapNoteScores("TapNoteScore_W1")
	
	if mods.FAPlus ~= 0 or not useitg
	then
		-- only show white count if they are >0
		if whites > 0 then table.insert(itgtable,whites.."w") end
	end
	
	-- show excellents, greats, misses if they get them
	if taps[2] ~= "0" then table.insert(itgtable,taps[2].."e") end	
	if taps[3] ~= "0" then table.insert(itgtable,taps[3].."g") end	
	if taps[6] ~= "0" then table.insert(itgtable,taps[6].."m") end
	
	-- Boys on/off. Only display boys on/off if there are 0 boys
	-- Boys > 0 implies they are on
	-- Doesn't really matter if it's the "enabled" or "extended" window	
	local boys = taps[4] + taps[5]	
	if boys == 0 then	
		if WF.SelectedErrorWindowSetting == 2 then
			table.insert(others,"Boys off")
		else 
			table.insert(others,"Boys on")
		end
	else
		local name = boys == 1 and "Boy" or "Boys"
		table.insert(itgtable,taps[4] + taps[5].." " .. name)
	end
	
	-- if for some reason you have full fantastic combo and hit a mine or dropped a hold,
	-- I'm truly sorry, you just lost $800. Logic to deal with that here
	if taps[2] == "0" 
		and taps[3] == "0" 
		and taps[4] == "0"
		and taps[5] == "0"
		and taps[6] == "0"
		and itgscore ~= "100.00%"
	then
		table.insert(itgtable,"$800 Boom") 
	end
	
	-- Cheat mod
	steps = (not GAMESTATE:IsCourseMode()) and GAMESTATE:GetCurrentSteps(player)
			or GAMESTATE:GetCurrentTrail(player)
	local td = (not iscourse) and steps:GetTimingData()
    if (iscourse or 
		(not steps:IsDisplayBpmConstant()) 
		or td:HasStops() 
		or td:HasScrollChanges() 
		or td:HasSpeedChanges() 
		or td:HasNegativeBPMs() 
		-- this will mostly be used for drift, but there are songs with a constant DisplayBPM
		-- that still have significant bpm changes, such as Utopia X-Mod Special from Crapyard
		-- Better to show what mod they used if unsure
		or td:HasBPMChanges() 
		or td:HasWarps()) then
		if (options:CMod()) then table.insert(others, "Cmod") 
		elseif (options:MMod()) then table.insert(others, "Mmod")
		else table.insert(others, "Xmod")
		end        
    end

	local significantmods = GetSignificantMods(player)
	local modnames = {"Left","Right","Mirror","Shuffle","SuperShuffle"}
	for mod in ivalues(significantmods) do
		local findmod = FindInTable(mod, modnames)
		if findmod then
			if mod == "SuperShuffle" then mod = "Blender" end
			table.insert(others,mod)
		end
	end
	
	-- Dropped holds/Rolls, mines
	if mines > 0 then
		local name = mines == 1 and "Mine" or "Mines"
		table.insert(others, mines.. " ".. name)
	end
	
	-- This could probably be coded better
	if drHold > 0 and drRoll > 0 then
		local text = "Dropped Hold/Rolls: " .. drHold+drRoll
		table.insert(others,text)
	end
	if drHold > 0 and drRoll == 0 then
		local text = "Dropped Holds: " .. drHold
		table.insert(others,text)
	end
	if drRoll > 0 and drHold == 0 then
		local text = "Dropped Rolls: " .. drRoll
		table.insert(others,text)
	end

	-- Add in adjusted BPM and rate mod if it is > 1.00
	local rate = SL.Global.ActiveModifiers.MusicRate
	local bpm = StringifyRoundedDisplayBPMs()	
	if rate > 1 then table.insert(others,rate .. " rate (" .. bpm .. " BPM" ..")") end
	
	-- Add "No Mines" if they have disabled mines AND there are mines in the chart.
	-- Disabling mines puts the pss radar values to 0
	-- I created a global variable for mines from here
	-- BGAnimations\ScreenGameplay overlay\MineCount.lua
	local num_mines = GAMESTATE:Env()["TotalMines" .. pn]
	
	if options:NoMines() and num_mines > 0 then
		table.insert(others,"No Mines")
	end
	
	-- hehe, fap
	local fapstring
	local fa10string = "10ms: " .. fa10 .. "%"
	local fa15string = "15ms: " .. fa15 .. "%"
	
	-- Only show fa% for when it's not a 15/10ms quint because it's already 
	-- told earlier in the comment
	if not quint15 then
		fapstring = fa15string .. " " .. fa10string
	elseif quint15 and not quint10 then 
		fapstring = fa10string
	end
	table.insert(others,fapstring)
	
	-- Waterfall score
	table.insert(others,"WF "..wfscore)
	
	local comment = table.concat(itgtable, " ") .. " | " .. table.concat(others, " | ")
	
	-- The limit for gs is 150 characters, pretty sure the longest possible string is ~2/3 of that.
	-- but on the weird off chance this happens to be even longer (??) just substring it
	comment = comment:sub(1, 150)
	
	return comment
end

local CreateExtraSubmissionString = function(player)
	
	-- Used to send extra information to GrooveStats
	-- initially used to create the extra fields needed for ITL 2022
	--usedCmod (boolean)	
	--JudgmentCounts 
	-- 		fantasticPlus
	-- 		fantastic
	-- 		excellent
	-- 		great
	-- 		decent
	-- 		wayOff
	-- 		miss
	-- 		totalSteps
	-- 		minesHit
	-- 		totalMines
	-- 		holdsHeld
	-- 		totalHolds
	-- 		rollsHeld
	-- 		totalRolls
	
	local pn = ToEnumShortString(player)
	local pnum = tonumber(player:sub(-1))
	local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)

	-- Cheat mod
	local options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")	
	local usedCmod = options:CMod() and true or false
	
	-- Create table for ITL
	local judgmentCounts = {}
	
	-- fantasticPlus and fantastic
	local blues = pss:GetTapNoteScores("TapNoteScore_W1")
	local whites = WF.ITGJudgmentCounts[pnum][1]-pss:GetTapNoteScores("TapNoteScore_W1")
	
	judgmentCounts["fantasticPlus"] = blues
	judgmentCounts["fantastic"] = whites
	judgmentCounts["excellent"] = WF.ITGJudgmentCounts[pnum][2]
	judgmentCounts["great"] = WF.ITGJudgmentCounts[pnum][3]
	if WF.SelectedErrorWindowSetting == 3 then
		-- Decents are only enabled when fault window is set to "Extended"
		judgmentCounts["decent"] = WF.ITGJudgmentCounts[pnum][4]
	end
	if WF.SelectedErrorWindowSetting ~= 2 then
		-- Way offs are enabled when fault window is either Enabled or Extended
		-- In other words, not disabled
		judgmentCounts["wayOff"] = WF.ITGJudgmentCounts[pnum][5]
	end
	judgmentCounts["miss"] = WF.ITGJudgmentCounts[pnum][6]
	
	local totalSteps = pss:GetRadarPossible():GetValue("RadarCategory_TapsAndHolds")

	judgmentCounts["totalSteps"] = totalSteps
	
	local possible = pss:GetRadarPossible()
	local actual = pss:GetRadarActual()	
	
	-- Dropped holds/rolls, mines
	local minesHit  = possible:GetValue("RadarCategory_Mines")-actual:GetValue("RadarCategory_Mines")
	local totalMines = possible:GetValue("RadarCategory_Mines")
	
	local holdsHeld = actual:GetValue("RadarCategory_Holds")
	local totalHolds = possible:GetValue("RadarCategory_Holds")
	
	local rollsHeld = actual:GetValue("RadarCategory_Rolls")
	local totalRolls = possible:GetValue("RadarCategory_Rolls")
		
	judgmentCounts["minesHit"] 		= minesHit
	judgmentCounts["totalMines"]	= totalMines
	judgmentCounts["holdsHeld"]		= holdsHeld
	judgmentCounts["totalHolds"]	= totalHolds
	judgmentCounts["rollsHeld"]		= rollsHeld
	judgmentCounts["totalRolls"]	= totalRolls
	
	return usedCmod, judgmentCounts
end



local af = Def.ActorFrame {
	Name="AutoSubmitMaster",
	RequestResponseActor(17, 50)..{
		OnCommand=function(self)
			local sendRequest = false
            local headers = {}
			local query = {
				maxLeaderboardResults=NumEntries,
			}
            local body = {}

			local rate = SL.Global.ActiveModifiers.MusicRate * 100
			if rate < 100 then return end
			
			for i=1,2 do
				local player = "PlayerNumber_P"..i
				local pn = ToEnumShortString(player)

				local _, valid = ValidForGrooveStats(player)
				local stats = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)

				if GAMESTATE:IsHumanPlayer(player) and
						not WF.ITGFailed[i] and
						valid and
						SL[pn].IsPadPlayer then
						
					local usedCmod, _ = CreateExtraSubmissionString(player)
			
					local percentDP = stats:GetPercentDancePoints()
					local score = tonumber((WF.ITGScore[i]:gsub("%.", "")))

					local profileName = ""
					if PROFILEMAN:IsPersistentProfile(player) and PROFILEMAN:GetProfile(player) then
						profileName = PROFILEMAN:GetProfile(player):GetDisplayName()
					end

					local steps = GAMESTATE:GetCurrentSteps(player)
					local hash = HashCacheEntry(steps)
					
					if (SL[pn].ApiKey ~= "") and (hash) and (hash ~= "") then
                        query["chartHashP"..i] = hash
                        headers["x-api-key-player-"..i] = SL[pn].ApiKey

						body["player"..i] = {
							rate=rate,
							score=score,
                            judgmentCounts=GetJudgmentCounts(player),
                            rescoreCounts=GetRescoredJudgmentCounts(player),
							usedCmod=usedCmod,
							comment=CreateCommentString(player),
							profileName=profileName,
						}
						sendRequest = true
					end
				end
			end
			-- Only send the request if it's applicable.
			if sendRequest then
				self:playcommand("MakeGrooveStatsRequest", {
					endpoint="score-submit.php?"..NETWORK:EncodeQueryParameters(query),
					method="POST",
					headers=headers,
					body=JsonEncode(body),
					timeout=30,
					callback=AutoSubmitRequestProcessor,
					args=SCREENMAN:GetTopScreen():GetChild("Overlay"):GetChild("ScreenEval Common"),
				})
			end
		end
	}
}

af[#af+1] = LoadActor("./RpgOverlay.lua")

return af
