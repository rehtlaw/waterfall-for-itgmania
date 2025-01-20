-- the height of the footer is defined in ./Graphics/_footer.lua, but we'll
-- use it here when calculating where to position the PaneDisplay
local footer_height = 32

-- height of the PaneDisplay in pixels
local pane_height = 60

local text_zoom = WideScale(0.8, 0.9)

-- use this to suppress responses that can come back after the song/chart scrolled away
local chartchanged = false

-- -----------------------------------------------------------------------
-- Convenience function to return the SongOrCourse and StepsOrTrail for a
-- for a player.
local GetSongAndSteps = function(player)
	local SongOrCourse = (GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse()) or GAMESTATE:GetCurrentSong()
	local StepsOrTrail = (GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player)) or GAMESTATE:GetCurrentSteps(player)
	return SongOrCourse, StepsOrTrail
end

-- function to determine for some player ("P1"/"P2") whether the actors should be overridden by groovestats
local UseGSScore = function(pn)
	return SL.GrooveStats.IsConnected and (SL[pn].ApiKey ~= "")
	and ((SL[pn].ActiveModifiers.SimulateITGEnv) or SL[pn].ActiveModifiers.AlwaysGS) and
	((SL.Global.ActiveModifiers.MusicRate == 1.0) or SL[pn].ActiveModifiers.GSOverride)
end

-- -----------------------------------------------------------------------
-- requires a profile (machine or player) as an argument
-- returns formatted strings for player tag (from ScreenNameEntry) and PercentScore

local GetNameAndScore = function(SongOrCourse, StepsOrTrail, pn, itg)
    if not (SongOrCourse and StepsOrTrail) then return "","" end
    if pn and not WF.PlayerProfileStats[pn] then return "","" end

    local score, name = "0.00", "----"
    local ct, fa10, fa15
    local rate = RateFromNumber(SL.Global.ActiveModifiers.MusicRate)
    local iscourse = not SongOrCourse.GetAllSteps
    local hash = iscourse and "" or HashCacheEntry(StepsOrTrail)
    local stats = WF.FindProfileSongStatsFromSteps(SongOrCourse, StepsOrTrail, rate, hash, pn)

    if stats then
        local bestScore = pn and ((not itg) and stats.BestPercentDP or stats.BestPercentDP_ITG) or stats["HighScoreList"..(itg and "_ITG" or "")][1] and stats["HighScoreList"..(itg and "_ITG" or "")][1].PercentDP
        score = string.format("%0.2f", (bestScore or 0)/100)
        name = pn and "PB" or stats["HighScoreList"..(itg and "_ITG" or "")][1] and stats["HighScoreList"..(itg and "_ITG" or "")][1].PlayerHSName or "----"
        if pn then
            fa10 = stats.BestFAPlusCounts[1]
            fa15 = stats.BestFAPlusCounts[3]
            if not itg then
                ct = stats.BestClearType
            else
                ct = stats.Cleared_ITG and ((stats.Cleared_ITG == "C") and WF.ClearTypes.Clear or WF.ClearTypes.Fail) or WF.ClearTypes.None
            end
        end
    end

    return score, name, ct, fa10, fa15
end

-- -----------------------------------------------------------------------
local SetNameAndScore = function(name, score, nameActor, scoreActor)
	if not scoreActor or not nameActor then return end
	scoreActor:settext(score)
	nameActor:settext(name)
end
local SetClearType = function(ct, cttext)
	if (not ct) or ct == WF.ClearTypes.None then
		cttext:settext("None"):diffuse(Color.White)
	else
		cttext:settext(WF.ClearTypes[ct]):diffuse(WF.ClearTypeColor(ct))
	end
end

local GetMachineTag = function(gsEntry)
	if not gsEntry then return end
	if gsEntry["machineTag"] then
		-- Make sure we only use up to 5 characters for space concerns.
		return gsEntry["machineTag"]:sub(1, 5):upper()
	end

	-- User doesn't have a machineTag set. We'll "make" one based off of
	-- their name.
	if gsEntry["name"] then
		-- 4 Characters is the "intended" length.
		-- i feel like i can get away with 5 or 6
		return gsEntry["name"]:sub(1,5):upper()
	end

	return ""
