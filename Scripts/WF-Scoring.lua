-- Stuff relating to tracking clear types and grades is in here

--- itg judgment/lifebar stuff ---
-- similarly to how SL already tracks offsets, this will store all judgment events that occur and at each time
-- in per player tables. each item should have the format { Judgement, NewLifeValue, MusicTimestamp }
-- note: we actually don't care about note offsets here; i'm not building another scatterplot

-- all itg judgments will be indexed according to this table from 1-9
WF.ITGJudgments = enum_table({ "Fantastic", "Excellent", "Great", "Decent", "Way Off", "Miss", "Held", "Dropped", "Mine" })

-- per player variables
WF.ITGJudgmentData = {{},{}}
WF.ITGJudgmentCounts = {}
WF.ITGJudgmentCountsPerSongInCourse = {}
WF.ITGLife = {0.5,0.5}
WF.ITGDangerThreshold = 0.25
WF.ITGRegenCombo = {0,0}
WF.ITGFailed = {false,false}
WF.ITGSongInCourseAtFail = {-1,-1}
WF.ITGScore = {"0.00","0.00"}
WF.ITGDP = {0,0}
WF.ITGDP_CurSongInCourse = {0,0}
-- MaxDP is the maximum dp possible for the whole chart
WF.ITGMaxDP = {0,0}
WF.ITGMaxDP_CurSongInCourse = {0,0}
-- CurMaxDP is the maximum dp that could be possible to have -right now- in the chart
-- (so increase by 5 every tap and hold). These are needed for subtractive scoring.
WF.ITGCurMaxDP = {0,0}
WF.ITGCurMaxDP_CurSongInCourse = {0,0}
WF.ITGCombo = {0,0}
WF.ITGFCType = {1,1} -- 1 = FFC, 2 = FEC, 3 = FC, 4 = None
WF.ITGFCType_CurSongInCourse = {1,1}
USEDAUTOPLAY = {false, false}

-- call this when screengameplay starts
WF.InitITGTracking = function(pn)
    local iscourse = GAMESTATE:IsCourseMode()
    if (not iscourse) or (iscourse and WF.CurrentSongInCourse == 1) then
        -- stuff that should not be reset in stages beyond the first song in a course
        WF.ITGJudgmentCounts[pn] = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }
        WF.ITGJudgmentCountsPerSongInCourse[pn] = {}
        WF.ITGJudgmentData[pn] = {}
        WF.ITGLife[pn] = 0.5
        WF.ITGRegenCombo[pn] = 0
        WF.ITGFailed[pn] = false
        WF.ITGSongInCourseAtFail[pn] = -1
        WF.ITGScore[pn] = "0.00"
        WF.ITGDP[pn] = 0
        WF.ITGMaxDP[pn] = WF.GetITGMaxDP("PlayerNumber_P"..pn)
        WF.ITGCurMaxDP[pn] = 0
        WF.ITGCombo[pn] = 0
        WF.ITGFCType[pn] = 1
        USEDAUTOPLAY[pn] = false
    end
    if iscourse then
        -- stuff that should be set for every song in a course
        table.insert(WF.ITGJudgmentCountsPerSongInCourse[pn], { 0, 0, 0, 0, 0, 0, 0, 0, 0 })
        table.insert(WF.ITGJudgmentData[pn], {})
        WF.ITGMaxDP_CurSongInCourse[pn] = 0
        WF.ITGCurMaxDP_CurSongInCourse[pn] = 0
        WF.ITGFCType_CurSongInCourse[pn] = 0
    end
end

WF.ITGTimingWindows = {
    0.023, -- Fantastic
    0.0445, -- Excellent
    0.1035, -- Great
    0.1365, -- Decent
    0.1815 -- Way Off
}

WF.ITGScoreWeights = {
    5, -- Fantastic
    4, -- Excellent
    2, -- Great
    0, -- Decent
    -6, -- Way Off
    -12, -- Miss
    5, -- Held
    0, -- Dropped
    -6 -- Mine
}
WF.ITGLifeChanges = {
    0.008, -- Fantastic
    0.008, -- Excellent
    0.004, -- Great
    0, -- Decent
    -0.05, -- Way Off
    -0.1, -- Miss
    0.008, -- Held
    -0.08, -- Dropped
    -0.05, -- Mine
    MissedHold = 0 -- this should not exist (see below)
}
WF.ITGRegenComboAfterMiss = 5
WF.ITGMaxRegenComboAfterMiss = 10
WF.ITGGradeTiers = {
    10000,
    9900,
    9800,
    9600,
    9400,
    9200,
    8900,
    8600,
    8300,
    8000,
    7600,
    7200,
    6800,
    6400,
    6000,
    5500
}
WF.GetITGGrade = function(score)
    -- pass in the formatted nn.nn string as the score. this assumes score is a pass.
    local s = tonumber(score) * 100
    for i, v in ipairs(WF.ITGGradeTiers) do
        if s >= v then
            return string.format("%02d", i)
        end
    end

    return "17" -- #itsa17
end

WF.GetITGJudgment = function(offset)
    for i, v in ipairs(WF.ITGTimingWindows) do
        if math.abs(offset) <= v then
            -- only use Decent if "Extended" is selected for Fault
            if i == 4 then return (WF.SelectedErrorWindowSetting == 3) and 4 or 5 end
            return i
        end
    end

    return WF.ITGJudgments.Miss -- this should never happen but who knows
end

WF.TrackITGJudgment = function(pn, judgedata, early)
    -- judgedata should be the params table from the JudgmentMessageCommand
    local iscourse = GAMESTATE:IsCourseMode()

    -- exit if autoplay
    local pc = GAMESTATE:GetPlayerState("PlayerNumber_P"..pn):GetPlayerController()
    if pc ~= "PlayerController_Human" then
        USEDAUTOPLAY[pn] = true
        if pc == "PlayerController_Autoplay" then
            return
        end
    end

    local weights = WF.ITGScoreWeights

    local songtime = GAMESTATE:GetCurMusicSeconds()
    local j = -1
    if judgedata.TapNoteScore and not judgedata.HoldNoteScore then
        if judgedata.TapNoteScore == "TapNoteScore_AvoidMine" then return end -- we don't care about dodging mines
        if judgedata.TapNoteScore == "TapNoteScore_HitMine" then
            j = WF.ITGJudgments.Mine
        else
            j = judgedata.TapNoteScore ~= "TapNoteScore_Miss" and WF.GetITGJudgment(judgedata.TapNoteOffset) or WF.ITGJudgments.Miss
        end
    elseif judgedata.HoldNoteScore then
        if judgedata.HoldNoteScore == "HoldNoteScore_Held" then
            j = WF.ITGJudgments.Held
        elseif judgedata.HoldNoteScore == "HoldNoteScore_LetGo" then
            j = WF.ITGJudgments.Dropped
        elseif judgedata.HoldNoteScore == "HoldNoteScore_MissedHold" then
           -- there is actually another HoldNoteScore (MissedHold) that happens at the end of a hold when the note was missed
           -- incidentally, we actually have to track this judgment because it decrements combotoregainlife
           -- this seems... unintended, but it happens
           -- update: this is indeed a bug and is not how "real" itg behaves. so i'm ignoring it here.
           -- update 2: as it turns out, we need this for subtractive scoring. so just take care of that here.
           WF.ITGCurMaxDP[pn] = WF.ITGCurMaxDP[pn] + weights[WF.ITGJudgments.Held]
           if iscourse then WF.ITGCurMaxDP_CurSongInCourse[pn] = WF.ITGCurMaxDP_CurSongInCourse[pn] + weights[7] end
           return --j = "MissedHold" 
        end
    end

    if j ~= -1 then
        -- most things we don't need to do if you've already failed
        if not WF.ITGFailed[pn] then
            if not early then
                -- update dp first
                WF.ITGDP[pn] = WF.ITGDP[pn] + weights[j]
                if iscourse then WF.ITGDP_CurSongInCourse[pn] = WF.ITGDP_CurSongInCourse[pn] + weights[j] end
                -- update max dp -- conveniently, both held and fantastic are +5, so we can increase it by 5 for any
                -- judgment except HitMine :)
                if j < 9 then
                    WF.ITGCurMaxDP[pn] = WF.ITGCurMaxDP[pn] + (j <= 6 and weights[WF.ITGJudgments.Fantastic] or weights[WF.ITGJudgments.Held])
                    if iscourse then
                        WF.ITGCurMaxDP_CurSongInCourse[pn] = WF.ITGCurMaxDP_CurSongInCourse[pn] + weights[1]
                    end
                end
            end

            -- track judgments in table
            local newlife = WF.UpdateLifeValue(pn, j, judgedata.EarlyTapNoteScore)
            if not early then
                local jd = WF.ITGJudgmentData[pn]
                if iscourse then
                    jd = WF.ITGJudgmentData[pn][WF.CurrentSongInCourse]
                    WF.ITGJudgmentCountsPerSongInCourse[pn][WF.CurrentSongInCourse][j] =
                        WF.ITGJudgmentCountsPerSongInCourse[pn][WF.CurrentSongInCourse][j] + 1
                end
                table.insert(jd, { j, newlife, songtime })
                WF.ITGJudgmentCounts[pn][j] = WF.ITGJudgmentCounts[pn][j] + 1
            end
        end

        -- combo stuff
        if j <= 3 then
            WF.ITGCombo[pn] = WF.ITGCombo[pn] + 1
            if WF.ITGFCType[pn] < j then
                WF.ITGFCType[pn] = j
            end
            if iscourse and (WF.ITGFCType_CurSongInCourse[pn] < j) then
                WF.ITGFCType_CurSongInCourse[pn] = j
            end
        else
            if ((j >= WF.ITGJudgments.Decent and j <= WF.ITGJudgments.Miss) and not early) or j == WF.ITGJudgments.Dropped then
                WF.ITGFCType[pn] = 4
                WF.ITGFCType_CurSongInCourse[pn] = 4
                if j ~= WF.ITGJudgments.Dropped then
                    WF.ITGCombo[pn] = 0 -- this condition was always strange to me haha
                end
            end
        end

        -- broadcast message for other things to respond more easily
        -- [TODO] i can refactor some stuff to use this later, but it's not doing anything yet...
        --MESSAGEMAN:Broadcast("ITGJudgment", {pn = pn, code = j})
    end
end

WF.UpdateLifeValue = function(pn, judgment, earlyTns)
    -- judgment should be the actual judgment index based on the table defined in this script
    --- ugh, you don't really realize how annoying this lifebar is until you're remaking it, do you

    if earlyTns ~= nil then
        local earlyTnsString = ToEnumShortString(earlyTns)
        if earlyTnsString ~= "None" then
            if judgment ~= 5 or judgment ~= 4 then
                return WF.ITGLife[pn]
            end
        end
    end
    -- if failed already, just return a 0
    if WF.ITGFailed[pn] then return 0 end

    local oldlife = WF.ITGLife[pn]

    -- update regencombo first, then change life accordingly
    if WF.ITGLifeChanges[judgment] < 0 then
        WF.ITGRegenCombo[pn] = math.min(WF.ITGRegenCombo[pn]
            + WF.ITGRegenComboAfterMiss, WF.ITGMaxRegenComboAfterMiss)
    else
        WF.ITGRegenCombo[pn] = math.max(WF.ITGRegenCombo[pn] - 1, 0)
    end

    if not (WF.ITGRegenCombo[pn] > 0 and WF.ITGLifeChanges[judgment] > 0) then
        -- harsh hot life penalty, god
        local lifechange = (WF.ITGLife[pn] == 1 and WF.ITGLifeChanges[judgment] < 0) and -0.1 or WF.ITGLifeChanges[judgment]
        WF.ITGLife[pn] = math.min(WF.ITGLife[pn] + lifechange, 1)
        if WF.ITGLife[pn] <= 0.00001 then
            -- set fail state here
            WF.ITGLife[pn] = 0
            WF.ITGFailed[pn] = true
            MESSAGEMAN:Broadcast("ITGFailed", { pn = pn })
            -- if in a course and itg mode is in use, force fail for wf; don't want to proceed to next song
            -- also store the song index at fail so we know later
            if GAMESTATE:IsCourseMode() then
                if SL["P"..pn].ActiveModifiers.SimulateITGEnv then
                    WF.FailPlayer(pn)
                end
                WF.ITGSongInCourseAtFail[pn] = WF.CurrentSongInCourse
            end
        end
    else
        --SCREENMAN:SystemMessage("ctrl "..WF.ITGRegenCombo[pn].."  "..judgment)
    end

    -- broadcast a message if life changed
    if WF.ITGLife[pn] ~= oldlife then
        MESSAGEMAN:Broadcast("ITGLifeChanged", {pn = pn, oldlife = oldlife, newlife = WF.ITGLife[pn]})
        if (WF.ITGLife[pn] <= WF.ITGDangerThreshold and oldlife > WF.ITGDangerThreshold) then
            MESSAGEMAN:Broadcast("ITGDanger", {pn = pn, event = "In"})
        elseif (WF.ITGLife[pn] > WF.ITGDangerThreshold and oldlife <= WF.ITGDangerThreshold) then
            MESSAGEMAN:Broadcast("ITGDanger", {pn = pn, event = "Out"})
        elseif (WF.ITGLife[pn] <= 0) then
            MESSAGEMAN:Broadcast("ITGDanger", {pn = pn, event = "Dead"})
        end
    end

    return WF.ITGLife[pn] -- TrackITGJudgment will use the new life value