end

local GetGSName = function(gsEntry)
	if not gsEntry then return end
	if gsEntry["name"] then
		-- Make sure we only use up to 5 characters for space concerns.
		return gsEntry["name"]
	end

	-- User doesn't have a machineTag set. We'll "make" one based off of
	-- their name.
	if gsEntry["machineTag"] then
		-- 4 Characters is the "intended" length.
		-- i feel like i can get away with 5 or 6
		return gsEntry["machineTag"]:sub(1,5):upper()
	end

	return ""
end

local GetScoresRequestProcessor = function(res, params)
    local master = params.master
    if master == nil then return end
    if GAMESTATE:GetCurrentSong() == nil then return end

    local data = res.statusCode == 200 and JsonDecode(res.body) or nil
	local requestCacheKey = params.requestCacheKey
	-- If we have data, and the requestCacheKey is not in the cache, cache it.
	if data ~= nil and SL.GrooveStats.RequestCache[requestCacheKey] == nil then
		SL.GrooveStats.RequestCache[requestCacheKey] = {
			Response=res,
			Timestamp=GetTimeSinceStart()
		}
	end

    local function processEntry(gsEntry, paneDisplay, scoreType)
        local scoreActor = paneDisplay:GetChild(scoreType.."HighScore")
        local nameActor = paneDisplay:GetChild(scoreType.."HighScoreName")
        local score = string.format("%0.2f", gsEntry["score"]/100)
        local name = scoreType == "Machine" and GetMachineTag(gsEntry) or "PB"
        SetNameAndScore(name, score, nameActor, scoreActor)
    end

    for i = 1, 2 do
        local playerStr = "player"..i
        local rivalNum = 1
		local worldRecordSet = false
		local personalRecordSet = false
        local steps = GAMESTATE:GetCurrentSteps("PlayerNumber_P"..i)
        local paneDisplay = master:GetChild("PaneDisplayP"..i)
        local cttext = paneDisplay:GetChild("CTText")
        local worldRecordSet, personalRecordSet = false, false

        if data and data[playerStr] and data[playerStr]["gsLeaderboard"] and HashCacheEntry(steps) == data[playerStr]["chartHash"]
            and (SL["P"..i].ActiveModifiers.SimulateITGEnv or SL["P"..i].ActiveModifiers.AlwaysGS)
            and ((SL.Global.ActiveModifiers.MusicRate == 1.0) or SL["P"..i].ActiveModifiers.GSOverride) then

            local leaderboardData = nil
            if data[playerStr]["gsLeaderboard"] then
                leaderboardData = data[playerStr]["gsLeaderboard"]
            end

            for gsEntry in ivalues(leaderboardData) do
                if gsEntry["rank"] == 1 then
                    processEntry(gsEntry, paneDisplay, "Machine")
                    worldRecordSet = true
                end

                if gsEntry["isSelf"] then
                    WF.PullITGScoreFromGrooveStats(i, data[playerStr]["chartHash"], gsEntry)
                    local rate = RateFromNumber(SL.Global.ActiveModifiers.MusicRate)
                    local stats = WF.FindProfileSongStatsFromSteps(GAMESTATE:GetCurrentSong(), steps, rate, HashCacheEntry(steps), i)
                    local usegspr = not stats or stats.BestPercentDP_ITG <= gsEntry["score"]
                    local ct = usegspr and (gsEntry["isFail"] and WF.ClearTypes.Fail or WF.ClearTypes.Clear) or (stats.Cleared_ITG == "F" and WF.ClearTypes.Fail or WF.ClearTypes.Clear)
                    SetClearType(ct, cttext)
                    processEntry(gsEntry, paneDisplay, "Player")
                    personalRecordSet = true
                end

                if gsEntry["isRival"] then
                    local rivalScore = paneDisplay:GetChild("Rival"..rivalNum.."Score")
                    local rivalName = paneDisplay:GetChild("Rival"..rivalNum.."Name")
                    SetNameAndScore(
                        GetMachineTag(gsEntry), 
                        string.format("%0.2f", gsEntry["score"]/100),
                        rivalName,
                        rivalScore)
                    rivalNum = rivalNum + 1
                end
            end
        end

        if not worldRecordSet then paneDisplay:GetChild("MachineHighScoreName"):queuecommand("SetDefault") end
        if not personalRecordSet then paneDisplay:GetChild("PlayerHighScoreName"):queuecommand("SetDefault") end

        if UseGSScore("P"..i) then
            for j = rivalNum, 3 do
                local rivalScore = paneDisplay:GetChild("Rival"..j.."Score")
                local rivalName = paneDisplay:GetChild("Rival"..j.."Name")
                rivalScore:settext("----")
                rivalName:settext("----")
            end
        end
    end