end

WF.ConsolidateJudgments = function(pn)
    -- build a table of judgment counts, because that's easier to work with (:
    -- call this first on the evaluation screen
    -- NO LONGER USED -- quick returning here as a red flag in case anything relies on it
    if true then return end

    WF.ITGJudgmentCounts[pn] = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }

    for i, v in ipairs(WF.ITGJudgmentData[pn]) do
        WF.ITGJudgmentCounts[pn][v[1]] = WF.ITGJudgmentCounts[pn][v[1]] + 1
    end
end

WF.GetITGMaxDP = function(player, steps)
    -- if no steps (or trail) passed, use current
    if not steps then
        steps = (not GAMESTATE:IsCourseMode()) and GAMESTATE:GetCurrentSteps(player)
            or GAMESTATE:GetCurrentTrail(player)
    end
    local iscourse = (steps.GetAllSongs == nil)
    local radar = steps:GetRadarValues((not iscourse) and player or nil)
    local weights = WF.ITGScoreWeights
    local totalholdjudgments = radar:GetValue("RadarCategory_Holds") + radar:GetValue("RadarCategory_Rolls")
    local totaltapjudgments = radar:GetValue("RadarCategory_TapsAndHolds")
    return totalholdjudgments * weights[WF.ITGJudgments.Held]
        + totaltapjudgments * weights[WF.ITGJudgments.Fantastic]
end

WF.GetITGPercentDP = function(player, maxdp, incourse)
    -- if maxdp is passed in, just use that so we don't have to call current steps every time
    local steps = ((incourse) and (not maxdp)) and GAMESTATE:GetCurrentSteps(player) or nil
    if not maxdp then maxdp = WF.GetITGMaxDP(player, steps) end

    if maxdp == 0 then return 0 end

    local pn = tonumber(player:sub(-1))
    local raw = (not incourse) and (WF.ITGDP[pn] / maxdp) or WF.ITGDP_CurSongInCourse[pn] / maxdp
    return math.max(0, math.floor(raw * 10000) / 10000)
end

WF.CalculateITGScore = function(player)
    -- call this on ScreenEvaluation
    -- this will return the score value as well as set the global WF.ITGScore[pn]
    local pn = tonumber(player:sub(-1))
    local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
    local weights = WF.ITGScoreWeights

    -- get possible/actual dp
    local totalholdjudgments = pss:GetRadarPossible():GetValue("RadarCategory_Holds") + pss:GetRadarPossible():GetValue("RadarCategory_Rolls")
    local totaltapjudgments = pss:GetRadarPossible():GetValue("RadarCategory_TapsAndHolds")
    local possibledp = totalholdjudgments * weights[WF.ITGJudgments.Held]
        + totaltapjudgments * weights[WF.ITGJudgments.Fantastic]
    local dp = 0
    for i, v in ipairs(WF.ITGJudgmentCounts[pn]) do
        dp = dp + v * weights[i]
    end

    if possibledp == 0 then return "0.00" end

    local rawscore = math.max(dp / possibledp, 0)
    -- return formatted string
    WF.ITGScore[pn] = string.format("%.2f", math.floor(rawscore * 10000) / 100)
    return WF.ITGScore[pn]
end