end

-- -----------------------------------------------------------------------
-- define the x positions of four columns, and the y positions of three rows of PaneItems
local pos = {
	col = { WideScale(-104,-133), WideScale(-36,-38), WideScale(54,76), WideScale(150, 190) },
	row = { 13, 31, 49 }
}

local num_rows = 3
local num_cols = 2

-- HighScores handled as special cases for now until further refactoring
local PaneItems = {
	-- first row
	{ name=THEME:GetString("RadarCategory","Taps"),  rc='RadarCategory_TapsAndHolds'},
	{ name=THEME:GetString("RadarCategory","Mines"), rc='RadarCategory_Mines'},
	-- { name=THEME:GetString("ScreenSelectMusic","NPS") },

	-- second row
	{ name=THEME:GetString("RadarCategory","Jumps"), rc='RadarCategory_Jumps'},
	{ name=THEME:GetString("RadarCategory","Lifts"), rc='RadarCategory_Lifts'},

	-- third row
	{ name=THEME:GetString("RadarCategory","Holds"), rc='RadarCategory_Holds'},
	{ name=THEME:GetString("RadarCategory","Rolls"), rc='RadarCategory_Rolls'},
	-- { name=THEME:GetString("RadarCategory","Fakes"), rc='RadarCategory_Fakes'},
}

-- -----------------------------------------------------------------------
local af = Def.ActorFrame{ Name="PaneDisplayMaster" }

af.OnCommand = function(self)									self:playcommand("Set") end
af.CurrentCourseChangedMessageCommand=function(self)			self:playcommand("Set") end
af.CurrentSongChangedMessageCommand=function(self)				self:playcommand("Set") end
af.CurrentStepsP1ChangedMessageCommand=function(self) self:playcommand("Set") end
af.CurrentStepsP2ChangedMessageCommand=function(self) self:playcommand("Set") end
af.CurrentTrailP1ChangedMessageCommand=function(self) self:playcommand("Set") end
af.CurrentTrailP2ChangedMessageCommand=function(self) self:playcommand("Set") end

af.SetCommand = function(self)
	-- do a little delay, then call CheckScores command
	chartchanged = true
	self:stoptweening():sleep(0.5):queuecommand("CheckScores")
end