-- calculate vertices for the itg lifebar graph (wow!)
--- the logic here is, there doesn't need to be more than [graph width] vertices. calculate the amount of time in the song
--- would take up 1 pixel of graph, and then for every interval between judgments, if the gap is larger than 1 pixel,
--- use the raw judgment for the next vertex.
--- originally i was going to average values between pixels but in practice that doesn't look necessary at all -- in fact,
--- my lifebar graph as it is is more precise/granular than the built in graph in game so checkmate atheists
WF.GetITGLifeVertices = function(pn, graphwidth, graphheight, songstart, songend, songincourse, xoff)
    local verts = {}
    local songlength = songend - songstart
    local timescale = songlength / graphwidth
    local t = songstart
    local l = 0.5

    -- songincourse and xoff are the same logic used in the base lifebar graphs
    if not xoff then xoff = 0 end
    local jdata = (not songincourse) and WF.ITGJudgmentData[pn] or WF.ITGJudgmentData[pn][songincourse]
    if (songincourse) and songincourse > 1 then
        local last = WF.ITGJudgmentData[pn][songincourse - 1]
        l = (#last > 0) and last[#last][2] or 0
    end

    table.insert(verts, {{xoff,(1-l)*graphheight,0},{1,1,1,1}})
    if (#jdata > 0) then
        table.insert(verts, {{(jdata[1][3] - songstart) / timescale + xoff, (1-l)*graphheight, 0},{1,1,1,1}})
    end

    for i, v in ipairs(jdata) do
        if v[3] - t >= timescale or v[2] < 0.0001 then
            table.insert(verts, {{(v[3] - songstart) / timescale + xoff, (1 - v[2]) * graphheight, 0},{1,1,1,1}})
            t = v[3]
        end

        l = v[2]
    end

    table.insert(verts, {{graphwidth + xoff, (1 - l) * graphheight, 0},{1,1,1,1}})

    return verts
end

WF.GetITGLifeVerticesCourse = function(pn, graphwidth, graphheight)
    local trail = GAMESTATE:GetCurrentTrail("PlayerNumber_P"..pn)
    local totaltime = 0

    -- get total length first
    for te in ivalues(trail:GetTrailEntries()) do
        totaltime = totaltime + te:GetSong():GetLastSecond()
    end

    local xoff = 0
    local verts = {}
    for i, v in ipairs(WF.ITGJudgmentData[pn]) do
        -- i'd validate that trail:GetTrailEntry(i-1) exists here, but if it didn't the program would crash anyway
        local curlen = trail:GetTrailEntry(i-1):GetSong():GetLastSecond()
        local w = (curlen / totaltime) * graphwidth
        local curverts = WF.GetITGLifeVertices(pn, w, graphheight, 0, curlen, i, xoff)

        for vert in ivalues(curverts) do
            table.insert(verts, vert) -- vert
        end

        xoff = xoff + w
    end

    return verts
end


--- various stuff for course mode
WF.CurrentSongInCourse = 1
WF.InitSongInCourse = function()
    -- anything that needs to happen at the start of every song in a course should go here
    if not GAMESTATE:IsCourseMode() then return end
    WF.CurrentSongInCourse = GAMESTATE:GetCourseSongIndex() + 1
    local players = GAMESTATE:GetHumanPlayers()

    if WF.CurrentSongInCourse == 1 then
        -- stuff for only the first song
        WF.CurrentCourseStatsObjects = {}
        WF.JudgmentCountsCurrentSongInCourse = {}
        WF.DetailedJudgmentsPerSongInCourse = {}
        WF.DetailedJudgmentsFullCourse = {}
        for player in ivalues(players) do
            local pn = tonumber(player:sub(-1))
            WF.CurrentCourseStatsObjects[pn] = {}
            WF.DetailedJudgmentsPerSongInCourse[pn] = {}
            WF.DetailedJudgmentsFullCourse[pn] = {}
        end
    end

    for player in ivalues(players) do
        local pn = tonumber(player:sub(-1))
        -- keep track of judgment counts for the current song for easy dp calculation on a fail
        WF.JudgmentCountsCurrentSongInCourse[pn] = {0, 0, 0, 0, 0, 0, 0, 0, 0}
        table.insert(WF.DetailedJudgmentsPerSongInCourse[pn], {})
    end
end

WF.TrackCourseJudgment = function(judgedata, pss)
    -- call in JudgmentMessageCommand
    if (pss and pss:GetFailed()) then return end
    local pn = tonumber(judgedata.Player:sub(-1))
    local j = -1
    if judgedata.TapNoteScore and (not judgedata.HoldNoteScore) then
        if judgedata.TapNoteScore:find("TapNoteScore_W") then
            j = tonumber(judgedata.TapNoteScore:sub(-1))
        elseif judgedata.TapNoteScore == "TapNoteScore_Miss" then
            j = 6
        elseif judgedata.TapNoteScore == "TapNoteScore_HitMine" then
            j = 9
        else
            return
        end
    elseif judgedata.HoldNoteScore then
        if judgedata.HoldNoteScore == "HoldNoteScore_Held" then
            j = 7
        elseif judgedata.HoldNoteScore == "HoldNoteScore_LetGo" then
            j = 8
        else
            return
        end
    end

    if j ~= -1 then
        WF.JudgmentCountsCurrentSongInCourse[pn][j] = WF.JudgmentCountsCurrentSongInCourse[pn][j] + 1
    end
end

WF.ConsolidateCourseStats = function()
    -- this should be called on evaluation before the profile does its update stuff, since that relies on all
    -- the course stats being consolidated
    if not GAMESTATE:IsCourseMode() then return end
    local jlookup = {TapNoteScore_W1=1,TapNoteScore_W2=2,TapNoteScore_W3=3,TapNoteScore_W4=4,
        TapNoteScore_W5=5,TapNoteScore_Miss=6,HoldNoteScore_Held=7,HoldNoteScore_LetGo=8,TapNoteScore_HitMine=9}

    for player in ivalues(GAMESTATE:GetHumanPlayers()) do
        local trail = GAMESTATE:GetCurrentTrail(player)
        local pn = tonumber(player:sub(-1))

        -- assign final life for last song in course here
        for i = 1, #WF.LifeBarNames do
            WF.LifeBarValues[pn][i].FinalLifePerSongInCourse[WF.CurrentSongInCourse] = 
                WF.LifeBarValues[pn][i].CurrentLife
        end

        -- consolidate detailed judgments for full course for easier scatterplot etc
        local toff = 0
        for dtind, dtsong in ipairs(WF.DetailedJudgmentsPerSongInCourse[pn]) do
            for dtnode in ivalues(dtsong) do
                -- copy node first
                local new = DeepCopy(dtnode)
                new[1] = new[1] + toff -- add current song offset to timestamp
                table.insert(WF.DetailedJudgmentsFullCourse[pn], new)
            end
            toff = toff + trail:GetTrailEntry(dtind-1):GetSong():GetLastSecond()
        end

        -- build stats object for full course
        local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
        local lifevals = WF.GetShortLifeBarTable(pn)
        WF.CurrentCourseStatsObjects[pn][1] = WF.BuildStatsObj(pss, lifevals)

        -- if failed, set the last song dp based on counted judgments
        -- note that i'm checking by lifebar because of a dumb edge case mentioned in WF-LifeBars.lua
        local isfail = (WF.LifeBarValues[pn][WF.LowestLifeBarToFail[pn]].Failed) or
            WF.CurrentCourseStatsObjects[pn][1]:GetSkipped()
        local failstatsobj
        if isfail then
            local laststeps = trail:GetTrailEntry(WF.CurrentSongInCourse - 1):GetSteps()
            local faildp = WF.CalculatePercentDP(WF.JudgmentCountsCurrentSongInCourse[pn],
                laststeps, player)
            local stats = {}
            for i = 1, 5 do stats["TapNoteScore_W"..i] = WF.JudgmentCountsCurrentSongInCourse[pn][i] end
            stats.TapNoteScore_Miss = WF.JudgmentCountsCurrentSongInCourse[pn][6]
            stats.HoldNoteScore_Held = WF.JudgmentCountsCurrentSongInCourse[pn][7]
            stats.HoldNoteScore_LetGo = WF.JudgmentCountsCurrentSongInCourse[pn][8]
            stats.TapNoteScore_HitMine = WF.JudgmentCountsCurrentSongInCourse[pn][9]
            stats.PercentDP = faildp
            local clifevals = {0, 0, 0}
            failstatsobj = WF.BuildStatsObj(stats, clifevals)
            if WF.ITGSongInCourseAtFail[pn] == -1 then WF.ITGSongInCourseAtFail[pn] = WF.CurrentSongInCourse end
        end

        -- build stats object for each song in course that was played
        for songind, te in ipairs(trail:GetTrailEntries()) do
            if (WF.DetailedJudgmentsPerSongInCourse[pn][songind]) and
            (not (isfail and songind == WF.CurrentSongInCourse)) then
                -- not every song was necessarily played
                -- additionally, the last song in a failed course is already handled separately, so
                -- we don't need that either
                local cursteps = te:GetSteps()
                local stats = {TapNoteScore_W1=0,TapNoteScore_W2=0,TapNoteScore_W3=0,TapNoteScore_W4=0,
                    TapNoteScore_W5=0,TapNoteScore_Miss=0,TapNoteScore_HitMine=0,HoldNoteScore_Held=0,
                    HoldNoteScore_LetGo=0}
                local shortj = {0,0,0,0,0,0,0,0,0}
                local clifevals = WF.GetShortLifeBarTable(pn, songind)

                -- get judgment counts from detailed stats
                for item in ivalues(WF.DetailedJudgmentsPerSongInCourse[pn][songind]) do
                    local j = item[2]
                    local ns
                    if j == "W1" or j == "W2" or j == "W3" or j == "W4" or j == "W5" or j == "Miss"
                    or j == "HitMine" then
                        ns = "TapNoteScore_"..j
                    elseif j == "Held" or j == "LetGo" then
                        ns = "HoldNoteScore_"..j
                    end
                    if ns then stats[ns] = stats[ns] + 1
                        shortj[jlookup[ns]] = shortj[jlookup[ns]] + 1 end
                end
                stats.PercentDP = WF.CalculatePercentDP(shortj, cursteps, player)

                WF.CurrentCourseStatsObjects[pn][songind + 1] = WF.BuildStatsObj(stats, clifevals)
            end
        end

        -- add failed stats obj to array if needed
        if failstatsobj then
            WF.CurrentCourseStatsObjects[pn][WF.CurrentSongInCourse + 1] = failstatsobj
        end
    end
end

function TotalCourseLength(player)
    -- utility for graph stuff because i ended up doing this a lot
    -- i use this method instead of TrailUtil.GetTotalSeconds because that leaves unused time at the end in graphs
    local trail = GAMESTATE:GetCurrentTrail(player)
    local t = 0
    for te in ivalues(trail:GetTrailEntries()) do
        t = t + te:GetSong():GetLastSecond()
    end

    return t
end

--- clear type/award stuff ---

-- grade tiers
-- "grades" will actually be overridden with my own grades, since SM doesn't allow a failing score to not
-- have a grade of grade_failed (why)
WF.Grades = enum_table({"S","AAA","AA","A","B","C","D"})
WF.GradePercent = {
    9900, -- S
    9700, -- AAA
    9500, -- AA
    9000, -- A
    8000, -- B
    7000, -- C
    -999  -- anything under 70 would give a grade of D
}

-- clear types
WF.ClearTypes = enum_table({
    "Mastery",
    "Awesome Combo",
    "Solid Combo",
    "Full Combo",
    WF.LifeBarNames[3].." Clear",
    "Clear",
    WF.LifeBarNames[1].." Clear",
    "Fail",
    "None" -- adding this for various situations i didn't think of before
})

WF.ClearTypesShort = enum_table({
    "★",
    "AC",
    "SC",
    "FC",
    "HCL",
    "CL",
    "ECL",
    "Fail",
    ""
})

WF.ClearTypeColor = function(ct)
    if (not ct) or ct == 0 or ct == WF.ClearTypes.None then return Color.White end
    if type(ct) == "string" then ct = WF.ClearTypes[ct] end
    if ct <= 4 then
        return SL.JudgmentColors.Waterfall[ct]
    elseif ct < 8 then
        return WF.LifeBarColors[8 - ct]
    else
        return color("#B00000")
    end
end

-- for the purpose of keeping track of play history etc, we want to be able to easily build a stats object
-- that has universal functions for GetTapNotes etc
-- the idea is that you can easily get all this information whether you're passing in a PlayerStageStats object
-- on ScreenEvaluation, or a HighScore object when loading the profile, or anywhere else

WF.StatsObj = {
    __index = function(self, arg)
        return WF.StatsObj[arg]
    end,

    GetType = function(self)
        -- determine the type of the object by checking functions that only exist in any particular one
        if self.Stats.FailPlayer then
            return "PlayerStageStats"
        elseif self.Stats.GetDate then
            return "HighScore"
        else
            return "Custom"
        end
    end,

    GetTapNotes = function(self, arg)
        if not arg:find("TapNoteScore") then
            arg = "TapNoteScore_"..arg
        end
        if self:GetType() == "PlayerStageStats" then
            return self.Stats:GetTapNoteScores(arg)
        elseif self:GetType() == "HighScore" then
            return self.Stats:GetTapNoteScore(arg)
        else
            return self.Stats[arg]
        end
    end,

    GetHoldNotes = function(self, arg)
        if not arg:find("HoldNoteScore") then
            arg = "HoldNoteScore_"..arg
        end
        if self:GetType() == "PlayerStageStats" then
            return self.Stats:GetHoldNoteScores(arg)
        elseif self:GetType() == "HighScore" then
            return self.Stats:GetHoldNoteScore(arg)
        else
            return self.Stats[arg]
        end
    end,

    GetJudgmentCount = function(self, arg)
        local tapnames = {"W1","W2","W3","W4","W5","Miss","HitMine","AvoidMine"}
        local holdnames = {"Held","LetGo","MissedHold"}
        if FindInTable(arg, tapnames) or arg:find("TapNoteScore") then
            return self:GetTapNotes(arg)
        end
        if FindInTable(arg, holdnames) or arg:find("HoldNoteScore") then
            return self:GetHoldNotes(arg)
        end
    end,

    GetSkipped = function(self)
        -- skipping to results is not tracked in ITG/SL but we don't want to give a clear if we can detect
        -- that the song was skipped. if a PSS is passed in this is simple, but with a HighScore we need
        -- to validate the DP percent, buh. we shouldn't need to care about this for custom table because
        -- we can set the lifebar values to 0 in real time when a song is skipped
        if self.LifeBarVals then
            -- before doing anything, we don't care if the song was skipped if we know all lifebars were 0
            -- (ie the song was failed and then skipped to the results screen)
            local f = true
            for v in ivalues(self.LifeBarVals) do
                if v > 0 then
                    f = false
                    break
                end
            end
            if f then
                return false
            end
        end
        local totaltaps = self:GetJudgmentCount("W1") + self:GetJudgmentCount("W2") + self:GetJudgmentCount("W3")
            + self:GetJudgmentCount("W4") + self:GetJudgmentCount("W5") + self:GetJudgmentCount("Miss")
        local totalholds = self:GetJudgmentCount("Held") + self:GetJudgmentCount("LetGo") 
            + (self:GetJudgmentCount("MissedHold") or 0)
        if self:GetType() == "PlayerStageStats" then
            local rv = self.Stats:GetRadarPossible()
            return not (totaltaps == rv:GetValue("RadarCategory_TapsAndHolds")
                        and totalholds == rv:GetValue("RadarCategory_Holds") + rv:GetValue("RadarCategory_Rolls"))
        elseif self:GetType() == "HighScore" then
            return (not self:ValidateDP())
        end
    end,

    GetFail = function(self)
        -- since we're using custom lifebars, life bar values can be passed in separately. if they arent, use
        -- the PSS or HS object to get a normal clear or fail
        if self.LifeBarVals ~= nil then
            if not self:GetSkipped() then
                for i, v in ipairs(self.LifeBarVals) do
                    if v > 0 then return false end
                end
            end
            return true
        elseif self:GetType() == "PlayerStageStats" then
            return (self.Stats:GetFailed() or self:GetSkipped())
        elseif self:GetType() == "HighScore" then
            return (self.Stats:GetGrade() == "Grade_Failed" or self:GetSkipped())
        end
    end,

    GetPercentDP = function(self)
        -- used in ValidateDP; for a HighScore/PSS, just return the % dp contained in the object, otherwise calculate
        if self:GetType() == "HighScore" then
            return self.Stats:GetPercentDP()
        elseif self:GetType() == "PlayerStageStats" then
            return self.Stats:GetPercentDancePoints()
        elseif self.Stats.PercentDP then
            -- a custom object can have a % dp assigned (this is good for songs in a course)
            return self.Stats.PercentDP
        else
            -- calculate for custom table
            return self:CalculateDP()
        end
    end,

    CalculateDP = function(self)
        -- different from the above in that it will always do the calculation. ValidateDP will compare these two.
        ---- NOTE: using "SL" table here to get score weights, remember to change that later ----
        local m = SL.Metrics.Waterfall
        local totaltaps = self:GetJudgmentCount("W1") + self:GetJudgmentCount("W2") + self:GetJudgmentCount("W3")
            + self:GetJudgmentCount("W4") + self:GetJudgmentCount("W5") + self:GetJudgmentCount("Miss")
        local totalholds = self:GetJudgmentCount("Held") + self:GetJudgmentCount("LetGo") + (self:GetJudgmentCount("MissedHold") or 0)

        if totaltaps + totalholds == 0 then
            return 0 --don't divide by 0
        end

        local dp = 0
        local j = {"W1","W2","W3","W4","W5","Miss","Held","LetGo","HitMine"}
        for v in ivalues(j) do
            dp = dp + m["PercentScoreWeight"..v] * self:GetJudgmentCount(v)
        end

        return math.max(0, dp / (totaltaps * m.PercentScoreWeightW1 + totalholds * m.PercentScoreWeightHeld))
    end,

    ValidateDP = function(self)
        --Trace("Validating dp... actual "..self:GetPercentDP().." calculated "..self:CalculateDP())
        return math.abs(self:GetPercentDP() - self:CalculateDP()) <= 0.0001
    end,

    GetScoreString = function(self)
        return FormatPercentScore(self:GetPercentDP()):gsub("%%","")
        --return string.format("%.2f", math.floor(self:GetPercentDP() * 10000) / 100)
    end,

    GetClearType = function(self)
        -- we can use the judgment breakdowns to derive all "full combo" types, but for lifebar clears, we can only
        -- derive approximated "normal clear" without passing in lifebar values (ie in a HighScore on loading profile)

        -- return fail if skipped
        if self:GetSkipped() or self:GetFail() then return WF.ClearTypes.Fail end

        if self:GetJudgmentCount("Miss") > 0 or self:GetJudgmentCount("LetGo") > 0 or self:GetJudgmentCount("HitMine") > 0
        or self:GetJudgmentCount("W5") > 0 then
            -- not a full combo; just get pass/fail
            if not self.LifeBarVals then
                return self:GetFail() and WF.ClearTypes.Fail or WF.ClearTypes.Clear
            else
                for i = #self.LifeBarVals, 1, -1 do
                    if self.LifeBarVals[i] > 0 then
                        return i == WF.LifeBarNames.Normal and WF.ClearTypes.Clear
                            or WF.ClearTypes[WF.LifeBarNames[i].." Clear"] -- i guess it works
                    end
                end
                return WF.ClearTypes.Fail
            end
        else
            -- full combo tiers
            for i = 4, 1, -1 do
                if self:GetJudgmentCount("W"..i) > 0 then
                    return i -- maybe a little weird but we know that the first 4 clear types correspond to the windows
                end
            end
        end

        -- it's possible to get here if for some reason no judgments happened at all. give em a hard clear i guess
        return WF.ClearTypes[WF.LifeBarNames[3].." Clear"]
    end,

    CalculateGrade = function(self)
        -- just the calculation for a grade
        local score = tonumber((self:GetScoreString())) * 100
        for i, v in ipairs(WF.GradePercent) do
            if score >= v then
                return i
            end
        end
    end,

    GetGrade = function(self)
        -- we actually don't want to use the "F" grade at all, because "fail" is categorized under clear types
        -- so for a PSS, we need to override a failing grade by calculating from the score
        if self:GetType() == "PlayerStageStats" and not self:GetFail() then
            return tonumber(self.Stats:GetGrade():sub(-1))
        else
            return self:CalculateGrade()
        end
    end
}

-- we will use this player indexed array on evaluation to pass into profile stuff
WF.CurrentSongStatsObject = {}
WF.CurrentCourseStatsObjects = {}

WF.BuildStatsObj = function(stats, lifebarvals)
    -- stats can either be a PlayerStageStats, a HighScore or a list of judgments in the format
    -- {TapNoteScore_W1 = n, ... HoldNoteScore_Held = n, ... }
    -- lifebarvals is an optional list of ending lifebar values from easy to hard {n,n,n}
    local t = { Stats = stats, LifeBarVals = lifebarvals }
    setmetatable(t, WF.StatsObj)
    return t
end

WF.CalculatePercentDP = function(judgments, steps, player, itg, maxdp)
    -- judgments should be a table in the form {w1,w2,w3,w4,w5,miss,held,dropped,mine}
    -- calculate by referencing the chart/course without the bloat of statsobject
    if not player then player = GAMESTATE:GetMasterPlayerNumber() end
    local iscourse = (steps.GetChartName ~= nil)
    local weights = SL.Metrics[itg and "ITG" or "Waterfall"]
    if not maxdp then
        local rv = steps:GetRadarValues((not iscourse) and player or nil)
        maxdp = rv:GetValue("RadarCategory_TapsAndHolds") * weights.PercentScoreWeightW1
        + (rv:GetValue("RadarCategory_Holds") + rv:GetValue("RadarCategory_Rolls")) * weights.PercentScoreWeightHeld
    end
    if maxdp == 0 then return 0 end

    local dp = 0
    for i = 1, 5 do
        dp = dp + judgments[i] * weights["PercentScoreWeightW"..i]
    end
    dp = dp + judgments[6] * weights.PercentScoreWeightMiss
        + judgments[7] * weights.PercentScoreWeightHeld + judgments[8] * weights.PercentScoreWeightLetGo
        + judgments[9] * weights.PercentScoreWeightHitMine

    return math.max(0, dp / maxdp)
end


-- Function to consolidate per panel judgments and apply the counts to the SL data table
WF.ConsolidatePerPanelJudgments = function(pn, judgments)
    -- judgments should be the detailed_judgments table recorded from ScreenGameplay
    SL["P"..pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].column_judgments = {}
    local coljudgments = SL["P"..pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].column_judgments
    local coljudgments_itg
    local missbcheld = SL["P"..pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].miss_bcheld or {}

    for i = 1,10 do table.insert(coljudgments, {W1=0,W2=0,W3=0,W4=0,W5=0,Miss=0,
        MissBecauseHeld=missbcheld[i] or 0}) end

    if not coljudgments_itg then 
        coljudgments_itg = {}
        for i = 1,10 do table.insert(coljudgments_itg, {W1=0,W2=0,W3=0,W4=0,W5=0,Miss=0}) 
        coljudgments_itg[i].MissBecauseHeld = coljudgments[i].MissBecauseHeld end
        SL["P"..pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].column_judgments_itg = coljudgments_itg
    end

    -- in a course, judgments is a list; put everything in one big list and loop through
    local alljudgments = (not GAMESTATE:IsCourseMode()) and {judgments} or judgments
    for curjudgments in ivalues(alljudgments) do
        for i, jdata in ipairs(curjudgments) do
            if not (jdata[2] == "Held" or jdata[2] == "LetGo" or jdata[2] == "HitMine") then
                for c in ivalues(jdata[3]) do
                    coljudgments[c][jdata[2]] = coljudgments[c][jdata[2]] + 1
                    -- itg logic
                    if jdata[2] == "Miss" then
                        coljudgments_itg[c].Miss = coljudgments_itg[c].Miss + 1
                    else
                        local w = DetermineTimingWindow(jdata[4], "ITG")
                        coljudgments_itg[c]["W"..w] = coljudgments_itg[c]["W"..w] + 1
                    end
                end
            end
        end
    end
end


--- Function for setting the timing window based on the ExpErrorWindow setting
WF.SelectedErrorWindowSetting = 1 -- {1 = Enabled, 2 = Disabled, 3 = Extended}
                            -- this just seems like a faster comparison to determine whether to use Decent
WF.SetErrorWindow = function(setting)
    -- pass the string value of the option here
    local lookup = {Enabled = 1, Disabled = 2, Extended = 3}
    local val = WF.GetErrorWindowVal(setting)
    if val ~= nil and PREFSMAN:GetPreference("TimingWindowSecondsW5") ~= val then
        PREFSMAN:SetPreference("TimingWindowSecondsW5", val)
        -- hijack "TimingWindow" modifier to indicate to SL that W5 is disabled, if that option is selected
        SL.Global.ActiveModifiers.TimingWindows[5] = (setting ~= "Disabled")
        WF.SelectedErrorWindowSetting = lookup[setting]
    end
end

WF.GetErrorWindowVal = function(setting)
    if setting == "Enabled" then
        return SL.Preferences.Waterfall.TimingWindowSecondsW5
    elseif setting == "Disabled" then
        return 0
    elseif setting == "Extended" then
        return SL.Preferences.ITG.TimingWindowSecondsW5 + SL.Preferences.ITG.TimingWindowAdd
    end
end


-- FA+ tracking
-- This will be per player, and indexed by [1] = 10ms count, [2] = 12.5ms count
-- We actually don't need to track 15ms because the W1 window is always 15ms

-- Waterfall Expanded 0.7.6 notes
-- Actually we do need to track 15ms, because evaluation screen is messed up
-- if we keep playing after failure while in FA+ mode.
-- Added FAPlusCount[3] which tracks 15ms instead of just using the W0 window
-- Because it was messing up the split fantastic window on Evaluation.
-- Also stopped counting FA Plus after failure. As far as I've tested, these 
-- changes fix the evaluation screen issues relating to ITG/FA+.
-- Zarzob

WF.FAPlusCount = {}
WF.FAPlusCountPerSongInCourse = {}
WF.InitFAPlus = function(pn)
    -- Call this at the start of ScreenGameplay (probably in offset tracking)
    local iscourse = GAMESTATE:IsCourseMode()
    if not iscourse then
        WF.FAPlusCount[pn] = {0,0,0}
    else
        if WF.CurrentSongInCourse == 1 then
            WF.FAPlusCount[pn] = {0,0,0}
            WF.FAPlusCountPerSongInCourse[pn] = {}
        end
        table.insert(WF.FAPlusCountPerSongInCourse[pn], {0,0,0})
    end
end
WF.TrackFAPlus = function(pn, judgedata)


	if WF.ITGFailed[pn] then return end

    -- Pass player number and params from JudgmentMessage into this
    -- exit under irrelevant conditions
    if not judgedata.TapNoteOffset then return end
    if judgedata.HoldNoteScore then return end
    if judgedata.TapNoteScore == "TapNoteScore_Miss" then return end
    if GAMESTATE:GetPlayerState("PlayerNumber_P"..pn):GetPlayerController() == "PlayerController_Autoplay" then
        return
    end

    local iscourse = GAMESTATE:IsCourseMode()
    local offset = judgedata.TapNoteOffset
    if math.abs(offset) <= 0.010 then
        WF.FAPlusCount[pn][1] = WF.FAPlusCount[pn][1] + 1
        WF.FAPlusCount[pn][2] = WF.FAPlusCount[pn][2] + 1
		WF.FAPlusCount[pn][3] = WF.FAPlusCount[pn][3] + 1
        if iscourse then
            WF.FAPlusCountPerSongInCourse[pn][WF.CurrentSongInCourse][1] = 
                WF.FAPlusCountPerSongInCourse[pn][WF.CurrentSongInCourse][1] + 1
            WF.FAPlusCountPerSongInCourse[pn][WF.CurrentSongInCourse][2] = 
                WF.FAPlusCountPerSongInCourse[pn][WF.CurrentSongInCourse][2] + 1
            WF.FAPlusCountPerSongInCourse[pn][WF.CurrentSongInCourse][3] = 
                WF.FAPlusCountPerSongInCourse[pn][WF.CurrentSongInCourse][3] + 1
        end
    elseif math.abs(offset) <= 0.0125 then
        WF.FAPlusCount[pn][2] = WF.FAPlusCount[pn][2] + 1
		WF.FAPlusCount[pn][3] = WF.FAPlusCount[pn][3] + 1
        if iscourse then
            WF.FAPlusCountPerSongInCourse[pn][WF.CurrentSongInCourse][2] = 
                WF.FAPlusCountPerSongInCourse[pn][WF.CurrentSongInCourse][2] + 1
            WF.FAPlusCountPerSongInCourse[pn][WF.CurrentSongInCourse][3] = 
                WF.FAPlusCountPerSongInCourse[pn][WF.CurrentSongInCourse][3] + 1
        end
    elseif math.abs(offset) <= 0.015 then
        WF.FAPlusCount[pn][3] = WF.FAPlusCount[pn][3] + 1
        if iscourse then
            WF.FAPlusCountPerSongInCourse[pn][WF.CurrentSongInCourse][3] = 
                WF.FAPlusCountPerSongInCourse[pn][WF.CurrentSongInCourse][3] + 1
        end
    end
end


-- stuff relating to plain text judgments ([TODO] maybe move this to player options file later)
WF.PlainTextJudgmentFont = "Common Normal"
WF.PlainTextJudgmentBaseZoom = 2
WF.PlainTextJudgmentNames = {
    Waterfall = {
        W1 = "MASTERFUL",
        W2 = "AWESOME",
        W3 = "SOLID",
        W4 = "OK",
        W5 = "FAULT",
        Miss = "MISS"
    },
    ITG = {
        W1 = "FANTASTIC!",
        W2 = "EXCELLENT",
        W3 = "GREAT",
        W4 = "DECENT",
        W5 = "WAY OFF",
        Miss = "MISS"
    }
}


-- ?
GetFunnyURL = function()
    local t = {
        "https://www.youtube.com/watch?v=s7GqArpYav4",
        "https://www.youtube.com/watch?v=iW1dkyrRagw",
        "https://www.youtube.com/watch?v=hKZXqUaNBcA",
        "https://www.youtube.com/watch?v=PGv4ixLllWo",
        "https://twitter.com/dril/status/830105130104127490",
        "https://twitter.com/dril/status/870008302662545408",
        "https://twitter.com/StopidSnoman/status/1380743307702136836",
        "https://www.squishable.com/squishables/mini_cute_snowman_7.html",
        "Hey there! Thanks for scanning this QR code! :)",
        "It’s definitely borderline haha. I can see why you thought it was fake at the time,"
        .." it just couldn't be decisively concluded since there were way less 230 charts at that"
        .." difficulty range back then. For what it's worth, it's got a solid 100m over other 230"
        .." bpm 21s (Xenoflux/Kuusuo) and those aren't exactly low 21s, they just happen to have pretty"
        .." bad patterns so they're not significantly easier to do"
    }

    return t[math.random(1, #t)]
end