af[#af+1] = RequestResponseActor(17, 50)..{
    Name="GetScoreRequester",
    OnCommand=function(self)
        for player in ivalues(GAMESTATE:GetHumanPlayers()) do
            -- If a profile is joined for this player, try and fetch the API key.
            -- A non-valid API key will have the field set to the empty string.
            if PROFILEMAN:GetProfile(player) then
                ParseGrooveStatsIni(player)
            end
        end
    end,
    PlayerJoinedMessageCommand=function(self, params)
        if GAMESTATE:IsHumanPlayer(params.Player) and PROFILEMAN:GetProfile(params.Player) then
            ParseGrooveStatsIni(params.Player)
        end
    end,
    CheckScoresCommand=function(self)
        local master = self:GetParent()
        chartchanged = false
        if not (GAMESTATE:GetCurrentSong() or GAMESTATE:GetCurrentCourse()) then return end
        
        -- signal everything to set default for any of these exit conditions
        local defaultall = GAMESTATE:IsCourseMode() or not IsServiceAllowed(SL.GrooveStats.GetScores) or
            not ((SL.P1.ActiveModifiers.SimulateITGEnv or SL.P1.ActiveModifiers.AlwaysGS) or (SL.P2.ActiveModifiers.SimulateITGEnv or SL.P2.ActiveModifiers.AlwaysGS)) or
            not (SL.Global.ActiveModifiers.MusicRate == 1.0 or SL.P1.ActiveModifiers.GSOverride or SL.P2.ActiveModifiers.GSOverride)

        if defaultall then
            self:GetParent():playcommand("SetDefault")
            return
        end

        local sendRequest = false
        local headers = {}
        local query = {}
        local requestCacheKey = ""

        for i=1,2 do
            local pn = "P"..i
            local steps = GAMESTATE:GetCurrentSteps("PlayerNumber_P"..i)
            local hash = steps and HashCacheEntry(steps)
            local pane = SCREENMAN:GetTopScreen():GetChild("Overlay"):GetChild("PaneDisplayMaster"):GetChild("PaneDisplayP"..i)
            if (SL[pn].ApiKey ~= "") and hash then
                query["chartHashP"..i] = hash
                headers["x-api-key-player-"..i] = SL[pn].ApiKey
                requestCacheKey = requestCacheKey .. hash .. SL[pn].ApiKey .. pn
                if UseGSScore(pn) then pane:playcommand("SetLoading") end
                sendRequest = true
            else
                pane:playcommand("SetDefault")
            end
        end

        if sendRequest then
            requestCacheKey = CRYPTMAN:SHA256String(requestCacheKey.."-player-scores")
			local params = {requestCacheKey=requestCacheKey, master=master}
			RemoveStaleCachedRequests()
			-- If the data is still in the cache, run the request processor directly
			-- without making a request with the cached response.
			if SL.GrooveStats.RequestCache[requestCacheKey] ~= nil then
				local res = SL.GrooveStats.RequestCache[requestCacheKey].Response
				GetScoresRequestProcessor(res, params)
			else
				self:playcommand("MakeGrooveStatsRequest", {
					endpoint="player-scores.php?"..NETWORK:EncodeQueryParameters(query),
					method="GET",
					headers=headers,
					timeout=10,
					callback=GetScoresRequestProcessor,
					args=params,
				})
			end
        end
    end,
}

for player in ivalues(PlayerNumber) do
	local pn = ToEnumShortString(player)
	local pnum = tonumber(player:sub(-1))
	
	local itg = SL[pn].ActiveModifiers.SimulateITGEnv

	af[#af+1] = Def.ActorFrame{ Name="PaneDisplay"..ToEnumShortString(player) }

	local af2 = af[#af]

	af2.InitCommand=function(self)
		self:visible(GAMESTATE:IsHumanPlayer(player))

		if player == PLAYER_1 then
			self:x(_screen.w * 0.25 - 46)
		elseif player == PLAYER_2 then
			self:x(_screen.w * 0.75 + 100)
		end

		self:y(_screen.h - footer_height - pane_height)
	end

	af2.PlayerJoinedMessageCommand=function(self, params)
		if player==params.Player then
			-- ensure BackgroundQuad is colored before it is made visible
			self:GetChild("BackgroundQuad"):playcommand("Set")
			self:visible(true)
				:zoom(0):croptop(0):bounceend(0.3):zoom(1)
				:playcommand("Update")
		end
	end
	-- player unjoining is not currently possible in SL, but maybe someday
	af2.PlayerUnjoinedMessageCommand=function(self, params)
		if player==params.Player then
			self:accelerate(0.3):croptop(1):sleep(0.01):zoom(0):queuecommand("Hide")
		end
	end
	af2.HideCommand=function(self) self:visible(false) end

	-- -----------------------------------------------------------------------
	-- colored background Quad

	af2[#af2+1] = Def.Quad{
		Name="BackgroundQuad",
		InitCommand=function(self)
			self:zoomtowidth(_screen.w/2-10)
			self:zoomtoheight(pane_height)
			self:vertalign(top)
			self:diffuse(PlayerColor(player))
		end
	}

	-- -----------------------------------------------------------------------
	-- loop through the six sub-tables in the PaneItems table
	-- add one BitmapText as the label and one BitmapText as the value for each PaneItem

	for i, item in ipairs(PaneItems) do
		local col = ((i-1) % num_cols) + 1
		local row = math.floor((i-1) / num_cols) + 1
		local xPos = pos.col[col]
		local yPos = pos.row[row]

		af2[#af2+1] = Def.ActorFrame{
			Name=item.name,

			-- numerical value
			LoadFont("Common Normal")..{
				InitCommand=function(self)
					self:zoom(text_zoom):diffuse(Color.Black):horizalign(right)
					self:xy(xPos, yPos)
				end,

				SetCommand=function(self)
					local SongOrCourse, StepsOrTrail = GetSongAndSteps(player)
					if not SongOrCourse then self:settext("?"); return end
					if not StepsOrTrail then self:settext(""); return end

					if item.rc then
						local val = StepsOrTrail:GetRadarValues(player):GetValue(item.rc)
						self:settext(val >= 0 and val or "?")
					end
				end
			},

			-- label
			LoadFont("Common Normal")..{
				Text=item.name,
				InitCommand=function(self)
					self:zoom(text_zoom):diffuse(Color.Black):horizalign(left)
					self:xy(xPos + 3, yPos)
				end
			},
		}
	end

	-- Machine/World Record Machine Tag
	af2[#af2+1] = LoadFont("Common Normal")..{
		Name="MachineHighScoreName",
		InitCommand=function(self)
			self:zoom(text_zoom):diffuse(Color.Black):maxwidth(30)
			self:x(pos.col[3]-50*text_zoom)
			self:y(pos.row[1])
		end,
		SetCommand=function(self)
			-- just set blank, this is controlled elsewhere
			self:settext("----")
		end,
		SetLoadingCommand = function(self) self:settext(". . .") end,
		SetDefaultCommand=function(self)
			local SongOrCourse, StepsOrTrail = GetSongAndSteps(player)
			local machine_score, machine_name = GetNameAndScore(SongOrCourse, StepsOrTrail, nil, itg)
			self:settext(machine_name or ""):diffuse(Color.Black)
			DiffuseEmojis(self)
			self:GetParent():GetChild("MachineHighScore"):settext(machine_score or ""):diffuse(Color.Black)
		end
	}

	-- Machine/World Record HighScore
	af2[#af2+1] = LoadFont("Common Normal")..{
		Name="MachineHighScore",
		InitCommand=function(self)
			self:zoom(text_zoom):diffuse(Color.Black):horizalign(right)
			self:x(pos.col[3]+20*text_zoom)
			self:y(pos.row[1])
		end,
		SetCommand=function(self)
			self:settext("----")
		end,
		SetLoadingCommand = function(self) self:settext(". . .") end
	}

	-- Player Profile/GrooveStats Machine Tag  ("PB" text in my case)
	af2[#af2+1] = LoadFont("Common Normal")..{
		Name="PlayerHighScoreName",
		Text = "PB",
		InitCommand=function(self)
			self:zoom(text_zoom):diffuse(Color.Black):maxwidth(30)
			self:x(pos.col[3]-50*text_zoom)
			self:y(pos.row[2])
			if not PROFILEMAN:IsPersistentProfile(player) then self:visible(false) end
		end,
		SetCommand = function(self) self:settext("PB") end,
		SetDefaultCommand=function(self)
			local SongOrCourse, StepsOrTrail = GetSongAndSteps(player)
			local player_score, player_name, ct, fa10, fa15
			if UseGSScore(pn) then self:settext("LOCAL") end
			if PROFILEMAN:IsPersistentProfile(player) then
				player_score, player_name, ct, fa10, fa15 = 
					GetNameAndScore(SongOrCourse, StepsOrTrail, pnum, itg)
			else
				self:visible(false)
			end
			self:GetParent():GetChild("PlayerHighScore"):settext(player_score or "")
			SetClearType(ct, self:GetParent():GetChild("CTText"))
			if (not UseGSScore(pn)) and WF.PlayerProfileStats[pnum] then
				local song, steps = GetSongAndSteps(player)
				if not steps then return end
				local rvarg = (not GAMESTATE:IsCourseMode()) and player or nil
				local stepcount = steps:GetRadarValues(rvarg):GetValue("RadarCategory_TapsAndHolds")
				local p10, p15
				if stepcount == 0 then p10 = "0.00" p15 = "0.00"
				elseif stepcount < 0 then p10 = "?" p15 = "?"
				else
					p10 = string.format("%0.2f", math.floor(((fa10 or 0)/stepcount)*10000)/100)
					p15 = string.format("%0.2f", math.floor(((fa15 or 0)/stepcount)*10000)/100)
				end
				self:GetParent():GetChild("Rival2Score"):settext(p10)
				self:GetParent():GetChild("Rival3Score"):settext(p15)
			end
		end
	}

	-- Player Profile/GrooveStats HighScore
	af2[#af2+1] = LoadFont("Common Normal")..{
		Name="PlayerHighScore",
		InitCommand=function(self)
			self:zoom(text_zoom):diffuse(Color.Black):horizalign(right)
			self:x(pos.col[3]+20*text_zoom)
			self:y(pos.row[2])
			if not PROFILEMAN:IsPersistentProfile(player) then self:visible(false) end
		end,
		SetCommand=function(self)
			self:settext("----")
		end,
		SetLoadingCommand = function(self) self:settext(". . .") end
	}

	-- ct quad/text
	local quadwidth = (not itg) and WideScale(84, 100) or 72
	af2[#af2+1] = Def.Quad{
		InitCommand = function(self)
			if not WF.PlayerProfileStats[pnum] then self:visible(false) end
			self:x(pos.col[3]-WideScale(18,20)):y(pos.row[3]):zoomto(quadwidth, 18):diffuse(0,0,0,0.9)
		end
	}

	af2[#af2+1] = LoadFont("Common Normal")..{
		Name="CTText",
		Text="",
		InitCommand=function(self)
			if not WF.PlayerProfileStats[pnum] then self:visible(false) end
			self:zoom(text_zoom):diffuse(Color.White)
			self:x(pos.col[3]-WideScale(18,20))
			self:y(pos.row[3])
			self:maxwidth((quadwidth-2)/text_zoom)
		end,
		SetCommand=function(self)
			self:settext("")
		end
	}

	-- Add actors for Rival score data. Hidden by default
	-- We position relative to column 3 for spacing reasons.
	for i=1,3 do
		local xPosName = pos.col[3]+WideScale(50, 54)*text_zoom
		local xPosScore = pos.col[3]+WideScale(122, 125)*text_zoom
		local yPos = pos.row[i]

		-- Rival Machine Tag
		af2[#af2+1] = LoadFont("Common Normal")..{
			Name="Rival"..i.."Name",
			InitCommand=function(self)
				self:zoom(text_zoom):diffuse(Color.Black):maxwidth(30)
				self:xy(xPosName, yPos)
			end,
			OnCommand=function(self)
				self:visible(WF.PlayerProfileStats[pnum] ~= nil)
			end,
			SetCommand=function(self)
				if UseGSScore(pn) then
					self:settext("----")
				else
					local faText = (i == 1 and "FA+") or (i == 2 and "10ms") or (i == 3 and "15ms")
					self:settext(faText)
				end
			end,
			SetLoadingCommand = function(self) self:settext(". . .") end
		}

		-- Rival HighScore
		af2[#af2+1] = LoadFont("Common Normal")..{
			Name="Rival"..i.."Score",
			InitCommand=function(self)
				self:zoom(text_zoom):diffuse(Color.Black):horizalign(right)
				self:xy(xPosScore, yPos)
			end,
			OnCommand=function(self)
				self:visible(WF.PlayerProfileStats[pnum] ~= nil and (UseGSScore(pn) or i ~= 1))
			end,
			SetCommand=function(self)
				self:settext("----")
			end,
			SetLoadingCommand = function(self) self:settext(". . .") end
		}
	end

end

return af
