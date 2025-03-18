--- This theme will manage high score saving entirely separately from how StepMania insists to do so.
--- Stats.xml will be "ignored" (in reality we're just setting the prefix to something arbitrary so as to create
--- a sort of dummy stats file that won't be used for retrieving what this theme will record as high scores).
--- Instead there will be separate files managed by the theme, stored in the local profile folder.

--- The general overview is that there will be a main stats file which will contain some information similar to how
--- Stats.xml does, but with my own fields and in my own format. There will also be "detailed" high score files
--- which can (later on) be used to recreate all the data associated with that play.

--- Functions dealing with managing the profile data are contained here.

--- Note about course stats: since course stuff was implemented later and adapted to the existing format, all the
--- functions dealing with "SongStats" will work by passing in course and trail instead of song and steps, and have
--- aliases for CourseStats so as to not just repeat a bunch of the same functions for a slightly different table.

-- HERE IT IS BOYS. IT'S THE HASH CACHE #HASHCASH
WF.HashCache = {}

WF.InitPlayerProfiles = function()
   -- these will always be indexed by player number
    WF.PlayerProfileStats = {}

    -- there will be some checks for the validity of a profile when loaded, and if it's found to be invalid, set a
    -- flag to indicate not to try to save anything
    WF.ProfileInvalid = {false,false}

    -- this is just my own variable to keep track of how many songs has been played per player
    WF.CurrentSessionSongsPlayed = {0,0}

    -- subtitle to appear under name on profile card
    WF.ProfileCardSubtitle = {"",""} 
end
WF.InitPlayerProfiles()

-- some variables that will be used on the menu for custom profile settings
WF.ModifyingProfileID = ""
WF.CustomProfileOptionDefaults = {
    ProfileCardInfo = "SongsPlayed",
    PreferredGraph = "Life",
    PreferredSecondPane = "General",
    PreferredSecondGraph = "Life",
    PreferredGameEnv = "Waterfall",
	PreferredFaultWindow = "Enabled",
    GSOverride = false,
    AlwaysGS = false
}
WF.CustomProfileOptions = DeepCopy(WF.CustomProfileOptionDefaults)

--[[
PlayerProfileStats table format:
{
    SkillLv = int,
    SongsPlayed = int,
    CoursesPlayed = int,
    TotalTapJudgments = {W1,W2,W3,W4,W5,Miss},
    TotalHolds = {HoldsHeld,HoldsTotal,RollsHeld,RollsTotal},
    TotalMines = {Hit,Total},
    LastSongPlayed = "Group/SongFolder",
    LastPlayedDate = "YYYY-MM-DD",

    -- a couple fields that are not actually stored in the file, but calculated on load
    ClearTypeCounts = {P,EC,GC,FC,HCL,CL,ECL,F},
    GradeCounts = {Ess,AAA,AA,A,B,C,D},
    GradeCounts_ITG = {****,***,**,*,...,F},
    -- separated for courses
    CourseClearTypeCounts = {...},
    CourseGradeCounts = {...},
    CourseGradeCounts_ITG = {...},

    SessionAchievements = {P,EC,GC,FC,HCL,CL,ECL}, -- counts of new clear types this session

    SongStats = {
        -- explanation: this will be a linear array with each item having a ChartID field (the same id i've been using
           for clear types so far) as well as a ChartHash field. There will be a function to search this to find the item
           for a certain chart based on either the ID or the hash. Rate mod will also be an identifier that separates these;
           a chart on a particular rate mod will be treated as a separate chart
        {
            SongFullTitle = "title",
            SongArtist = "artist",
            BPM = "bpm string",
            ChartID = "Style/Group/SongFolder/Difficulty",
            ChartHash = "gs hash",
            RateMod = "1.xx",
            DifficultyRating = int,
            PlayCount = int,
            BestClearType = int,
            BestPercentDP = int (0-10000),
            BestPercentDP_ITG = int,
            Cleared_ITG = "C"/"F", -- nil = unplayed, F = failed, C = cleared
            BestFAPlusCounts = {int,int,int},
            TotalSteps = int,
            TotalHolds = int,
            TotalRolls = int,
            TotalMines = int,
            BestPlay = {
                DateObtained = "YYYY-MM-DD HH:MM:SS",
                Judgments = {W1,W2,W3,W4,W5,Miss,HoldsHeld,RollsHeld,MinesHit},
                FAPlus = {10ms count,12.5ms count},
                LifeBarVals = {Easy,Normal,Hard},
                ScoreAtLifeEmpty = {Easy,Normal,Hard},
                SignificantMods = {"C","Left/Right/Etc","NoMines","NoBoys"}
            }
        },
        ...
        -- Lookup table will allow faster access to any item via SongStats[ Lookup[Hash][Rate] ] and so forth
        Lookup = {HashOrID = {Rate = n}, ...}
    },
    CourseStats = {
        {
            CourseTitle = title,
            BPM = bpmstring,
            CourseID = "Style/Path/Difficulty",
            RateMod = "1.xx",
            DifficultyRating = int,
            PlayCount = int,
            BestClearType = int,
            BestPercentDP = int,
            BestPercentDP_ITG = int,
            Cleared_ITG = ctstring,
            BestFAPlusCounts = {int,int,int},
            TotalSteps = int,
            TotalHolds = int,
            TotalRolls = int,
            TotalMines = int,
            BestPlay = {
                DateObtained = "YYYY-MM-DD HH:MM:SS",
                Judgments = {W1,W2,W3,W4,W5,Miss,HoldsHeld,RollsHeld,MinesHit},
                FAPlus = {10ms count,12.5ms count},
                LifeBarVals = {Easy,Normal,Hard},
                ScoreAtLifeEmpty = {Easy,Normal,Hard},
                SignificantMods = {"C","Left/Right/Etc","NoMines","NoBoys"}
            }
        },
        ...
        Lookup = {ID = {Rate = n}}
        }
    }
}
]]

WF.NewPlayerProfileSongStats = function()
    -- return a blank song stats object for a player profile
    local stats = {
        SongFullTitle = "",
        SongArtist = "",
        BPM = "",
        ChartID = "",
        ChartHash = nil,
        RateMod = "1.0",
        DifficultyRating = 1,
        PlayCount = 0,
        BestClearType = WF.ClearTypes.None,
        BestPercentDP = 0,
        BestPercentDP_ITG = 0,
        Cleared_ITG = nil,
        BestFAPlusCounts = {0,0,0},
        TotalSteps = 0,
        TotalHolds = 0,
        TotalRolls = 0,
        TotalMines = 0,
        BestPlay = {
            DateObtained = "0000-00-00 00:00:00",
            Judgments = {0,0,0,0,0,0,0,0,0},
            FAPlus = {0,0},
            LifeBarVals = {1000,1000,1000},
            ScoreAtLifeEmpty = {0,0,0},
            SignificantMods = {}
        }
    }

    return stats
end

WF.NewPlayerProfileCourseStats = function()
    local stats = WF.NewPlayerProfileSongStats()
    stats.SongFullTitle = nil
    stats.SongArtist = nil
    stats.ChartID = nil
    stats.ChartHash = nil
    stats.CourseTitle = ""
    stats.CourseID = ""

    return stats
end

WF.MergePlayerProfileSongStats = function(stats1, stats2)
    -- this will return a new SongStats that takes the best of every item between stats1 and stats2.
    -- this is used in any event that multiple SongStats exist with the same hash and rate
    --- conditionally handle course stats in here as well to avoid redundant code
    -- programmer responsibility to pass in the same kind of stats for both arguments
    local iscourse = (stats1.CourseTitle ~= nil)
    local newstats = (not iscourse) and WF.NewPlayerProfileSongStats() or WF.NewPlayerProfileCourseStats()

    -- exit if hash and rate aren't the same (no reason to ever merge in this case, so catch it here and log it)
    if (not ((not iscourse) and stats1.ChartHash == stats2.ChartHash and stats1.RateMod == stats2.RateMod))
    and (not ((iscourse) and stats1.CourseID == stats2.CourseID and stats1.RateMod == stats2.RateMod)) then
        Trace(string.format("Stats merge error:\nhash/id 1: %s\nrate 1: %s\nhash/id 2: %s\nrate 2:%s",
            iscourse and stats1.CourseID or stats1.ChartHash, stats1.RateMod,
            iscourse and stats2.CourseID or stats2.ChartHash, stats2.RateMod))
        return
    end

    newstats.SongFullTitle = stats1.SongFullTitle
    newstats.CourseTitle = stats1.CourseTitle
    newstats.SongArtist = stats1.SongArtist
    newstats.BPM = stats1.BPM
    newstats.ChartID = stats1.ChartID
    newstats.CourseID = stats1.CourseID
    newstats.ChartHash = stats1.ChartHash
    newstats.RateMod = stats1.RateMod
    newstats.DifficultyRating = stats1.DifficultyRating
    newstats.PlayCount = stats1.PlayCount + stats2.PlayCount
    newstats.BestClearType = math.min(stats1.BestClearType, stats2.BestClearType)
    newstats.BestPercentDP = math.max(stats1.BestPercentDP, stats2.BestPercentDP)
    newstats.BestPercentDP_ITG = math.max(stats1.BestPercentDP_ITG, stats2.BestPercentDP_ITG)
    if (stats1.Cleared_ITG == "C" or stats2.Cleared_ITG == "C") then newstats.Cleared_ITG = "C"
    elseif (stats1.Cleared_ITG == "F" or stats2.Cleared_ITG == "F") then newstats.Cleared_ITG = "F" end
    newstats.BestFAPlusCounts = {
        math.max(stats1.BestFAPlusCounts[1], stats2.BestFAPlusCounts[1]),
        math.max(stats1.BestFAPlusCounts[2], stats2.BestFAPlusCounts[2]),
        math.max(stats1.BestFAPlusCounts[3], stats2.BestFAPlusCounts[3])
    }
    newstats.TotalSteps = stats1.TotalSteps
    newstats.TotalHolds = stats1.TotalHolds
    newstats.TotalRolls = stats1.TotalRolls
    newstats.TotalMines = stats1.TotalMines
    local betterplay = stats1
    -- note: using my CompareDateTime shit in a nested loop was causing stack overflows, so just only take stats2
    -- if it's actually a higher score. currently nothing really uses this "best play" thing anyway...
    if stats2.BestPercentDP > stats1.BestPercentDP then
        betterplay = stats2
    end
    newstats.BestPlay = DeepCopy(betterplay.BestPlay)

    return newstats
end

-- alias of the above for clarity when used
WF.MergePlayerProfileCourseStats = WF.MergePlayerProfileSongStats

WF.ConsolidateProfileSongAndCourseStats = function(pn)
    -- loop through all SongStats and merge any that (for whatever reason) have the same hash and rate
    -- this will also reassign any hashes that don't match what's in the #HashCash
    local stats = pn and WF.PlayerProfileStats[pn].SongStats or WF.MachineProfileStats.SongStats
    local mergefunc = pn and WF.MergePlayerProfileSongStats or WF.MergeMachineProfileSongStats
    local numbermerged = 0
    local hcc = 0
    for k, v in pairs(WF.HashCache) do hcc = hcc + 1 end
    if hcc == 0 then return end
    if not WF.HashCache.WFVersion then return end

    -- first loop through and reassign bad hashes; this needs to be done in a separate loop
    for score in ivalues(stats) do
        if (WF.HashCache) and (score.ChartHash) and (score.ChartHash ~= "") and (score.ChartID)
        and (score.ChartID ~= "") and (WF.HashCache[score.ChartID])
        and (score.ChartHash ~= WF.HashCache[score.ChartID]) then
            score.ChartHash = WF.HashCache[score.ChartID]
        end
    end

    for i = 1, #stats do
        if not stats[i] then break end
        local hash = stats[i].ChartHash
        if hash and (hash ~= "") then
            for ii = i + 1, #stats do
                if not stats[ii] then break end
                if stats[i].ChartHash == stats[ii].ChartHash and stats[i].RateMod == stats[ii].RateMod then
                    Trace(string.format("Merging scores for hash: %s", stats[i].ChartHash))
                    local newstats = mergefunc(stats[i], stats[ii])
                    stats[i] = newstats
                    table.remove(stats, ii)
                    ii = ii - 1
                    numbermerged = numbermerged + 1
                end
            end
            UpdateLookupEntry(stats, hash, stats[i].RateMod, i)
        end
        UpdateLookupEntry(stats, stats[i].ChartID, stats[i].RateMod, i)
    end

    -- now handle courses
    stats = pn and WF.PlayerProfileStats[pn].CourseStats or WF.MachineProfileStats.CourseStats
    mergefunc = pn and WF.MergePlayerProfileCourseStats or WF.MergeMachineProfileCourseStats

    for i = 1, #stats do
        if not stats[i] then break end
        local id = stats[i].CourseID
        if id and (id ~= "") then
            for ii = i + 1, #stats do
                if not stats[ii] then break end
                if stats[i].CourseID == stats[ii].CourseID and stats[i].RateMod == stats[ii].RateMod then
                    Trace(string.format("Merging scores for course: %s", stats[i].CourseID))
                    local newstats = mergefunc(stats[i], stats[ii])
                    stats[i] = newstats
                    table.remove(stats, ii)
                    ii = ii - 1
                    numbermerged = numbermerged + 1
                end
            end
            --UpdateLookupEntry(stats, hash, stats[i].RateMod, i)
        end
        UpdateLookupEntry(stats, stats[i].CourseID, stats[i].RateMod, i)
    end
    if numbermerged > 0 then Trace(string.format("Merged %d scores", numbermerged)) end
end

WF.AddPlayerProfileSongStatsFromSteps = function(song, steps, rate, hash, pn)
    -- create a new stats object with information from the song and steps passed (and optional rate mod),
    -- and add it to the player profile stats table.
    local player = "PlayerNumber_P"..pn

    if not song then
        song = (not GAMESTATE:IsCourseMode()) and GAMESTATE:GetCurrentSong() or GAMESTATE:GetCurrentCourse()
    end
    local iscourse = (song.GetAllSteps == nil)
    if not steps then
        steps = (not iscourse) and GAMESTATE:GetCurrentSteps(player) or GAMESTATE:GetCurrentTrail(player)
        -- assume if no steps are passed in, everything is based on the current state, so take active rate mod
        rate = RateFromNumber(SL.Global.ActiveModifiers.MusicRate)
    end
    if not rate then rate = "1.0" end
    if (not song) or (not steps) then return end

    local stats = (not iscourse) and WF.NewPlayerProfileSongStats() or WF.NewPlayerProfileCourseStats()
    WF.SongStatsUpdateChartAttributes(stats, song, steps, hash, pn)
    stats.RateMod = rate
    stats.PlayCount = 0
    
    WF.AddSongStatsToProfile(stats, pn)
    return stats
end

WF.AddPlayerProfileCourseStatsFromTrail = function(course, trail, rate, pn)
    return WF.AddPlayerProfileSongStatsFromSteps(course, trail, rate, nil, pn)
end

WF.SavePlayerProfileStats = function(pn)
    -- Need a player number to get the profile directory (lol)
    if not WF.OKToSaveProfileStats(pn) then return end

    local stats = WF.PlayerProfileStats[pn]
    if (not stats) or stats == {} then return end

    local dir = PROFILEMAN:GetProfileDir("ProfileSlot_Player"..pn)
    if (not dir) or dir == "" then return end

    -- table for all sections of the file
    local ft = {}

    -- first, the general stats
    local statsstr = string.format("#STATS\n%s\n%d\n%d\n%d\n%d,%d,%d,%d,%d,%d\n%d,%d\n%d,%d\n%d,%d\n%s\n%s",
        GetThemeVersion(), stats.SkillLv, stats.SongsPlayed, stats.CoursesPlayed, stats.TotalTapJudgments[1], stats.TotalTapJudgments[2],
        stats.TotalTapJudgments[3], stats.TotalTapJudgments[4], stats.TotalTapJudgments[5], stats.TotalTapJudgments[6],
        stats.TotalHolds[1], stats.TotalHolds[2], stats.TotalHolds[3], stats.TotalHolds[4],
        stats.TotalMines[1], stats.TotalMines[2], stats.LastSongPlayed, stats.LastPlayedDate)
    table.insert(ft, statsstr)

    -- add chart stats for every item in SongStats
    for chart in ivalues(stats.SongStats) do
        -- first, the general stats for the chart
        local hash = chart.ChartHash and chart.ChartHash or "-"
        local itgdp = tostring(chart.BestPercentDP_ITG)..(chart.Cleared_ITG or "")
        table.insert(ft, string.format("#SONG\n%s\n%s\n%s\n%s\n%s\n%s\n%d\n%d\n%d\n%d\n%s\n%d,%d,%d\n%d\n%d,%d,%d",
            chart.SongFullTitle, chart.SongArtist, chart.BPM, hash, chart.ChartID, chart.RateMod,
            chart.DifficultyRating, chart.PlayCount, chart.BestClearType, chart.BestPercentDP, itgdp,
            chart.BestFAPlusCounts[1], chart.BestFAPlusCounts[2], chart.BestFAPlusCounts[3], chart.TotalSteps,
            chart.TotalHolds, chart.TotalRolls, chart.TotalMines))

        -- finally, stats local to the best play on the chart
        local best = chart.BestPlay
        local mods = "-"
        if #best.SignificantMods > 0 then
            mods = table.concat(best.SignificantMods, ",")
        end
        table.insert(ft, string.format("%s\n%d,%d,%d,%d,%d,%d\n%d,%d\n%d\n%d,%d\n%d,%d,%d\n%d,%d,%d\n%s",
            best.DateObtained, best.Judgments[1], best.Judgments[2], best.Judgments[3], best.Judgments[4],
            best.Judgments[5], best.Judgments[6], best.Judgments[7], best.Judgments[8], best.Judgments[9],
            best.FAPlus[1], best.FAPlus[2], best.LifeBarVals[1], best.LifeBarVals[2], best.LifeBarVals[3],
            best.ScoreAtLifeEmpty[1], best.ScoreAtLifeEmpty[2], best.ScoreAtLifeEmpty[3], mods))
    end

    -- repeat above for courses
    for course in ivalues(stats.CourseStats) do
        -- first, the general stats for the course
        local itgdp = tostring(course.BestPercentDP_ITG)..(course.Cleared_ITG or "")
        table.insert(ft, string.format("#COURSE\n%s\n%s\n%s\n%s\n%d\n%d\n%d\n%d\n%s\n%d,%d,%d\n%d\n%d,%d,%d",
            course.CourseTitle, course.BPM, course.CourseID, course.RateMod,
            course.DifficultyRating, course.PlayCount, course.BestClearType, course.BestPercentDP, itgdp,
            course.BestFAPlusCounts[1], course.BestFAPlusCounts[2], course.BestFAPlusCounts[3], course.TotalSteps,
            course.TotalHolds, course.TotalRolls, course.TotalMines))

        -- finally, stats local to the best play on the chart
        local best = course.BestPlay
        local mods = "-"
        if #best.SignificantMods > 0 then
            mods = table.concat(best.SignificantMods, ",")
        end
        table.insert(ft, string.format("%s\n%d,%d,%d,%d,%d,%d\n%d,%d\n%d\n%d,%d\n%d,%d,%d\n%d,%d,%d\n%s",
            best.DateObtained, best.Judgments[1], best.Judgments[2], best.Judgments[3], best.Judgments[4],
            best.Judgments[5], best.Judgments[6], best.Judgments[7], best.Judgments[8], best.Judgments[9],
            best.FAPlus[1], best.FAPlus[2], best.LifeBarVals[1], best.LifeBarVals[2], best.LifeBarVals[3],
            best.ScoreAtLifeEmpty[1], best.ScoreAtLifeEmpty[2], best.ScoreAtLifeEmpty[3], mods))
    end

    -- temporary course string, in the event we loaded into non-marathon mode and didn't load course scores
    if stats.CourseTmpString then
        table.insert(ft, stats.CourseTmpString)
    end

    table.insert(ft, "")

    -- write file
    local fstr = table.concat(ft, "\n")
    if File.Write(dir.."/PlayerStats.wfs",fstr) then
        Trace("Player "..pn.." profile stats saved.")
    else
        SM("Player "..pn.." profile stats failed to save!")
    end
end

WF.LoadPlayerProfileStats = function(pn)
    -- Load all the stats from the main stats file
    local dir = PROFILEMAN:GetProfileDir("ProfileSlot_Player"..pn)
    WF.ProfileCardSubtitle[pn] = ""
    if (not dir) or dir == "" then
        -- nil the stats here and exit; this essentially means a guest profile is being used
        WF.PlayerProfileStats[pn] = nil
        return
    end

    local stats = WF.ProfileStatsTemplate()

    -- get subtitle for profile card
    if FILEMAN:DoesFileExist(dir.."/subtitle.txt") then
        WF.ProfileCardSubtitle[pn] = File.Read(dir.."/subtitle.txt")
        -- some light processing, since who knows what people will write in there
        WF.ProfileCardSubtitle[pn] = (WF.ProfileCardSubtitle[pn]:gsub("[\r\f\n]", " ")):sub(1, 20)
    else
        File.Write(dir.."/subtitle.txt", "")
    end

    if not FILEMAN:DoesFileExist(dir.."/PlayerStats.wfs") then
        -- file has not been created; just return
        WF.PlayerProfileStats[pn] = stats
        return
    end

    local sfile = File.Read(dir.."/PlayerStats.wfs")
    if not sfile then
        -- error loading file
        SM("Error loading stats for player "..pn.."!")
        WF.PlayerProfileStats[pn] = nil
        return
    end

    -- in order to save some load time in non-marathon mode, we can store everything starting from the first
    -- instance of #COURSE as a raw string, and just save that back to the file later
    if not GAMESTATE:IsCourseMode() then
        local cind = (sfile:find("#COURSE"))
        if cind then
            stats.CourseTmpString = sfile:sub(cind, -1)
        end
    end

    -- line by line logic to read everything from the file into the profile stats
    local ADDCOURSESPLAYED = false -- flag for if the stats file version is from before courses played was added
    local lines = split("\n", sfile)
    local token = ""
    local off = 1
    local songind = 0
    local courseind = 0
    local hash = ""
    local id = ""
    for i, line in ipairs(lines) do
        line = line:gsub("[\r\f\n]", "")
        if line == "#STATS" then
            token = "STATS"
            off = i
        elseif line == "#SONG" then
            token = "SONG"
            off = i
            if not stats.SongStats then
                stats.SongStats = { Lookup = {} }
            end
            table.insert(stats.SongStats, {})
            songind = #stats.SongStats
        elseif line == "#COURSE" then
            -- we can exit here if not in course mode
            if not GAMESTATE:IsCourseMode() then break end
            token = "COURSE"
            off = i
            if not stats.CourseStats then
                stats.CourseStats = { Lookup = {} }
            end
            table.insert(stats.CourseStats, {})
            courseind = #stats.CourseStats
        elseif token == "STATS" then
            local l = i - off
            if l == 1 then
                -- line 1 is wfversion
                if VersionCompare(line, "0.6.3") == -1 then
                    ADDCOURSESPLAYED = true
                    stats.ForceImportCourses = true -- force course import since they weren't available before

                    -- back up old player stats file
                    if not FILEMAN:DoesFileExist(dir.."/PlayerStats_062") then
                        File.Write(dir.."/PlayerStats_062", sfile)
                    end
                    -- back up ecfa stats file if exists
                    BackUpECFA2021Stats(dir)
                end
            elseif l == 2 then
                -- line 2 is skill lv
                stats.SkillLv = tonumber(line)
            elseif l == 3 then
                -- line 3 is songs played
                if not ADDCOURSESPLAYED then stats.SongsPlayed = tonumber(line) end
            elseif l == 4 then
                -- courses played
                if not ADDCOURSESPLAYED then stats.CoursesPlayed = tonumber(line)
                else stats.SongsPlayed = tonumber(line) end
            elseif l == 5 then
                -- judgment counts
                local judges = line:split_tonumber()
                stats.TotalTapJudgments = {judges[1],judges[2],judges[3],judges[4],judges[5],judges[6]}
            elseif l == 6 then
                -- holds
                local holds = line:split_tonumber()
                stats.TotalHolds = {holds[1],holds[2],0,0}
            elseif l == 7 then
                -- rolls
                local rolls = line:split_tonumber()
                stats.TotalHolds[3] = rolls[1]
                stats.TotalHolds[4] = rolls[2]
            elseif l == 8 then
                -- mines
                local mines = line:split_tonumber()
                stats.TotalMines = {mines[1],mines[2]}
            elseif l == 9 then
                -- last song played
                stats.LastSongPlayed = line
            elseif l == 10 then
                -- last played date
                stats.LastPlayedDate = line
            end
        elseif token == "SONG" or token == "COURSE" then
            local l = i - off
            if token == "COURSE" and l >= 2 then l = (i - off) + 1 end
            if token == "COURSE" and l >= 4 then l = (i - off) + 2 end
            local song = (token == "SONG") and stats.SongStats[songind] or stats.CourseStats[courseind]
            local titlestr = (token == "SONG") and "SongFullTitle" or "CourseTitle"
            local idstr = (token == "SONG") and "ChartID" or "CourseID"
            local updtbl = (token == "SONG") and stats.SongStats or stats.CourseStats
            local updind = (token == "SONG") and songind or courseind
            if l == 1 then
                -- full title
                song[titlestr] = line
            elseif l == 2 then
                -- artist
                song.SongArtist = line
            elseif l == 3 then
                -- bpm string
                song.BPM = line
            elseif l == 4 then
                -- hash
                hash = line
                song.ChartHash = hash ~= "-" and hash or nil
            elseif l == 5 then
                -- id
                id = line
                song[idstr] = id
            elseif l == 6 then
                -- rate mod
                song.RateMod = line
                if song.ChartHash then
                    UpdateLookupEntry(stats.SongStats, hash, song.RateMod, songind)
                end
                UpdateLookupEntry(updtbl, id, song.RateMod, updind)
            elseif l == 7 then
                -- difficulty rating
                song.DifficultyRating = tonumber(line)
            elseif l == 8 then
                -- play count
                song.PlayCount = tonumber(line)
            elseif l == 9 then
                -- clear type
                song.BestClearType = tonumber(line)
            elseif l == 10 then
                -- high score
                song.BestPercentDP = tonumber(line)
            elseif l == 11 then
                -- high itg score
                -- this also contains pass/fail for itg
                local clr = line:match("[FC]") and line:sub(-1)
                local dp = tonumber((line:gsub("[FC]", "")))
                song.BestPercentDP_ITG = dp
                song.Cleared_ITG = clr or (dp ~= 0 and "C")
                ConvertFailToNone(song) -- compensate for unplayed in wf/played in itg, see utilities below
            elseif l == 12 then
                -- high fa+ counts
                local counts = line:split_tonumber()
                song.BestFAPlusCounts = {counts[1],counts[2],counts[3]}
            elseif l == 13 then
                -- total steps
                song.TotalSteps = tonumber(line)
            elseif l == 14 then
                -- holds, rolls, mines
                local vals = line:split_tonumber()
                song.TotalHolds = vals[1]
                song.TotalRolls = vals[2]
                song.TotalMines = vals[3]
            elseif l == 15 then
                -- best play section; date obtained
                song.BestPlay = {}
                song.BestPlay.DateObtained = line
            elseif l == 16 then
                -- tap judgments
                local counts = line:split_tonumber()
                song.BestPlay.Judgments = {counts[1],counts[2],counts[3],counts[4],counts[5],counts[6],0,0,0}
            elseif l == 17 then
                -- hold judgments
                local held = line:split_tonumber()
                song.BestPlay.Judgments[7] = held[1]
                song.BestPlay.Judgments[8] = held[2]
            elseif l == 18 then
                -- mine hits
                song.BestPlay.Judgments[9] = tonumber(line)
            elseif l == 19 then
                -- fa+
                local counts = line:split_tonumber()
                song.BestPlay.FAPlus = {counts[1],counts[2]}
            elseif l == 20 then
                -- lifebar vals
                local vals = line:split_tonumber()
                song.BestPlay.LifeBarVals = {vals[1],vals[2],vals[3]}
            elseif l == 21 then
                -- score at life empty
                local vals = line:split_tonumber()
                song.BestPlay.ScoreAtLifeEmpty = {vals[1],vals[2],vals[3]}
            elseif l == 22 then
                -- significant mods
                local mods = split(",", line)
                song.BestPlay.SignificantMods = {}
                if line ~= "-" then
                    for mod in ivalues(mods) do
                        table.insert(song.BestPlay.SignificantMods, mod)
                    end
                end
            end
        end
    end

    WF.PlayerProfileStats[pn] = stats

    -- consolidate scores
    WF.ConsolidateProfileSongAndCourseStats(pn)

    -- do aggregate math stuff
    WF.CalculateClearTypeAndGradeCounts(pn)

    -- if preferred, preload ct/grade cache
    -- if "always merge" is on, we defer this to the merge function, so that it only happens once instead of 4 times
    if ThemePrefs.Get("PreloadGrades") and (not ThemePrefs.Get("AlwaysMergeScores")) then
        WF.PreloadClearsAndGrades(pn)
    end

    Trace("Player "..pn.." profile stats loaded.")
end

WF.CalculateClearTypeAndGradeCounts = function(pn)
    -- This calculation will be done on loading profile stats. Call it after everything has loaded from the file.
    local stats = WF.PlayerProfileStats[pn]
    if not stats then return end

    stats.ClearTypeCounts = {0,0,0,0,0,0,0,0,  0} -- last index here is basically a dummy for unplayed
    stats.GradeCounts = {0,0,0,0,0,0,0}
    stats.GradeCounts_ITG = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
    stats.CourseClearTypeCounts = {0,0,0,0,0,0,0,0,  0}
    stats.CourseGradeCounts = {0,0,0,0,0,0,0}
    stats.CourseGradeCounts_ITG = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

    for song in ivalues(stats.SongStats) do
        stats.ClearTypeCounts[song.BestClearType] = stats.ClearTypeCounts[song.BestClearType] + 1
        local grade = CalculateGrade(song.BestPercentDP)
        stats.GradeCounts[grade] = stats.GradeCounts[grade] + 1
        local itggrade = CalculateGradeITG(song)
        if itggrade ~= 99 then stats.GradeCounts_ITG[itggrade] = stats.GradeCounts_ITG[itggrade] + 1 end
    end
    for course in ivalues(stats.CourseStats) do
        stats.CourseClearTypeCounts[course.BestClearType] = stats.CourseClearTypeCounts[course.BestClearType] + 1
        local grade = CalculateGrade(course.BestPercentDP)
        stats.CourseGradeCounts[grade] = stats.CourseGradeCounts[grade] + 1
        local itggrade = CalculateGradeITG(course)
        if itggrade ~= 99 then stats.CourseGradeCounts_ITG[itggrade] = stats.CourseGradeCounts_ITG[itggrade] + 1 end
    end
end

WF.OKToSaveProfileStats = function(pn)
    -- always check this before saving stuff to the profile stats
    return (not WF.ProfileInvalid[pn]) and (WF.PlayerProfileStats[pn] ~= nil)
end

WF.ProfileStatsTemplate = function()
    local stats = {
        SkillLv = 0,
        SongsPlayed = 0,
        CoursesPlayed = 0,
        TotalTapJudgments = {0,0,0,0,0,0},
        TotalHolds = {0,0,0,0},
        TotalMines = {0,0},
        LastSongPlayed = "3D Movie Maker/Bistro Evil Theme",
        LastPlayedDate = WF.DateString(),

        ClearTypeCounts = {0,0,0,0,0,0,0,0,  0}, -- last index here is basically a dummy for unplayed
        GradeCounts = {0,0,0,0,0,0,0},
        SessionAchievements = {0,0,0,0,0,0,0},
        
        GradeCounts = {0,0,0,0,0,0,0},
        SessionAchievements = {0,0,0,0,0,0,0},
        GradeCounts_ITG = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
        CourseClearTypeCounts = {0,0,0,0,0,0,0,0,  0},
        CourseGradeCounts = {0,0,0,0,0,0,0},
        CourseGradeCounts_ITG = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},

        GroupClearsAndGrades = {},

        SongStats = {
            Lookup = {}
        },
        CourseStats = {
            Lookup = {}
        }
    }

    return stats
end

WF.WriteDetailedHighScoreStats = function(pn, hsitem, filenameext, filename, courseind)
    -- This should be called at evaluation. It will directly access the detailed judgments table for the current
    -- song and use it to write to the file.
    -- hsitem should be the newly created high score item for the player profile; it's necessary that one was created
    -- if we're writing a new detailed file, so we can get all the general data from it.
    -- filename will override the default name, filenameext will be appended to the filename
    -- pass in courseind for the index of a song within a course
    if not WF.OKToSaveProfileStats(pn) then return end

    local song, steps, detailed
    if not courseind then
        song = GAMESTATE:GetCurrentSong()
        steps = GAMESTATE:GetCurrentSteps("PlayerNumber_P"..pn)
        detailed = SL["P"..pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].detailed_judgments
    else
        local te = GAMESTATE:GetCurrentTrail("PlayerNumber_P"..pn):GetTrailEntry(courseind-1)
        song = te:GetSong()
        steps = te:GetSteps()
        detailed = WF.DetailedJudgmentsPerSongInCourse[pn][courseind]
    end

    if not detailed then return end

    local hashorid = hsitem and (hsitem.ChartHash and hsitem.ChartHash or hsitem.ChartID)

    local abbrev = {Miss = "M", Held = "H", LetGo = "D", HitMine = "N"}

    -- file string will be built from a table to avoid using .. which is bad on performance
    local ft = {}

    if not hsitem then
        -- create a dummy (haha dummy!!!! HHHASHAHAHAHHSH) hsitem from steps if none is passed in
        -- steps can be passed in as an argument, which is useful for courses
        local player = "PlayerNumber_P"..pn
        hsitem = WF.NewPlayerProfileSongStats()
        local id = WF.GetStepsID(song, steps)
        hashorid = WF.HashCache[id]
        if not hashorid then return end
        local judges = STATSMAN:GetCurStageStats():GetPlayerStageStats(player):GetRadarActual()
        WF.SongStatsUpdateChartAttributes(hsitem, song, steps, hashorid, pn)
        hsitem.RateMod = RateFromNumber(SL.Global.ActiveModifiers.MusicRate)
        hsitem.BestPlay.SignificantMods = GetSignificantMods(player)
        hsitem.BestPlay.DateObtained = WF.DateTimeString()
        hsitem.BestPlay.Judgments[7] = judges:GetValue("Holds")
        hsitem.BestPlay.Judgments[8] = judges:GetValue("Rolls")
    end

    local fname = filename or LookupIdentifier(hashorid, hsitem.RateMod):gsub("/", "]]][[[")
    if filenameext then fname = fname..filenameext end
    local fullpath = PROFILEMAN:GetProfileDir("ProfileSlot_Player"..pn).."/detailed/"..fname

    -- general info
    local smods = (#hsitem.BestPlay.SignificantMods > 0) and table.concat(hsitem.BestPlay.SignificantMods, ",") or "-"
    local songstr = string.format("%s\n%s\n%s\n%s\n%s\n%d\n%s\n%s\n%d\n%d\n%d\n%d\n%d\n%d\n%s",
        GetThemeVersion(), hsitem.SongFullTitle, hsitem.SongArtist, hsitem.BPM, hsitem.ChartID, hsitem.DifficultyRating,
        hsitem.BestPlay.DateObtained, hsitem.RateMod, hsitem.TotalSteps, hsitem.TotalHolds, hsitem.BestPlay.Judgments[7],
        hsitem.TotalRolls, hsitem.BestPlay.Judgments[8], hsitem.TotalMines, smods)
    table.insert(ft, songstr)

    -- loop through all judgments and output corresponding data
    for judge in ivalues(detailed) do
        -- {seconds, tns, panels, offset}
        local p = (#judge == 3) and string.format("%d", judge[3]) or table.concat(judge[3], "")
        local off = (#judge == 3 or judge[2] == "Miss") and abbrev[judge[2]] or string.format("%f", judge[4])
        table.insert(ft, string.format("%f;%s;%s", judge[1], off, p))
    end
    
    table.insert(ft, "")

    local fstr = table.concat(ft, "\n")

    -- write file
    if not File.Write(fullpath, fstr) then
        SM("Error writing detailed file!")
        return false
    end

    return true
end

WF.WriteDetailedHighScoreStatsFromCourseList = function(pn, filenameext, list)
    -- this will sequentially write the detailed files for all songs in a course within the list of indices passed
    -- list should just be an array of song indices like {2, 4, 5}
    -- this will be leveraged for saving all upscores in a course.
    -- don't ever use the word leveraged in that way, it's really dumb ok
    local count = 0
    for ind in ivalues(list) do
        if  WF.WriteDetailedHighScoreStats(pn, nil, filenameext, nil, ind) then
            count = count + 1
        end
    end
    return count
end

WF.WriteAllDetailedHighScoresForCourse = function(pn, wfuslist, itguslist)
    -- this will call the above function three times. once for each env's upscores, and once for "saved"
    -- for every song in the course
    local count = 0
    count = count + WF.WriteDetailedHighScoreStatsFromCourseList(pn, nil, wfuslist)
    count = count + WF.WriteDetailedHighScoreStatsFromCourseList(pn, "_ITG", itguslist)

    -- save each individual file to saved directory
    for i = 1, #WF.DetailedJudgmentsPerSongInCourse[pn] do
        local te = GAMESTATE:GetCurrentTrail("PlayerNumber_P"..pn):GetTrailEntry(i-1)
        local song = te:GetSong()
        local steps = te:GetSteps()
        local songtitle = (song:GetDisplayMainTitle():gsub("[^A-Z^a-z^0-9]", ""))
		if (not songtitle) or (songtitle == "") then
			songtitle = (song:GetTranslitMainTitle():gsub("[^A-Z^a-z^0-9]", ""))
		end
		if (not songtitle) or (songtitle == "") then songtitle = "UnknownSong" end
		local diff = THEME:GetString("Difficulty",
			ToEnumShortString(steps:GetDifficulty()))
		local datestr = (WF.DateTimeString():gsub(":", ""):gsub(" ", "_"))
		local fname = "/saved/"..songtitle.."_"..diff.."_"..datestr

        if WF.WriteDetailedHighScoreStats(pn, nil, nil, fname, i) then
            count = count + 1
        end
    end

    return count
end


-- machine stats will be much more limited, basically just lists of high scores
--[[ format
{
    SongStats = {
        -- list of items similar to player profile; each item contains a "machine record list"
        -- consisting of "machine record items"
        {
            SongFullTitle = "title",
            SongArtist = "artist",
            BPM = "bpm string",
            ChartHash = "hash",
            ChartID = "id",
            RateMod = "1.xx",
            DifficultyRating = diff,
            PlayCount = count,
            HighScoreList = {
                {
                    PlayerFullName = "name", PlayerHSName = "REEN", PlayerGuid = "guid",
                    DateObtained = "YYYY-MM-DD HH:MM:SS", PercentDP = (0-10000)
                },
                ...
            },
            HighScoreList_ITG = {
                (same format)
            }
        },
        ...
        Lookup = { (Hash)={rate = ind}, (ID)={rate = ind}, ... }
    },
    CourseStats = {
        ...
    }
}
]]
WF.MaxMachineRecordsPerChart = 10
WF.MachineProfileStatsTemplate = function()
    local stats = {
        SongStats = { Lookup = {} },
        CourseStats = { Lookup = {} }
    }
    return stats
end

WF.NewMachineProfileSongStats = function()
    -- create and return a blank chart stats item, but don't actually add it to the profile table.
    -- we mainly don't want to add it because we need the chart id, hash and rate mod first.
    local stats = {
        SongFullTitle = "",
        SongArtist = "",
        BPM = "",
        ChartHash = nil,
        ChartID = "",
        RateMod = "1.0",
        DifficultyRating = 1,
        PlayCount = 0,
        HighScoreList = {},
        HighScoreList_ITG = {}
    }
    setmetatable(stats.HighScoreList, mt_machinerecordlist)
    setmetatable(stats.HighScoreList_ITG, mt_machinerecordlist)

    return stats
end

WF.NewMachineProfileCourseStats = function()
    local stats = WF.NewMachineProfileSongStats()
    stats.SongFullTitle = nil
    stats.SongArtist = nil
    stats.ChartHash = nil
    stats.ChartID = nil
    stats.CourseTitle = ""
    stats.CourseID = ""

    return stats
end

WF.MergeMachineProfileSongStats = function(stats1, stats2)
    local iscourse = (stats1.CourseTitle ~= nil)
    local newstats = WF.NewMachineProfileSongStats()

    if (not ((not iscourse) and stats1.ChartHash == stats2.ChartHash and stats1.RateMod == stats2.RateMod))
    and (not ((iscourse) and stats1.CourseID == stats2.CourseID and stats1.RateMod == stats2.RateMod)) then
        Trace(string.format("Stats merge error:\nhash/id 1: %s\nrate 1: %s\nhash/id 2: %s\nrate 2:%s",
            (not iscourse) and stats1.ChartHash or stats1.CourseID, stats1.RateMod,
            (not iscourse) and stats2.ChartHash or stats2.CourseID, stats2.RateMod))
        return
    end

    newstats.SongFullTitle = stats1.SongFullTitle
    newstats.SongArtist = stats1.SongArtist
    newstats.CourseTitle = stats1.CourseTitle
    newstats.BPM = stats1.BPM
    newstats.ChartID = stats1.ChartID
    newstats.CourseID = stats1.CourseID
    newstats.ChartHash = stats1.ChartHash
    newstats.RateMod = stats1.RateMod
    newstats.DifficultyRating = stats1.DifficultyRating
    newstats.PlayCount = stats1.PlayCount + stats2.PlayCount

    for score in ivalues(stats1.HighScoreList) do
        table.insert(newstats.HighScoreList, score)
    end
    for score in ivalues(stats2.HighScoreList) do
        table.insert(newstats.HighScoreList, score)
    end
    for score in ivalues(stats1.HighScoreList_ITG) do
        table.insert(newstats.HighScoreList_ITG, score)
    end
    for score in ivalues(stats2.HighScoreList_ITG) do
        table.insert(newstats.HighScoreList_ITG, score)
    end

    return newstats
end

WF.MergeMachineProfileCourseStats = WF.MergeMachineProfileSongStats

WF.AddSongStatsToProfile = function(stats, pn)
    -- this function actually adds it to the profile stats table. assume chart id, hash and rate are finally set.
    -- originally this was just for machine profile, but doing it for player profile is exactly the same just using
    -- a different main stats table, so just pass nil for pn to get machine profile.
    local stable = (pn ~= nil) and WF.PlayerProfileStats[pn] or WF.MachineProfileStats
    if not stable then return end

    local iscourse = (stats.CourseTitle ~= nil)
    local list = (not iscourse) and stable.SongStats or stable.CourseStats

    table.insert(list, stats)
    local ind = #list
    if stats.ChartHash then
        UpdateLookupEntry(list, stats.ChartHash, stats.RateMod, ind)
    end
    UpdateLookupEntry(list, (not iscourse) and stats.ChartID or stats.CourseID, stats.RateMod, ind)
end

WF.AddCourseStatsToProfile = WF.AddSongStatsToProfile

WF.SongStatsUpdateChartAttributes = function(stats, song, steps, hash, pn)
    -- reusing this code so putting it here. updates things like title, artist, difficulty, etc based on the steps
    -- passed in. this should actually be called any time a score is achieved because there is some chance the simfile
    -- would have been changed.
    -- this doesn't access the Machine or Player song stats tables, but passing in pn will indicate that it's
    -- a player song stats object, meaning step counts etc will need to be updated too.
    local iscourse = (stats.CourseTitle ~= nil) -- if course, "song" is course and "steps" is trail
    local player
    if pn then player = "PlayerNumber_P"..pn end
    local id = WF.GetItemID(song, steps)

    -- generate hash if one isn't passed in (better to not parse again if we don't need to)
    if (not iscourse) and (not hash) then
        -- #HashCash
        if not WF.HashCache[id] then
            -- [TODO] at the moment, this won't work
            --local stype = steps:GetStepsType():gsub("StepsType_",""):lower():gsub("_", "-")
            --hash = GenerateHash(steps, stype, ToEnumShortString(steps:GetDifficulty()))
            --WF.HashCache[id] = hash
        else
            hash = WF.HashCache[id]
        end
    end

    stats.SongFullTitle = (not iscourse) and song:GetDisplayFullTitle() or nil
    stats.CourseTitle = (iscourse) and song:GetDisplayFullTitle() or nil
    stats.SongArtist = (not iscourse) and song:GetDisplayArtist() or nil
    stats.BPM = StringifyDisplayBPMs(player, steps, tonumber(rate)):gsub(" ", "")
    stats.ChartHash = ((not iscourse) and (hash ~= "")) and hash or nil
    stats.ChartID = (not iscourse) and WF.GetStepsID(song, steps) or nil
    stats.CourseID = (iscourse) and WF.GetCourseID(song, steps) or nil
    stats.DifficultyRating = steps:GetMeter()

    if pn then
        local radar = steps:GetRadarValues((not iscourse) and player or nil)
        stats.TotalSteps = radar:GetValue("RadarCategory_TapsAndHolds")
        stats.TotalHolds = radar:GetValue("RadarCategory_Holds")
        stats.TotalRolls = radar:GetValue("RadarCategory_Rolls")
        stats.TotalMines = radar:GetValue("RadarCategory_Mines")
    end
end

WF.CourseStatsUpdateAttributes = function(stats, course, trail, pn)
    WF.SongStatsUpdateChartAttributes(stats, course, trail, nil, pn)
end

WF.AddMachineProfileSongStatsFromSteps = function(song, steps, rate, hash, player)
    -- create a new stats object with information from the song and steps passed (and optional rate mod),
    -- and add it to the machine profile stats table.
    -- player is unused unless steps and/or rate are nil. if either is nil, get them from the player passed.
    if not song then
        song = (not GAMESTATE:IsCourseMode()) and GAMESTATE:GetCurrentSong() or GAMESTATE:GetCurrentCourse()
    end
    local iscourse = (song.GetAllSteps == nil)
    if (player) and (not steps) then
        steps = (not iscourse) and GAMESTATE:GetCurrentSteps(player) or GAMESTATE:GetCurrentTrail(player)
        rate = RateFromNumber(SL.Global.ActiveModifiers.MusicRate)
    end
    if not rate then rate = "1.0" end
    if (not song) or (not steps) then return end

    local stats = (not iscourse) and WF.NewMachineProfileSongStats() or WF.NewMachineProfileCourseStats()
    WF.SongStatsUpdateChartAttributes(stats, song, steps, hash)
    stats.RateMod = rate
    stats.PlayCount = 0
    
    WF.AddSongStatsToProfile(stats)
    return stats
end

WF.AddMachineProfileCourseStatsFromTrail = function(course, trail, rate, player)
    return WF.AddMachineProfileSongStatsFromSteps(course, trail, rate, nil, player)
end

WF.NewMachineRecordItem = function()
    -- return a blank machine record object
    local mr = {
        PlayerFullName = "",
        PlayerHSName = "",
        PlayerGuid = "",
        DateObtained = "0000-00-00 00:00:00",
        PercentDP = 0
    }
    setmetatable(mr, mt_machinerecorditem)

    return mr
end

mt_machinerecorditem = {
    __lt = function(a, b)
        if a.PercentDP ~= b.PercentDP then
            return (a.PercentDP < b.PercentDP)
        else
            return (WF.CompareDateTime(a.DateObtained, b.DateObtained) == -1)
        end
    end,
    __le = function(a, b)
        if a.PercentDP ~= b.PercentDP then
            return (a.PercentDP < b.PercentDP)
        else
            return (WF.CompareDateTime(a.DateObtained, b.DateObtained) ~= 1)
        end
    end,
    __eq = function(a, b)
        return ((a.PercentDP == b.PercentDP) and (WF.CompareDateTime(a.DateObtained, b.DateObtained) == 0))
    end
}

mt_machinerecordlist = {
    __newindex = function(list, ind, item)
        -- basically, any time a new item is added to the high score list, sort the list in descending score order
        -- and remove the lowest from the list if there are more items than the max
        --Trace("INSERTING ITEM "..tostring(item).." INTO "..tostring(list).." AT "..tostring(ind))
        rawset(list, ind, item)
        table.sort(list, function(a, b) return a > b end)
        if #list > WF.MaxMachineRecordsPerChart then
            table.remove(list, WF.MaxMachineRecordsPerChart + 1)
        end
    end
}

WF.SaveMachineProfileStats = function()
    local stats = WF.MachineProfileStats
    if (not stats) or stats == {} then return end

    local dir = PROFILEMAN:GetProfileDir("ProfileSlot_Machine")
    if (not dir) or dir == "" then return end

    local ft = {}

    table.insert(ft, GetThemeVersion())

    -- song stats
    for song in ivalues(stats.SongStats) do
        local hash = song.ChartHash and song.ChartHash or "-"
        table.insert(ft, string.format("#SONG\n%s\n%s\n%s\n%s\n%s\n%s\n%d\n%d", song.SongFullTitle, song.SongArtist,
            song.BPM, hash, song.ChartID, song.RateMod, song.DifficultyRating, song.PlayCount))
        for score in ivalues(song.HighScoreList) do
            table.insert(ft, string.format("$SCORE\n%s\n%s\n%s\n%s\n%d", score.PlayerFullName, score.PlayerHSName,
            score.PlayerGuid, score.DateObtained, score.PercentDP))
        end
        for score in ivalues(song.HighScoreList_ITG) do
            table.insert(ft, string.format("$ITG\n%s\n%s\n%s\n%s\n%d", score.PlayerFullName, score.PlayerHSName,
            score.PlayerGuid, score.DateObtained, score.PercentDP))
        end
    end

    -- course stats
    for course in ivalues(stats.CourseStats) do
        table.insert(ft, string.format("#COURSE\n%s\n%s\n%s\n%s\n%d\n%d", course.CourseTitle,
            course.BPM, course.CourseID, course.RateMod, course.DifficultyRating, course.PlayCount))
        for score in ivalues(course.HighScoreList) do
            table.insert(ft, string.format("$SCORE\n%s\n%s\n%s\n%s\n%d", score.PlayerFullName, score.PlayerHSName,
            score.PlayerGuid, score.DateObtained, score.PercentDP))
        end
        for score in ivalues(course.HighScoreList_ITG) do
            table.insert(ft, string.format("$ITG\n%s\n%s\n%s\n%s\n%d", score.PlayerFullName, score.PlayerHSName,
            score.PlayerGuid, score.DateObtained, score.PercentDP))
        end
    end

    table.insert(ft, "")

    -- write to file
    local fstr = table.concat(ft, "\n")
    if File.Write(dir.."/MachineStats.wfm",fstr) then
        Trace("Machine profile stats saved.")
    else
        SM("Machine profile stats failed to save!")
    end

    -- write hash cache here
    if WF.HashCache then
        WF.SaveHashCache()
    end
end

WF.LoadMachineProfileStats = function()
    -- Load all the stats from the main stats file
    local dir = PROFILEMAN:GetProfileDir("ProfileSlot_Machine")
    if (not dir) or dir == "" then
        -- trace error and exit
        SM("No machine profile directory found!")
        return
    end

    WF.MachineProfileStats = WF.MachineProfileStatsTemplate()

    if not FILEMAN:DoesFileExist(dir.."/MachineStats.wfm") then
        -- file has not been created; just return
        return
    end

    local sfile = File.Read(dir.."/MachineStats.wfm")
    if not sfile then
        -- error loading file
        SM("Error loading stats for machine profile!")
        return
    end

    -- line by line logic
    local lines = split("\n", sfile)
    local token = ""
    local off = 1
    local songind = 0
    local hash = ""
    local id = ""
    local curstats
    local score
    for i, line in ipairs(lines) do
        line = line:gsub("[\r\f\n]", "")
        if i == 1 then
            -- version
            if VersionCompare(line, "0.6.3") == -1 then
                WF.MachineProfileStats.ForceImportCourses = true
            end
        elseif (line == "#SONG") or (line == "#COURSE") or line:match("$.*") then
            token = line:sub(2)
            off = i
        elseif token == "SONG" or token == "COURSE" then
            local l = i - off
            if token == "COURSE" and l >= 2 then l = (i - off) + 1 end
            if token == "COURSE" and l >= 4 then l = (i - off) + 2 end
            local titlestr = (token == "SONG") and "SongFullTitle" or "CourseTitle"
            local idstr = (token == "SONG") and "ChartID" or "CourseID"
            if l == 1 then
                -- new song stats
                curstats = (token == "SONG") and WF.NewMachineProfileSongStats() or WF.NewMachineProfileCourseStats()
                curstats[titlestr] = line
            elseif l == 2 then
                curstats.SongArtist = line
            elseif l == 3 then
                curstats.BPM = line
            elseif l == 4 then
                hash = line
                curstats.ChartHash = (hash ~= "-") and hash or nil
            elseif l == 5 then
                id = line
                curstats[idstr] = id
            elseif l == 6 then
                curstats.RateMod = line
            elseif l == 7 then
                curstats.DifficultyRating = tonumber(line)
            elseif l == 8 then
                curstats.PlayCount = tonumber(line)
                WF.AddSongStatsToProfile(curstats)
            end
        elseif token == "SCORE" or token == "ITG" then
            local l = i - off
            if l == 1 then
                -- new record item
                score = WF.NewMachineRecordItem()
                score.PlayerFullName = line
            elseif l == 2 then
                score.PlayerHSName = line
            elseif l == 3 then
                score.PlayerGuid = line
            elseif l == 4 then
                score.DateObtained = line
            elseif l == 5 then
                score.PercentDP = tonumber(line)
                -- insert into corresponding table
                local ext = (token == "ITG") and "_ITG" or ""
                curstats["HighScoreList"..ext][#curstats["HighScoreList"..ext]+1] = score
            end
        end
    end

    -- consolidate
    WF.ConsolidateProfileSongAndCourseStats()

    Trace("Machine profile stats loaded.")
end


-- functions to easily get the propler song stats item given hash, id or song/steps
-- for the general ones of these, separate functions must be called for song vs course, but "FromSteps" can
-- be called with a course/trail in the same way as above
WF.FindProfileSongStats = function(hashorid, rate, pn)
    -- pass in either a hash or a chart id. simple logic will determine which to use.
    local identifier = hashorid:match("/") and "ChartID" or "ChartHash"
    
    -- pass no pn for machine profile
    local stats = pn ~= nil and WF.PlayerProfileStats[pn] or WF.MachineProfileStats
    if not stats then return end

    -- default to 1.0
    if not rate then rate = "1.0" end

    -- first just check using the lookup table
    local lookupind = CheckLookupEntry(stats.SongStats, hashorid, rate)
    if lookupind then
        return stats.SongStats[lookupind]
    end

    -- if this returns nil, you know to add a new item
end

WF.FindProfileCourseStats = function(id, rate, pn)
    -- pass no pn for machine profile
    local stats = pn ~= nil and WF.PlayerProfileStats[pn] or WF.MachineProfileStats
    if not stats then return end

    -- default to 1.0
    if not rate then rate = "1.0" end

    -- first just check using the lookup table
    local lookupind = CheckLookupEntry(stats.CourseStats, id, rate)
    if lookupind then
        return stats.CourseStats[lookupind]
    end
end

WF.FindProfileSongStatsFromSteps = function(song, steps, rate, hash, pn)
    local stats
    local iscourse = (song.GetAllSteps == nil)
    local id = WF.GetItemID(song, steps)

    -- check hash first
    -- no hash needs to be passed in, but it's better to pass one in if it already exists somewhere, that way
    -- we aren't parsing the file a bunch of times for no reason
    if (not iscourse) and (not hash) then
        -- first check the #HashCash for the hash, genearate it and add it to the #HashCash if it's not there
        if not WF.HashCache[id] then
            -- [TODO] at the moment, this won't work
            --local stype = steps:GetStepsType():gsub("StepsType_",""):lower():gsub("_", "-")
            --hash = GenerateHash(steps, stype, ToEnumShortString(steps:GetDifficulty()))
            --WF.HashCache[id] = hash
        else
            hash = WF.HashCache[id]
        end
    end
    if hash and (hash ~= "") then
        stats = WF.FindProfileSongStats(hash, rate, pn)
    end

    if stats then return stats end

    -- next check by id, and if the hash is valid, update the hash in the item
    if id and (id ~= "") then
        stats = (not iscourse) and WF.FindProfileSongStats(id, rate, pn) or WF.FindProfileCourseStats(id, rate, pn)
    end

    if stats and hash and (hash ~= "") then
        stats.ChartHash = hash
        WF.HashCache[id] = hash
        local t = pn ~= nil and WF.PlayerProfileStats[pn] or WF.MachineProfileStats
        UpdateLookupEntry(t.SongStats, hash, rate, FindInTable(stats, t.SongStats))
    end

    return stats
end

WF.FindProfileCourseStatsFromTrail = function(course, trail, rate, pn)
    return WF.FindProfileSongStatsFromSteps(course, trail, rate, nil, pn)
end

WF.GetMusicWheelSongStats = function(song, steps, rate, pn)
    -- similar to above, but this will also return a stats for any rate mod if one for the selected rate doesn't exist
    -- music wheel item has the responsibility of checking what is in this object to determine what shows up
    if not WF.PlayerProfileStats[pn] then return end
    local iscourse = (song.GetAllSteps == nil)

    local id = WF.GetItemID(song, steps)
    local hash = (not iscourse) and WF.HashCache[id] or nil
    if (not iscourse) and (not hash) then return end

    local playerstats = (not iscourse) and WF.PlayerProfileStats[pn].SongStats or WF.PlayerProfileStats[pn].CourseStats
    local lookup = (not iscourse) and playerstats.Lookup[hash] or playerstats.Lookup[id]
    if not lookup then return end

    if lookup[rate] then
        return playerstats[lookup[rate]]
    else
        local maxrate = 0
        local returnrate = ""
        for irate, ind in pairs(lookup) do
            local n = tonumber(irate)
            if n > maxrate then
                maxrate = n
                returnrate = irate
            end
        end
        return playerstats[lookup[returnrate]]
    end
end

WF.GetMusicWheelCourseStats = WF.GetMusicWheelSongStats


-- The following function will handle all the steps for recording to player and machine profiles at the end of a song
-- Returns HSInfo in the format:
--[[
{
    -- p1
    {
        PlayerSongStats = (song stats for current chart in player profile),
        PlayerSongStats_Old = (copy of song stats before update, for comparisons),
        MachineSongStats = (song stats for current chart in machine profile),
        MachineHSInd = (index of high score obtained after inserting to machine profile),
        MachineHSInd_ITG = (itg high score index),
        -- (if course)
        PlayerCourseStats = (CourseStats item),
        PlayerCourseStats_Old = (copy of old CourseStats),
        PlayerCourseSongStats = {(SongStats for song n of marathon)},
        PlayerCourseSongStats_Old = {(copy of old SongStats for song n in marathon)},
        MachineCourseStats = (machine CourseStats item),
        MachineCourseSongStats = {(SongStats for song n of marathon)},
        MachineCourseSongHSInd = {(index of machine high score for song n within course)},
        MachineCourseSongHSInd_ITG = {(itg high score index for song n in marathon)},
        UpscoreSongIndList = {n, n, ...},
        UpscoreSongIndList_ITG = {n, n, ...}
    },
    -- p2
    ...
}
]]
WF.UpdateProfilesOnEvaluation = function(hashes)
    -- see WF-Scoring for StatsObject (this will definitely be revised and less messy later but it's useful here)
    -- hashes should be a table {p1hash, p2hash} -- indices must be player numbers, so for p2 alone {nil, hash}
    local iscourse = GAMESTATE:IsCourseMode()
    local song = (not iscourse) and GAMESTATE:GetCurrentSong() or GAMESTATE:GetCurrentCourse()
    local players = GAMESTATE:GetHumanPlayers()
    local rate = RateFromNumber(SL.Global.ActiveModifiers.MusicRate)
    local dateobtained = WF.DateTimeString()

    -- for a song, there is only one item, but for a course, there is one for the course itself,
    -- and one for each song in the course
    local allitems = {}
    for player in ivalues(players) do
        local pn = tonumber(player:sub(-1))
        local steps = (not iscourse) and GAMESTATE:GetCurrentSteps(player) or GAMESTATE:GetCurrentTrail(player)
        allitems[pn] = {}
        table.insert(allitems[pn], {song, steps})
        if iscourse then
            for i = 1, WF.CurrentSongInCourse do
                local te = steps:GetTrailEntry(i-1)
                local songincourse = te:GetSong()
                local stepsincourse = te:GetSteps()
                table.insert(allitems[pn], {songincourse, stepsincourse})
            end
        end
    end

    local dplist = {}
    local dplist_itg = {}
    local rt = {}
    local wfus, itgus
    if iscourse then
        wfus = {}
        itgus = {}
    end

    -- machine stats arrays
    local mstats = {}
    local mr = {}
    local itgmr = {}

    for player in ivalues(players) do
        local pn = tonumber(player:sub(-1))
        local statsobj = (not iscourse) and WF.CurrentSongStatsObject[pn] or WF.CurrentCourseStatsObjects[pn][1]

        if iscourse then
            wfus[pn] = {}
            itgus[pn] = {}
        end

        -- quick hack to fail for itg/zero the lifebars if skipped
        if statsobj:GetSkipped() then
            WF.ITGFailed[pn] = true
            -- this feels shaky but as it is now, itg judgments and score are consolidated before this function
            -- is called. so we can probably get away with inserting a nil judgment...
            -- just gonna mark a [TODO] here because it feels fucky lol
            local itgdata = (not iscourse) and WF.ITGJudgmentData[pn]
                or WF.ITGJudgmentData[pn][WF.CurrentSongInCourse]
            local ts = itgdata[#itgdata] and (itgdata[#itgdata][3] + 0.02) or 0.1
            table.insert(itgdata, {nil, 0, ts})
            -- now just insert into wf lifebar tables
            for i = 1, #WF.LifeBarNames do 
                if WF.LifeBarChanges[pn][i] then
                    -- reuse ts here because itg tracks life at every judgment rather than just changes
                    -- what the fuck am i doing lol
                    -- [TODO] - this causes a funny bug when itg fails early and then the song is skipped
                    local barchanges = (not iscourse) and WF.LifeBarChanges[pn][i]
                        or WF.LifeBarChanges[pn][i][WF.CurrentSongInCourse]
                    table.insert(barchanges, {0, ts})
                end
            end
        end

        local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
        local steps = (not iscourse) and GAMESTATE:GetCurrentSteps(player) or GAMESTATE:GetCurrentTrail(player)
        local dp = math.floor(statsobj:GetPercentDP() * 10000)
        local itgdp = tonumber(WF.ITGScore[pn]) * 100
        if not dplist[pn] then dplist[pn] = {} end
        if not dplist_itg[pn] then dplist_itg[pn] = {} end
        local itgclr = (not WF.ITGFailed[pn]) and "C" or "F"
        rt[pn] = {}

        -- update hash cache if for some reason it was out of sync (since the hash is always regenerated at eval)
        local stepsid = WF.GetItemID(song, steps)
        if (hashes) and WF.HashCache[stepsid] ~= hashes[pn] then WF.HashCache[stepsid] = hashes[pn] end

        -- First update player profile, but only need to if it's not a guest
        if WF.PlayerProfileStats[pn] then
            -- Before we actually get song stats, update general player totals.
            local hash = (hashes) and hashes[pn] or nil
            local stats = WF.PlayerProfileStats[pn]
            if not iscourse then
                stats.SongsPlayed = stats.SongsPlayed + 1
            else
                stats.CoursesPlayed = stats.CoursesPlayed + 1
                stats.SongsPlayed = stats.SongsPlayed + WF.CurrentSongInCourse
            end
            for i = 1, 5 do
                stats.TotalTapJudgments[i] = stats.TotalTapJudgments[i] + pss:GetTapNoteScores("TapNoteScore_W"..i)
            end
            stats.TotalTapJudgments[6] = stats.TotalTapJudgments[6] + pss:GetTapNoteScores("TapNoteScore_Miss")
            local ra = pss:GetRadarActual()
            local rv = pss:GetRadarPossible()
            stats.TotalHolds[1] = stats.TotalHolds[1] + ra:GetValue("Holds")
            stats.TotalHolds[2] = stats.TotalHolds[2] + rv:GetValue("Holds")
            stats.TotalHolds[3] = stats.TotalHolds[3] + ra:GetValue("Rolls")
            stats.TotalHolds[4] = stats.TotalHolds[4] + rv:GetValue("Rolls")
            stats.TotalMines[1] = stats.TotalMines[1] + pss:GetTapNoteScores("TapNoteScore_HitMine")
            stats.TotalMines[2] = stats.TotalMines[2] + rv:GetValue("Mines")
            if not iscourse then
                stats.LastSongPlayed = song:GetSongDir():gsub("/AdditionalSongs/","",1):gsub("/Songs/","",1):sub(1,-2)
            end

            -- loop through all potential "item stats"
            for cind, item in ipairs(allitems[pn]) do
                local curstatsobj = statsobj
                local cursong = item[1]
                local cursteps = item[2]
                local currv = pss:GetRadarActual()
                if cind > 1 then
                    currv = cursteps:GetRadarValues(player)
                end
                if iscourse then curstatsobj = WF.CurrentCourseStatsObjects[pn][cind] end
                local curdp = dp
                local curitgdp = itgdp
                local curitgclr = itgclr
                local curfaplus = WF.FAPlusCount[pn]
                if cind > 1 then
                    local jt = {curstatsobj:GetJudgmentCount("W1"),curstatsobj:GetJudgmentCount("W2"),
                    curstatsobj:GetJudgmentCount("W3"),curstatsobj:GetJudgmentCount("W4"),
                    curstatsobj:GetJudgmentCount("W5"),curstatsobj:GetJudgmentCount("Miss"),
                    curstatsobj:GetJudgmentCount("Held"),curstatsobj:GetJudgmentCount("LetGo"),
                    curstatsobj:GetJudgmentCount("HitMine")}
                    curdp = math.floor(WF.CalculatePercentDP(jt, cursteps, player, false) * 10000)
                    curitgdp = math.floor(WF.CalculatePercentDP(WF.ITGJudgmentCountsPerSongInCourse[pn][cind-1],
                        cursteps, player, true) * 10000)
                    curfaplus = WF.FAPlusCountPerSongInCourse[pn][cind-1]
                    if WF.ITGFailed[pn] then
                        if cind-1 < WF.ITGSongInCourseAtFail[pn] then curitgclr = "C"
                        elseif cind-1 == WF.ITGSongInCourseAtFail[pn] then curitgclr = "F"
                        else curitgclr = nil end
                    end
                end
                table.insert(dplist[pn], curdp)
                table.insert(dplist_itg[pn], curitgdp)


                -- Find stats if exists, otherwise create one.
                local songstats = WF.FindProfileSongStatsFromSteps(cursong, cursteps, rate, hash, pn)
                if not songstats then
                    songstats = WF.AddPlayerProfileSongStatsFromSteps(cursong, cursteps, rate, hash, pn)
                    -- tentatively bump up counts for newly created clear type/grade; they get adjusted below
                    stats.ClearTypeCounts[WF.ClearTypes.Fail] = stats.ClearTypeCounts[WF.ClearTypes.Fail] + 1
                    stats.GradeCounts[7] = stats.GradeCounts[7] + 1
                else
                    -- just update attributes
                    WF.SongStatsUpdateChartAttributes(songstats, cursong, cursteps, hash, pn)
                end

                -- add copy of song stats to return table
                if not iscourse then
                    rt[pn].PlayerSongStats_Old = WF.CopySongStats(songstats)
                else
                    if cind == 1 then
                        rt[pn].PlayerCourseStats_Old = WF.CopyCourseStats(songstats)
                        rt[pn].PlayerCourseSongStats_Old = {}
                    else
                        table.insert(rt[pn].PlayerCourseSongStats_Old, WF.CopySongStats(songstats))
                    end
                end

                -- Update bests, etc
                songstats.PlayCount = songstats.PlayCount + 1

                local oldct = songstats.BestClearType
                local newct = curstatsobj:GetClearType()
                if newct < oldct then
                    -- update counts, then reassign
                    stats.ClearTypeCounts[oldct] = stats.ClearTypeCounts[oldct] - 1
                    stats.ClearTypeCounts[newct] = stats.ClearTypeCounts[newct] + 1
                    if newct < WF.ClearTypes.Fail then
                        stats.SessionAchievements[newct] = stats.SessionAchievements[newct] + 1
                    end
                    songstats.BestClearType = curstatsobj:GetClearType()
                end

                -- update itg grade count (depends on pass or fail, so can't just use dp increase condition)
                local oldgrade_itg = CalculateGradeITG(songstats)
                if curitgdp > songstats.BestPercentDP_ITG then songstats.BestPercentDP_ITG = curitgdp end
                if (curitgclr) and ((not songstats.Cleared_ITG) or (songstats.Cleared_ITG == "F")) then
                    songstats.Cleared_ITG = curitgclr
                end
                local newgrade_itg = CalculateGradeITG(songstats)
                if newgrade_itg < oldgrade_itg then
                    if oldgrade_itg ~= 99 then stats.GradeCounts_ITG[oldgrade_itg] =
                        stats.GradeCounts_ITG[oldgrade_itg] - 1 end
                    stats.GradeCounts_ITG[newgrade_itg] = stats.GradeCounts_ITG[newgrade_itg] + 1
                end
                for i = 1, 2 do
                    if curfaplus[i] > songstats.BestFAPlusCounts[i] then
                        songstats.BestFAPlusCounts[i] = curfaplus[i]
                    end
                end
                if curstatsobj:GetJudgmentCount("TapNoteScore_W1") > songstats.BestFAPlusCounts[3] then
                    songstats.BestFAPlusCounts[3] = curstatsobj:GetJudgmentCount("TapNoteScore_W1")
                end

                -- Update items in "best play" if percent score is a PB
                if curdp >= songstats.BestPercentDP then
                    -- update grade counts if needed
                    local oldgrade = CalculateGrade(songstats.BestPercentDP)
                    local newgrade = CalculateGrade(curdp)
                    if oldgrade ~= newgrade then
                        stats.GradeCounts[oldgrade] = stats.GradeCounts[oldgrade] - 1
                        stats.GradeCounts[newgrade] = stats.GradeCounts[newgrade] + 1
                    end

                    songstats.BestPercentDP = curdp
                    songstats.BestPlay.DateObtained = dateobtained
                    for i = 1, 5 do
                        songstats.BestPlay.Judgments[i] = curstatsobj:GetJudgmentCount("TapNoteScore_W"..i)
                    end
                    songstats.BestPlay.Judgments[6] = curstatsobj:GetJudgmentCount("TapNoteScore_Miss")
                    songstats.BestPlay.Judgments[7] = (cind == 1) and currv:GetValue("Holds")
                        or curstatsobj:GetJudgmentCount("Held")
                    songstats.BestPlay.Judgments[8] = (cind == 1) and currv:GetValue("Rolls") or 0
                    songstats.BestPlay.Judgments[9] = curstatsobj:GetJudgmentCount("TapNoteScore_HitMine")
                    songstats.BestPlay.FAPlus[1] = curfaplus[1]
                    songstats.BestPlay.FAPlus[2] = curfaplus[2]
                    for i = 1, 3 do
                        songstats.BestPlay.LifeBarVals[i] = curstatsobj.LifeBarVals[i]
                    end
                    for i = 1, 3 do
                        local bar = WF.LifeBarValues[pn][i]
                        local saf = (bar.ScoreAtFail ~= -1) and bar.ScoreAtFail or curdp
                        if cind > 1 then
                            saf = (not (bar.Failed and bar.SongInCourseAtFail == cind - 1)) 
                                and bar.ScoreAtFailSongInCourse or curdp
                        end
                        songstats.BestPlay.ScoreAtLifeEmpty[i] = saf
                    end
                    songstats.BestPlay.SignificantMods = GetSignificantMods(player)

                    -- write detailed stats file, or add course song index to upscore list
                    if not iscourse then
                        WF.WriteDetailedHighScoreStats(pn, songstats)
                    else
                        table.insert(wfus[pn], cind-1)
                    end
                end

                -- write detailed stats for itg if pb for itg
                -- eventually we want to separately check if there is one of these per game mode so that real time
                -- score comparison works
                if curitgdp >= songstats.BestPercentDP_ITG then
                    if not iscourse then
                        WF.WriteDetailedHighScoreStats(pn, nil, "_ITG")
                    else
                        table.insert(itgus[pn], cind-1)
                    end
                end

                -- add to return table
                if not iscourse then
                    rt[pn].PlayerSongStats = songstats
                else
                    if cind == 1 then
                        rt[pn].PlayerCourseStats = songstats
                        rt[pn].PlayerCourseSongStats = {}
                    else
                        table.insert(rt[pn].PlayerCourseSongStats, songstats)
                    end
                end
            end

            -- add course upscore tables to return table
            if iscourse then
                rt[pn].UpscoreSongIndList = wfus[pn]
                rt[pn].UpscoreSongIndList_ITG = itgus[pn]
            end

            -- recalculate folder lamp/grade
            if not iscourse then
                local stepstype = ToEnumShortString(steps:GetStepsType())
                local groupname = song:GetGroupName()
                local difficulty = steps:GetDifficulty()
                WF.CalculateClearsAndGrades(stepstype, groupname, difficulty, rate, pn)
            end
        else
            -- there is surely a logically better way to organize this, but i don't have the time right now lol
            -- we still need to add guest profile stuff like % dp etc for the purpose of machine records
            for cind, item in ipairs(allitems[pn]) do
                local curstatsobj = statsobj
                local cursong = item[1]
                local cursteps = item[2]
                local currv = pss:GetRadarActual()
                if cind > 1 then
                    currv = cursteps:GetRadarValues(player)
                end
                if iscourse then curstatsobj = WF.CurrentCourseStatsObjects[pn][cind] end
                local curdp = dp
                local curitgdp = itgdp
                local curitgclr = itgclr
                local curfaplus = WF.FAPlusCount[pn]
                if cind > 1 then
                    local jt = {curstatsobj:GetJudgmentCount("W1"),curstatsobj:GetJudgmentCount("W2"),
                    curstatsobj:GetJudgmentCount("W3"),curstatsobj:GetJudgmentCount("W4"),
                    curstatsobj:GetJudgmentCount("W5"),curstatsobj:GetJudgmentCount("Miss"),
                    curstatsobj:GetJudgmentCount("Held"),curstatsobj:GetJudgmentCount("LetGo"),
                    curstatsobj:GetJudgmentCount("HitMine")}
                    curdp = math.floor(WF.CalculatePercentDP(jt, cursteps, player, false) * 10000)
                    curitgdp = math.floor(WF.CalculatePercentDP(WF.ITGJudgmentCountsPerSongInCourse[pn][cind-1],
                        cursteps, player, true) * 10000)
                    curfaplus = WF.FAPlusCountPerSongInCourse[pn][cind-1]
                    if WF.ITGFailed[pn] then
                        if cind-1 < WF.ITGSongInCourseAtFail[pn] then curitgclr = "C"
                        elseif cind-1 == WF.ITGSongInCourseAtFail[pn] then curitgclr = "F"
                        else curitgclr = nil end
                    end
                end
                table.insert(dplist[pn], curdp)
                table.insert(dplist_itg[pn], curitgdp)
            end
        end

        -- Next update machine profile stats
        -- find machine stats if available, update attributes, increment play count
        for cind, item in ipairs(allitems[pn]) do
            local cursong = item[1]
            local cursteps = item[2]
            local curmstats = WF.FindProfileSongStatsFromSteps(cursong, cursteps, rate, hash)
            if not curmstats then
                curmstats = WF.AddMachineProfileSongStatsFromSteps(cursong, cursteps, rate, hash, player)
            else
                WF.SongStatsUpdateChartAttributes(curmstats, cursong, cursteps, hash)
            end
            if not mstats[pn] then mstats[pn] = {} end
            table.insert(mstats[pn], curmstats)
            if (mstats[1] and mstats[2]) and (not (mstats[1][cind] == mstats[2][cind])) then
                -- mstats 1 and 2 will only ever be the same on the second iteration
                -- so this essentially checks if the same chart was played and play count has already incremented
                curmstats.PlayCount = curmstats.PlayCount + 1
            end
        

            -- insert into high score list
            local profile = PROFILEMAN:GetProfile(player)
            local isguest = (not WF.PlayerProfileStats[pn])
            if not mr[pn] then mr[pn] = {} end
            local curmr = WF.NewMachineRecordItem()
            curmr.PlayerFullName = (not isguest) and profile:GetDisplayName() or "Guest"
            curmr.PlayerHSName = (not isguest) and profile:GetLastUsedHighScoreName() or "????"
            curmr.PlayerGuid = (not isguest) and profile:GetGUID() or "None"
            curmr.DateObtained = dateobtained
            curmr.PercentDP = dplist[pn][cind]
            curmstats.HighScoreList[#curmstats.HighScoreList+1] = curmr
            table.insert(mr[pn], curmr)

            -- insert into itg high score list
            if not itgmr[pn] then itgmr[pn] = {} end
            local curitgmr = WF.NewMachineRecordItem()
            curitgmr.PlayerFullName = (not isguest) and profile:GetDisplayName() or "C. Foy"
            curitgmr.PlayerHSName = (not isguest) and profile:GetLastUsedHighScoreName() or "CFOY"
            curitgmr.PlayerGuid = (not isguest) and profile:GetGUID() or ""
            curitgmr.DateObtained = dateobtained
            curitgmr.PercentDP = dplist_itg[pn][cind]
            curmstats.HighScoreList_ITG[#curmstats.HighScoreList_ITG+1] = curitgmr
            table.insert(itgmr[pn], curitgmr)

            if not iscourse then
                rt[pn].MachineSongStats = curmstats
            else
                if cind == 1 then
                    rt[pn].MachineCourseStats = curmstats
                    rt[pn].MachineCourseSongStats = {}
                else
                    table.insert(rt[pn].MachineCourseSongStats, curmstats)
                end
            end
        end
    end

    -- need to get machine record index after both potential scores have been inserted
    for player in ivalues(players) do
        local pn = tonumber(player:sub(-1))
        -- we actually can't just FindInTable here, due to the way the metatable handles equality for
        -- machine records (if both players get the same score at the same time, they'll be considered "equal").
        -- fuckin whoops
        for cind, item in ipairs(allitems[pn]) do
            if iscourse and (cind == 1) then
                rt[pn].MachineCourseSongHSInd = {}
                rt[pn].MachineCourseSongHSInd_ITG = {}
            end
            for i, score in ipairs(mstats[pn][cind].HighScoreList) do
                local found = true
                for k, v in pairs(score) do if mr[pn][cind][k] ~= v then found = false end end
                if found then
                    if cind == 1 then rt[pn].MachineHSInd = i
                    else rt[pn].MachineCourseSongHSInd[cind-1] = i end
                    break
                end
            end
            for i, score in ipairs(mstats[pn][cind].HighScoreList_ITG) do
                local found = true
                for k, v in pairs(score) do if itgmr[pn][cind][k] ~= v then found = false end end
                if found then
                    if cind == 1 then rt[pn].MachineHSInd_ITG = i
                    else rt[pn].MachineCourseSongHSInd_ITG[cind-1] = i end
                    break
                end
            end
        end
    end
    
    return rt
end

WF.CopySongStats = function(hs)
    -- this is used to get a copy of the current ("old") high score item on evaluation so that we can make comparisons
    -- to determine what was improved
    local t = {}
    for k, v in pairs(hs) do
        if k ~= "BestFAPlusCounts" and k ~= "BestPlay" then
            t[k] = v
        elseif k == "BestFAPlusCounts" then
            t[k] = {}
            for i = 1,3 do t[k][i] = v[i] end
        end
    end
    return t
end

WF.CopyCourseStats = WF.CopySongStats

WF.ImportCheck = function()
    -- just check if there is anything to merge.
    -- with the new system the UI probably doesn't need to report anything super specific
    if ThemePrefs.Get("AlwaysMergeScores") then return true end
    local mdir = PROFILEMAN:GetProfileDir("ProfileSlot_Machine")
    if not FILEMAN:DoesFileExist(mdir.."/MachineStats.wfm") then return true end
    if WF.MachineProfileStats and WF.MachineProfileStats.ForceImportCourses then
        return true
    end
    local players = GAMESTATE:GetHumanPlayers()
    for player in ivalues(players) do
        local pn = player:sub(-1)
        local dir = PROFILEMAN:GetProfileDir("ProfileSlot_Player"..pn)
        if (dir ~= "") and (not FILEMAN:DoesFileExist(dir.."/PlayerStats.wfs")) then
            return true
        end
        if WF.PlayerProfileStats[pn] and WF.PlayerProfileStats[pn].ForceImportCourses then
            return true
        end
    end
    return false
end

WF.MergeProfileStats = function()
    -- This will check, for both player profiles and machine profile, if the WF stats files exist.
    -- If they don't, run through some logic to import stats and scores from Exp-Stats.xml (Standard scores),
    -- Stats.xml (ITG scores), and ECFA-Stats.xml (ITG scores, with tier 2 FA+ counts).
    -- Call this in OffConand on the select play mode screen.

    -- There is also now a ThemePref that will force this merge always; this is more affordable to do now
    -- with the addition of a maintained hash cache #HashCash
    
    -- check which we should import first, so that we can minimize the amount of SetStatsPrefix jawns
    local mdir = PROFILEMAN:GetProfileDir("ProfileSlot_Machine")
    local alwaysmerge = ThemePrefs.Get("AlwaysMergeScores")
    local importmachine = alwaysmerge or (not FILEMAN:DoesFileExist(mdir.."/MachineStats.wfm"))
    if (not importmachine) and WF.MachineProfileStats and WF.MachineProfileStats.ForceImportCourses then
        importmachine = true
    end
    local importsongsmachine = importmachine
    if (importmachine) and (WF.MachineProfileStats.ForceImportCourses) and (not alwaysmerge)
        and FILEMAN:DoesFileExist(mdir.."/MachineStats.wfm") then
        importsongsmachine = false
    end

    local players = GAMESTATE:GetHumanPlayers()
    local importplayers = {}
    local importsongsplayer = {true,true}
    for player in ivalues(players) do
        local pn = tonumber(player:sub(-1))
        local dir = PROFILEMAN:GetProfileDir("ProfileSlot_Player"..pn)
        if alwaysmerge or ((dir ~= "") and (not FILEMAN:DoesFileExist(dir.."/PlayerStats.wfs")))
        or (WF.PlayerProfileStats[pn] and WF.PlayerProfileStats[pn].ForceImportCourses) then
            table.insert(importplayers, player)
            if (not alwaysmerge) and FILEMAN:DoesFileExist(dir.."/PlayerStats.wfs")
            and WF.PlayerProfileStats[pn].ForceImportCourses then
                importsongsplayer[pn] = false
            end
        end
    end
    if (not importmachine) and (#importplayers == 0) then return true end

    local function Import(prefix)
        PROFILEMAN:SetStatsPrefix(prefix)
        if importmachine then
            WF.ImportProfileStats(importsongsmachine, true)
        end
        for player in ivalues(importplayers) do
            local pn = tonumber(player:sub(-1))
            WF.ImportProfileStats(importsongsplayer[pn], true, pn)
        end
    end

    -- import "Exp-" (standard) stats and scores
    Import("Exp-")

    -- import no prefix (ITG, no FA+) stats
    Import("")

    -- import "ECFA-" (ITG, with FA+) stats
    Import("ECFA-")

    -- set stats prefix back to WF, so as not to mess with anything else
    PROFILEMAN:SetStatsPrefix("WF-")

    -- finally, preload grades/cts here if "always merge" is on, which defers it to here
    if ThemePrefs.Get("PreloadGrades") and ThemePrefs.Get("AlwaysMergeScores") then
        for player in ivalues(players) do
            WF.PreloadClearsAndGrades(tonumber(player:sub(-1)))
        end
    end

    return true
end

WF.ImportProfileStats = function(importsongs, importcourses, pn)
    -- actual function that does the importing stuff
    -- pn nil for machine
    local stats = (not pn) and WF.MachineProfileStats or WF.PlayerProfileStats[pn]
    if not stats then return end
    local profile = (not pn) and PROFILEMAN:GetMachineProfile() or PROFILEMAN:GetProfile("PlayerNumber_P"..pn)
    if not profile then return end

    local curprefix = PROFILEMAN:GetStatsPrefix()
    local scoretype = {["Exp-"] = "standard", [""] = "ITG", ["ECFA-"] = "ITG (FA+)"}

    -- status message traced to log
    local name = (not pn) and "Machine" or profile:GetDisplayName()
    local statusbase = "Importing scores for profile: "..name
    local status = statusbase
    Trace(status)

    -- update songs played for player
    -- note for updating any profile fields that aren't scores: we can't trust that these are tracked separately
    -- across different stats.xml files due to the prefix bug, so all we can do is take the value if it's higher
    -- than what's already there, as opposed to trying to total them all together
    if pn then
        stats.SongsPlayed = math.max(stats.SongsPlayed, profile:GetNumTotalSongsPlayed())
    end

    local allitems = {}
    if importsongs then
        for song in ivalues(SONGMAN:GetAllSongs()) do table.insert(allitems, song) end
    end
    local lastsongind = #allitems
    if importcourses then
        for course in ivalues(SONGMAN:GetAllCourses(false)) do table.insert(allitems, course) end
    end

    for songind, song in ipairs(allitems) do
        local iscourse = (songind > lastsongind)
        local allsteps = (not iscourse) and song:GetAllSteps() or song:GetAllTrails()
        for steps in ivalues(allsteps) do
            -- check for high scores
            local hsl = profile:GetHighScoreListIfExists(song, steps)
            if hsl then
                local scores = hsl:GetHighScores()
                local stepsid = WF.GetItemID(song, steps)
                status = statusbase.."\nScores found for chart/course: "..stepsid
                Trace(status)
                local bestplayset = {} -- used below
                
                for scoreind, score in ipairs(scores) do
                    -- first check if song stats already exists, and create it if not.
                    -- need to get the songstats each iteration, because rate might be different (ugh)
                    local rate = GetRateFromModString(score:GetModifiers())
                    local songstats = WF.FindProfileSongStatsFromSteps(song, steps, rate, nil, pn)
                    if not songstats then
                        songstats = (not pn) and WF.AddMachineProfileSongStatsFromSteps(song, steps, rate) or
                            WF.AddPlayerProfileSongStatsFromSteps(song, steps, rate, nil, pn)
                    end

                    if not pn then
                        -- if machine, all we need to do is insert the scores into the list
                        -- we'll check if a score with the same dp already exists, so that we don't keep inserting
                        -- the same scores if you have "always import" on
                        local list = (curprefix == "Exp-") and songstats.HighScoreList or songstats.HighScoreList_ITG
                        local dp = math.round(score:GetPercentDP() * 10000)
                        local smatch = false
                        for tscore in ivalues(list) do if tscore.PercentDP == dp then smatch = true break end end
                        if not smatch then
                            local hs = WF.NewMachineRecordItem()
                            hs.PlayerFullName = score:GetName()
                            hs.PlayerHSName = score:GetName()
                            hs.PlayerGuid = "Unknown"
                            hs.DateObtained = tostring(score:GetDate())
                            hs.PercentDP = dp
                            list[#list+1] = hs
                        end
                    else
                        -- for player, we need to get all the personal best stuff we can detect.
                        if curprefix == "" or curprefix == "ECFA-" then
                            -- if itg, all we care about is the high dp score and pass/fail. for fa+, we can also add W1
                            -- judgments to total W1 judgments, as well as record tier 3 FA+ counts from those.
                            -- NOTE: club fantastic theme sets prefix to ECFA- but redefines fa+ as 15ms. because of
                            -- this, we can't guarantee these will be 12.5ms counts anymore. so don't count those.
                            -- pass/fail
                            if score:GetGrade() ~= "Grade_Failed" then songstats.Cleared_ITG = "C"
                            elseif songstats.Cleared_ITG ~= "C" then songstats.Cleared_ITG = "F" end

                            -- best dp for itg
                            local newscore = (math.round(score:GetPercentDP() * 10000) > songstats.BestPercentDP_ITG)
                            songstats.BestPercentDP_ITG = math.max(songstats.BestPercentDP_ITG,
                                math.round(score:GetPercentDP() * 10000))

                            -- fa+ specific stuff
                            if curprefix == "ECFA-" then
                                local faplus = score:GetTapNoteScore("TapNoteScore_W1")
                                songstats.BestFAPlusCounts[3] = math.max(songstats.BestFAPlusCounts[3], faplus)
                                if newscore then
                                    stats.TotalTapJudgments[1] = stats.TotalTapJudgments[1] + faplus
                                     -- we can detect a "mastery" if score is 100% and there are no W2 judgments
                                    if score:GetPercentDP() == 1 and score:GetTapNoteScore("TapNoteScore_W2") == 0 then
                                        songstats.BestClearType = 1
                                        songstats.BestPercentDP = 10000
                                    end
                                end
                            end

                            if newscore then
                                -- mines/play count update need to happen in each of these conditions now, because it's
                                -- dependent on whether it's a new score
                                local radar = score:GetRadarValues()
                                stats.TotalMines[1] = stats.TotalMines[1] + score:GetTapNoteScore("TapNoteScore_HitMine")
                                stats.TotalMines[2] = stats.TotalMines[2] + radar:GetValue("RadarCategory_Mines")

                                -- update play count
                                songstats.PlayCount = songstats.PlayCount + 1
                            end
                        elseif curprefix == "Exp-" then
                            -- with exp, we can fill most things out since it mirrors the base metrics here.
                            -- particularly, we can fill out "BestPlay" even though it's possible that the actual
                            -- best play was on itg. but in that case, we'd have no way of knowing what any stats
                            -- are for it, so the most we can do is record it for exp.
                            -- let's make use of this old statsobj thing, wow
                            local statsobj = WF.BuildStatsObj(score)
                            local ct = statsobj:GetClearType()
                            songstats.BestClearType = math.min(songstats.BestClearType, ct)
                            local dp = math.round(statsobj:GetPercentDP() * 10000)
                            local newscore = (dp > songstats.BestPercentDP)
                            songstats.BestPercentDP = math.max(songstats.BestPercentDP, dp)
                            local faplus = statsobj:GetJudgmentCount("W1")
                            songstats.BestFAPlusCounts[3] = math.max(songstats.BestFAPlusCounts[3], faplus)

                            -- tally up totals if new score
                            if newscore then
                                for i = 1, 5 do
                                    stats.TotalTapJudgments[i] = stats.TotalTapJudgments[i]
                                        + statsobj:GetJudgmentCount("W"..i)
                                end
                                stats.TotalTapJudgments[6] = stats.TotalTapJudgments[6] + statsobj:GetJudgmentCount("Miss")

                                -- there is no way to reliably differentiate holds from rolls in terms of performance vs
                                -- total, so we'll just ignore those. but we can at least tally mines.
                                local radar = score:GetRadarValues()
                                stats.TotalMines[1] = stats.TotalMines[1] + score:GetTapNoteScore("TapNoteScore_HitMine")
                                stats.TotalMines[2] = stats.TotalMines[2] + radar:GetValue("RadarCategory_Mines")

                                -- update play count
                                songstats.PlayCount = songstats.PlayCount + 1
                            end

                            -- some kind of convoluted logic for best play with rates
                            if not bestplayset[rate] then
                                local bp = songstats.BestPlay
                                bp.DateObtained = tostring(score:GetDate())
                                for i = 1,5 do bp.Judgments[i] = statsobj:GetJudgmentCount("W"..i) end
                                bp.Judgments[6] = statsobj:GetJudgmentCount("Miss")
                                -- just combine holds held and rolls held into holds held
                                bp.Judgments[7] = statsobj:GetJudgmentCount("Held")
                                bp.Judgments[9] = statsobj:GetJudgmentCount("HitMine")
                                -- lifebar values are impossible to get, but we can set arbitrary ones for
                                -- easy/normal based on pass/fail
                                local failed = statsobj:GetFail()
                                bp.LifeBarVals[3] = 0
                                bp.LifeBarVals[1] = (not failed) and 1000 or 0
                                bp.LifeBarVals[2] = (not failed) and 800 or 0
                                for i = 1,3 do bp.ScoreAtLifeEmpty[i] = dp end
                                -- won't bother with significant mods for this
                                bestplayset[rate] = true
                            end
                        end
                    end
                end
            end
        end
    end

    status = statusbase.."\nDone"
    Trace(status)

    -- save stats before next load (upon changing the prefix)
    if not pn then WF.SaveMachineProfileStats()
    else WF.SavePlayerProfileStats(pn) end
end

-- get the actorframe to pass into ProfileCard
WF.ProfileCardLowerAF = function(pn, items)
    -- items can be passed in, otherwise will come from ThemePrefs for the profile.
    -- options are "SongsPlayed", "FCTiers", "FCTiersNoPerfect", "LifeBarClears", "TopGradesITG"
    if not items then items = SL["P"..pn].ActiveModifiers.ProfileCardInfo end
    if not items then items = "SongsPlayed" end

    local af = Def.ActorFrame{}
    local iscourse = GAMESTATE:IsCourseMode()

    if items == "SongsPlayed" then
        af[#af+1] = LoadFont("Common Normal")..{
            Text = "Current Session:",
            InitCommand = function(self) self:y(4):zoom(0.8) end
        }
        af[#af+1] = LoadFont("Common Normal")..{
            Text = string.format("%d %s%s", WF.CurrentSessionSongsPlayed[pn], (not iscourse) and "song" or "course",
                (WF.CurrentSessionSongsPlayed[pn] > 1) and "s" or ""),
            InitCommand = function(self) self:zoom(0.8):y(20) end
        }
    elseif items == "FCTiers" or items == "FCTiersNoPerfect" or items == "LifeBarClears" then
        local cto = {FCTiers = 0, FCTiersNoPerfect = 1, LifeBarClears = 4}
        local p = (not iscourse) and "" or "Course"
        for i = 1, 3 do
            local cti = i + cto[items]
            af[#af+1] = LoadFont("Common Normal")..{
                Text = WF.ClearTypesShort[cti],
                InitCommand = function(self) self:zoom(0.8):diffuse(WF.ClearTypeColor(cti)):xy(-20, 14*(i-1)) end
            }
            af[#af+1] = LoadFont("Common Normal")..{
                Text = tostring(WF.PlayerProfileStats[pn][p.."ClearTypeCounts"][cti]),
                InitCommand = function(self) self:zoom(0.8):xy(36, 14*(i-1)):horizalign("right"):maxwidth(36/0.8) end
            }
        end
    elseif items == "TopGradesITG" then
        local positions = {{-34, 2}, {12, 2}, {-34, 24}, {12, 24}}
        local p = (not iscourse) and "" or "Course"
        for i = 1, 4 do
            af[#af+1] = LoadActor(THEME:GetPathG("", "_GradesSmall/LetterGrade.lua"), {grade = i, itg = true})..{
                OnCommand = function(self) self:zoom(0.2):xy(positions[i][1], positions[i][2]) end
            }
            af[#af+1] = LoadFont("Common Normal")..{
                Text = tostring(WF.PlayerProfileStats[pn][p.."GradeCounts_ITG"][i]),
                InitCommand = function(self) self:zoom(0.75):xy(positions[i][1] + 32, positions[i][2]+1)
                    :maxwidth(20/0.75):horizalign("right") end
            }
        end
    elseif items == "ECFA2021" then
        -- unused now
        local points = tostring(math.floor(WF.PlayerProfileStats[pn].ECFA2021ScoreList.TotalPoints))
        local songs = tostring(WF.PlayerProfileStats[pn].ECFA2021ScoreList.Songs)
        af[#af+1] = LoadFont("Common Normal")..{
            Text = "ECFA Total",
            InitCommand = function(self) self:zoom(0.8) end
        }
        af[#af+1] = LoadFont("Common Normal")..{
            Text = points,
            InitCommand = function(self) self:zoom(0.8):y(14):maxwidth(92/0.8) end
        }
        af[#af+1] = LoadFont("Common Normal")..{
            Text = "Songs Played:",
            InitCommand = function(self) self:zoom(0.7):xy(-44, 29):horizalign("left") end
        }
        af[#af+1] = LoadFont("Common Normal")..{
            Text = songs,
            InitCommand = function(self) self:zoom(0.7):xy(44, 29):horizalign("right") end
        }
    end

    return af
end

-- test hash cache weird shit lol LOL
function TestHashes()
    HashTest = {}
    WF.LoadHashCache(THEME:GetPathO("", "HashTest_SM"), HashTest)

    local wrong = 0
    local nochart = 0
    for id, v in pairs(HashTest) do
        if id ~= "WFVersion" then
            if WF.HashCache[id] == v then
                Trace("Hashes match for ID: "..id)
                Trace(v or "[NO HASH]")
                Trace(WF.HashCache[id] or "[NO HASH]")
            else
                if WF.HashCache[id] then
                    wrong = wrong + 1
                    Trace("Hashes do not match for ID: "..id)
                    Trace(v or "[NO HASH]")
                    Trace(WF.HashCache[id] or "[NO HASH]")
                else
                    nochart = nochart + 1
                    Trace("No chart or hash for ID: "..id)
                end
            end
        end
    end
    Trace("Hash test complete. "..wrong.." incorrect hashes, "..nochart.." empty hashes.")
end


-- The following is a really dumb hacky idea, entirely to try to maintain "Last song played."
-- Firstly, we'll have a flag that signals to the theme to not do any of the WF file operations for profiles
-- if it's set while the Load/SaveProfileCustom functions run, because there is no need.
-- We'll set this flag on the Game Over screen, and run a function that switches the stats prefix back to blank,
-- then saves the profiles, and then switches it back. This is really dumb I'm sorry.
-- note: initializing this to true, so that the initial setstatsprefix doesn't load machine stats.
WF.SwitchPrefixFlag = true
WF.DummySave = function(players)
    if not WF.SwitchPrefixFlag then return end
    PROFILEMAN:SetStatsPrefix("")
    for player in ivalues(players) do
        if WF.PlayerProfileStats[tonumber(player:sub(-1))] then
            PROFILEMAN:SaveProfile(player)
        end
    end
    PROFILEMAN:SetStatsPrefix("WF-")
    WF.SwitchPrefixFlag = false
end


-- Hello, past me. It's now post release of version 0.5.0 and we're in dire need of some stored caching for the hashes.
-- People really want those music wheel grades don't they...
WF.HashCacheNextScreen = "ScreenInit"

WF.InitHashCache = function()
    -- Call this on ScreenInit; it will check if the cache is empty, then load from file if it exists.
    -- It will then check for new uncached charts, and signal to generate those.
    WF.NewChartsToCache = {}
    WF.LastSongParsed = nil
    WF.LastMSD = {}
    WF.SongsParsed = 0
    WF.ChartsHashed = 0

    if not WF.HashCache.WFVersion then
        -- preload from file included in theme
        WF.LoadHashCache(THEME:GetPathO("", "HashPreCache"))

        -- load from user's file
        WF.LoadHashCache()
    end

    -- check for new charts
    for song in ivalues(SONGMAN:GetAllSongs()) do
        for steps in ivalues(song:GetAllSteps()) do
            local fn = steps:GetFilename()
            if (fn) and fn ~= "" and (steps:GetStepsType():find("Dance") or steps:GetStepsType():find("Pump")) then
                local id = WF.GetStepsID(song, steps)
                if not WF.HashCache[id] then
                    table.insert(WF.NewChartsToCache, {song, steps})
                end
            end
        end
    end

    if #WF.NewChartsToCache == 0 then
        WF.LastSongParsed = nil
        WF.LastMSD = nil
    end

    -- the function that actually generates the hashes will run in pieces at a time, so that we can update
    -- the status from the UI side. so nothing more to do here.
end

WF.LoadHashCache = function(path, outtbl)
    if not path then path = "/Save/Waterfall/HashCacheV3" end
    if not FILEMAN:DoesFileExist(path) then return end

    -- outtbl can be passed to load a cache into a separate table (this might be useful for testing, or for
    -- some updating scenarios)
    if not outtbl then outtbl = WF.HashCache end

    -- format of cache file is just id\nhash\nid\nhash etc, so pretty simple logic here
    local filetext = File.Read(path)

    if filetext then
        local curid = ""
        local lines = split("\n", filetext)
        local firstline = true
        for line in ivalues(lines) do
            line = line:gsub("[\r\f\n]", "")
            if firstline then
                -- this is the current WF version; handle any changes here
                outtbl.WFVersion = line
                if VersionCompare(line, "0.6.7") == -1 then
                    -- something updated
                    -- hashing changed for new groovestats stuff, so recache if on an earlier version
                    if path == "/Save/Waterfall/HashCache" then
                        SM("\nHashing has been updated. Rebuilding cache.\n")
                    end
                    outtbl.WFVersion = nil
                    return
                end
                firstline = false
            else
                if line:match("/") then curid = line
                elseif curid ~= "" then
                    outtbl[curid] = line
                    curid = ""
                end
            end
        end
        Trace("Hash Cache loaded from file. #HashCash")
    else
        SM("Hash Cache failed to load!! #HashCash")
    end
end

WF.SaveHashCache = function()
    -- write to the file after the full cache has been built
    local path = "/Save/Waterfall/HashCacheV3"

    local ft = { GetThemeVersion() }
    for id, hash in pairs(WF.HashCache) do
        if id ~= "WFVersion" then
            table.insert(ft, id)
            table.insert(ft, hash)
        end
    end

    local fstr = table.concat(ft, "\n")
    if File.Write(path, fstr) then
        Trace("Hash Cache successfully written. #HashCash")
    else
        SM("The Hash Cache failed to write!! #HashCash")
    end
end

WF.GetHashCacheBuildStatus = function(total)
    -- this will return a table of information relating to the status, so that a text can report the progress
    -- if no total is passed in, the number of items in the NewChartsToCache table will be used, and then that
    -- total can be passed back in
    if not total then total = #WF.NewChartsToCache end
    
    local rt = {Step = "Generating hash", ChartID = "", Finished = total - #WF.NewChartsToCache, Total = total}
    if #WF.NewChartsToCache == 0 then
        rt.Step = "Done"
        WF.HashCacheBuildFinish()
        return rt
    end

    local nextitem = WF.NewChartsToCache[1]
    rt.ChartID = WF.GetStepsID(nextitem[1], nextitem[2])

    return rt
end

WF.ProcessHashCacheItem = function()
    -- generate one hash, remove the item from the queue, and return
    if #WF.NewChartsToCache == 0 then return end

    local item = WF.NewChartsToCache[1]
    local id = WF.GetStepsID(item[1], item[2])

    WF.ChartsHashed = WF.ChartsHashed + 1

    if item[1] ~= WF.LastSongParsed then
        WF.LastMSD.MSD, WF.LastMSD.Type = GetSimfileString(item[2])
        WF.LastSongParsed = item[1]
        WF.SongsParsed = WF.SongsParsed + 1
    end

    local hash = ""
    if WF.LastMSD.MSD then
        hash = GetHashFromSimfileString(item[2], WF.LastMSD.MSD, WF.LastMSD.Type) or ""
    end

    WF.HashCache[id] = hash
    table.remove(WF.NewChartsToCache, 1)
end

WF.HashCacheBuildFinish = function()
    WF.SaveHashCache()
    WF.LastSongParsed = nil
    WF.LastMSD = nil
end


-- the following is for caching the folder grades and "lamps" because calculating them every time the song wheel
-- scrolls is causing some lag. i might make this preload completely instead of cache on the fly later.

-- format: WF.ClearTypesAndGrades[pn][stepstype][group][difficulty][rate] = {ITG = n, WF = n}
-- 0 = none, 1-17 = grade or ct, 99 = *

WF.CheckClearsAndGrades = function(stepstype, groupname, difficulty, rate, pn)
    if not WF.PlayerProfileStats[pn] then return end
    if not WF.PlayerProfileStats[pn].GroupClearsAndGrades[stepstype] then return end
    if not WF.PlayerProfileStats[pn].GroupClearsAndGrades[stepstype][groupname] then return end
    if not WF.PlayerProfileStats[pn].GroupClearsAndGrades[stepstype][groupname][difficulty] then return end
    return WF.PlayerProfileStats[pn].GroupClearsAndGrades[stepstype][groupname][difficulty][rate]
end

WF.AddToClearsAndGrades = function(stepstype, groupname, difficulty, rate, pn, ct, itggrade)
    if not WF.PlayerProfileStats[pn] then return end
    if not WF.PlayerProfileStats[pn].GroupClearsAndGrades[stepstype] then
        WF.PlayerProfileStats[pn].GroupClearsAndGrades[stepstype] = {}
    end
    if not WF.PlayerProfileStats[pn].GroupClearsAndGrades[stepstype][groupname] then
        WF.PlayerProfileStats[pn].GroupClearsAndGrades[stepstype][groupname] = {}
    end
    if not WF.PlayerProfileStats[pn].GroupClearsAndGrades[stepstype][groupname][difficulty] then
        WF.PlayerProfileStats[pn].GroupClearsAndGrades[stepstype][groupname][difficulty] = {}
    end
    WF.PlayerProfileStats[pn].GroupClearsAndGrades[stepstype][groupname][difficulty][rate] = {
        WF = ct,
        ITG = itggrade
    }
end

WF.CalculateClearsAndGrades = function(stepstype, groupname, difficulty, rate, pn)
    if not WF.PlayerProfileStats[pn] then return end
    local songs = SONGMAN:GetSongsInGroup(groupname)
    if not songs then return end

    -- i could do all the dumb logic i did for edits in the song item file, but the idea of tracking a
    -- "lamp" for a specific index of edit difficulty within a pack seems dumb and pointless to me
    if difficulty == "Difficulty_Edit" then return {WF = 0, ITG = 0} end

    local arg = {WF = 0, ITG = 0}
    for song in ivalues(songs) do
        local charts = song:GetStepsByStepsType(stepstype)
        if charts then
            for chart in ivalues(charts) do
                if chart:GetDifficulty() == difficulty then
                    local stats = WF.GetMusicWheelSongStats(song, chart, rate, pn)
                    if (stats) then
                        if rate == stats.RateMod then
                            -- some score exists on either mode
                            arg.ITG = math.max(arg.ITG, CalculateGradeITG(stats))
                            arg.WF = math.max(arg.WF, stats.BestClearType)
                        else
                            -- some score exists at another rate but not this one
                            arg.WF = 99
                            arg.ITG = 99
                        end
                    else
                        -- no stats for some song at a valid difficulty, so no lamp
                        WF.AddToClearsAndGrades(stepstype, groupname, difficulty, rate, pn, 0, 0)
                        arg.WF = 0
                        arg.ITG = 0
                        return arg
                    end
                end
            end
        end
    end

    -- if we get here, every chart had a score of some kind. arg.WF = None CT means * for WF
    -- ITG will already have 99 assigned from CalculateGradeITG if any chart was unplayed
    if arg.WF == WF.ClearTypes.None then arg.WF = 99 end
    
    WF.AddToClearsAndGrades(stepstype, groupname, difficulty, rate, pn, arg.WF, arg.ITG)
    return arg
end

WF.PreloadClearsAndGrades = function(pn)
    if not WF.PlayerProfileStats[pn] then return end
    -- this has no use in marathon mode
    if GAMESTATE:IsCourseMode() then return end
    local t = GetTimeSinceStart()
    local cnt = 0
    Trace("Starting ct/grade preload...")

    -- first, get all the rates we need to do this for (i feel like there should be a shortcut here but it's
    -- like 4am and i'm kinda dumb)
    local scores = WF.PlayerProfileStats[pn].SongStats
    local rates = {"1.0"}
    for score in ivalues(scores) do
        if (not FindInTable(score.RateMod, rates)) then table.insert(rates, score.RateMod) end
    end

    local diffs = 
        {"Difficulty_Beginner","Difficulty_Easy","Difficulty_Medium","Difficulty_Hard","Difficulty_Challenge"}
    local types = {"Dance_Single","Dance_Double","Pump_Single","Pump_Double"}
    local groups = SONGMAN:GetSongGroupNames()
    for rate in ivalues(rates) do
        for stype in ivalues(types) do
            for group in ivalues(groups) do
                for diff in ivalues(diffs) do
                    local val = WF.CalculateClearsAndGrades(stype, group, diff, rate, pn)
                    if not (val.WF == 0 and val.ITG == 0) then cnt = cnt + 1 end
                end
            end
        end
    end

    local timetaken = GetTimeSinceStart() - t
    Trace(string.format("Finished preloading %d folder grades.", cnt))
    Trace(string.format("Time taken: %.4f seconds", timetaken))
end


-- Function to pull a score returned from GrooveStats and put it into your ITG score if the one from
-- GS is higher.
-- Since GS doesn't track rates, this will follow a logical hierarchy.
-- First, loop through all stats for the song and find if one exists at any rate that matches the score.
-- If found, assume that is the one submitted to GS and do nothing.
-- Otherwise, check for a score at 1.0x. If not found, create one. Take the max and apply that to ITG score.
-- Also take "max" for pass/fail and use that for Cleared_ITG field.
WF.PullITGScoreFromGrooveStats = function(pn, hash, gsentry, steps)
    -- steps isn't necessary to pass, but if isn't, may have to check current steps for the player
    if not WF.PlayerProfileStats[pn] then return end

    local songstats = WF.PlayerProfileStats[pn].SongStats
    local stats

    local lookup = songstats.Lookup[hash]
    if lookup then
        for rate, ind in pairs(lookup) do
            if songstats[ind].BestPercentDP_ITG == gsentry["score"] then
                -- matching score found; do nothing
                return
            end
        end

        if lookup["1.0"] then stats = songstats[lookup["1.0"]] end
    end

    if not stats then
        -- no stats for 1.0; make a new one
        if not steps then
            steps = GAMESTATE:GetCurrentSteps("PlayerNumber_P"..pn)
        end
        -- don't proceed if certain things don't look right
        if not steps then return end
        local song = SONGMAN:GetSongFromSteps(steps)
        if HashCacheEntry(steps) ~= hash then return end

        stats = WF.AddPlayerProfileSongStatsFromSteps(song, steps, "1.0", hash, pn)
    end

    -- now assign max values accordingly
    stats.BestPercentDP_ITG = math.max(gsentry["score"], stats.BestPercentDP_ITG)
    if not stats.Cleared_ITG then
        stats.Cleared_ITG = (gsentry["isFail"]) and "F" or "C"
    elseif stats.Cleared_ITG ~= "C" and (not gsentry["isFail"]) then
        stats.Cleared_ITG = "C"
    end
end


-- some utilities

function VersionCompare(v1, v2)
    -- -1 if v1 < 2, 1 if v1 > v2, 0 if same
    local v1n = tonumber((v1:gsub("[^0-9]", "")))
    local v2n = tonumber((v2:gsub("[^0-9]", "")))

    if v1n == v2n then return 0 end
    if v1n < v2n then return -1 end
    if v1n > v2n then return 1 end
end

function HashCacheEntry(steps)
    -- quick way to just get the hash for a chart from steps passed rather than manually getting the id
    return WF.HashCache[WF.GetStepsID(SONGMAN:GetSongFromSteps(steps), steps)]
end

-- (the following 2 functions were moved from WF-Scoring.lua)
WF.GetStepsID = function(song, steps)
    -- this is the index for any item in the SongStats table, pertaining to any steps
    local stypeid = steps:GetStepsType():gsub("StepsType_","")
    local songid = song:GetSongDir():gsub("/AdditionalSongs/","",1):gsub("/Songs/","",1):sub(1,-2)
    local diffid = steps:GetDifficulty():gsub("Difficulty_","")
    local ext = diffid == "Edit" and WF.GetEditIndex(song, steps) or ""
    diffid = diffid:sub(1,1)
    --return stypeid.."/"..songid.."/"..diffid..ext
    return table.concat({stypeid,songid,diffid..ext}, "/")
end

WF.GetEditIndex = function(song, steps)
    -- because of the dumbass way edits work, all edit steps have a difficulty of Difficulty_Edit
    -- since we're indexing using the difficulty name, need to find which edit these steps are, and add a number
    local stype = steps:GetStepsType()
    local i = 1
    for v in ivalues(song:GetStepsByStepsType(stype)) do
        if v:GetDifficulty() == "Difficulty_Edit" then
            if v == steps then
                return i
            end
            i = i + 1
        end
    end
end

WF.GetCourseID = function(course, trail)
    local stypeid = ToEnumShortString(trail:GetStepsType())
    local courseid = course:GetCourseDir():gsub("/Courses/", "", 1):sub(1, -5)
    if course:IsAutogen() then courseid = course:GetDisplayFullTitle() end
    local diffid = ToEnumShortString(trail:GetDifficulty())
    diffid = diffid:sub(1, 1)
    return table.concat({stypeid, "CRS", courseid, diffid}, "/")
end

WF.GetItemID = function(songcrs, stepstrl)
    return (songcrs.GetAllSteps ~= nil) and WF.GetStepsID(songcrs, stepstrl) or WF.GetCourseID(songcrs, stepstrl)
end

function LookupIdentifier(hashorid, rate)
    -- indices for the lookup tables should be just the hash or chart id for 1.0 rate, and [Hash]_n_n or [ID]_n_n
    -- for rate modded charts. a chart on 1.2x rate would have the identifier [Hash]_1_2 or [ID]_1_2
    -- OLD FUNCTION, lookup table no longer works this way, but this id is still used for detailed filenames
    if IsNormalRate(rate) then return hashorid end

    return hashorid.."_"..(NormalizeRateString(rate):gsub("%.", "_"))
end

function CheckLookupEntry(t, hashorid, rate)
    -- quick way to check if an entry exists and get its value if it does
    return t.Lookup[hashorid] and t.Lookup[hashorid][rate]
end

function UpdateLookupEntry(t, hashorid, rate, val)
    -- quick function so that you don't have to check t.Lookup[hash] exists every time you want to index it
    -- t should be the SongStats or CourseStats table within the profile table
    if not t.Lookup[hashorid] then t.Lookup[hashorid] = {} end
    t.Lookup[hashorid][rate] = val
end

function CalculateGrade(score)
    -- score should be int score out of 10000
    for i, v in ipairs(WF.GradePercent) do
        if score >= v then
            return i
        end
    end
end

function CalculateGradeITG(scoreitem)
    -- scoreitem can either be int score /10000 or the whole song stats item.
    -- if a number is passed, assume score is a pass, otherwise check Cleared_ITG field
    -- returns number index of grade; 18 is fail, none is 99
    if not scoreitem then return 99 end

    local pass = true
    local score = scoreitem

    if type(scoreitem) ~= "number" then
        if not scoreitem.Cleared_ITG then return 99 end -- unplayed
        pass = (scoreitem.Cleared_ITG == "C")
        score = scoreitem.BestPercentDP_ITG
    end

    if not pass then return 18 end
    for i, v in ipairs(WF.ITGGradeTiers) do
        if score >= v then
            return i
        end
    end

    return 17 -- #itsa17
end

function ConvertFailToNone(stats)
    -- originally, i did not have a "None" item in clear types, because of the assumption that anything
    -- unplayed would not even have an item in the profile table in the first place. later on, i decided to make
    -- the theme import all the existing itg scores from SL, which inevitably brings about the scenario of having
    -- an itg score but no WF score on a chart. we don't want all these songs to appear as Fails as a result of this,
    -- so do a basic check for 0% WF score with existing itg score and reassign to None
    if not (stats.BestClearType == WF.ClearTypes.Fail) then return end
    if stats.BestPercentDP == 0 and stats.BestPercentDP_ITG > 0 then
        stats.BestClearType = WF.ClearTypes.None
    end
end

function GetSignificantMods(player, steps)
    -- "significant mods" are defined as player options that are important to show in some way on the results screen.
    -- currently the types of significant mods are:
    --- "C" - cmod, when a chart has stops or multiple displaybpms
    --- (name) - all turn mods
    --- "Mines" - no mines
    --- "ITG" - simulate itg
    --- "FA[n]" fa+ window (n is either 100, 125 or 150)
    --- "NoBoys" / "BigBoys" - fault window
    -- returns a table of strings
    -- pass in steps for special cases like specific charts in a course
    if not steps then
        steps = (not GAMESTATE:IsCourseMode()) and GAMESTATE:GetCurrentSteps(player)
            or GAMESTATE:GetCurrentTrail(player)
    end
    local iscourse = (steps.ContainsSong ~= nil)
    local options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
    local slmods = SL[ToEnumShortString(player)].ActiveModifiers
    local t = {}

    -- cmod condition now accounts for scroll rates, speed changes and warps
    -- it's actually possible that a cmod would be considered "significant" when scroll rates actually
    -- render it insignificant. this is pretty harmless as all it will do is show the icon at eval, but
    -- later on i could write a function to evaluate this (not the most complicated thing really)
    local td = (not iscourse) and steps:GetTimingData()
    if (options:CMod()) and (iscourse or (not steps:IsDisplayBpmConstant()) or td:HasStops() or td:HasScrollChanges() 
    or td:HasSpeedChanges() or td:HasNegativeBPMs() or td:HasWarps()) then
        table.insert(t, "C")
    end

    local turns = {"Left","Right","Mirror","Shuffle","SoftShuffle","SuperShuffle","NoMines"}
    for turn in ivalues(turns) do
        if options[turn](options) then
            table.insert(t, turn)
        end
    end

    if slmods.SimulateITGEnv then
        table.insert(t, "ITG")
    end

    if slmods.FAPlus ~= 0 then
        table.insert(t, string.format("FA%d", slmods.FAPlus*10000))
    end

    local what = {{"Disabled","NoBoys"},{"Extended","BigBoys"}}
    for boy in ivalues(what) do
        if math.abs(PREFSMAN:GetPreference("TimingWindowSecondsW5") - WF.GetErrorWindowVal(boy[1])) < 0.00001 then
            table.insert(t, boy[2])
            break
        end
    end

    return t
end

-- these few functions are mostly just me being paranoid about how rates will be written to files
function IsNormalRate(rate)
    return (rate == "1.0" or NormalizeRateString(rate) == "1.0")
end
function RateFromNumber(num)
    if math.abs(1 - num) < 0.0001 then return "1.0" end
    local s = tostring(num)
    if s:len() == 1 then s = s..".0" end
    return s
end
function NormalizeRateString(rate)
    return RateFromNumber(tonumber(rate))
end
function RatesAreEqual(rate1, rate2)
    return ((IsNormalRate(rate1) and IsNormalRate(rate2)) or NormalizeRateString(rate1) == NormalizeRateString(rate2))
end

function GetRateFromModString(str)
    str = str:lower()
    local t = split(",", str)
    for i, v in ipairs(t) do
        if v:find("xmusic") then
            local n = tonumber((v:gsub("xmusic", "")))
            return RateFromNumber(n)
        end
    end
    return "1.0"
end

WF.DateString = function(year, month, day)
    if not year then year = Year() end
    if not month then month = MonthOfYear() + 1 end
    if not day then day = DayOfMonth() end
    return string.format("%d-%02d-%02d", year, month, day)
end

WF.TimeString = function(hour, minute, second)
    if not hour then hour = Hour() end
    if not minute then minute = Minute() end
    if not second then second = Second() end
    return string.format("%02d:%02d:%02d", hour, minute, second)
end

WF.DateTimeString = function(year, month, day, hour, minute, second)
    return WF.DateString(year, month, day).." "..WF.TimeString(hour, minute, second)
end

WF.CompareDateTime = function(s1, s2)
    -- should avoid comparisons between items that aren't the same type -- technically, you could compare
    -- just a date to just a time, and the time would always come out greater unless it was 00:00:00
    -- but logically, we just want to be able to quickly check if some date is before another date,
    -- or some time is before another time.
    -- return -1, 1 or 0 depending on if date 1 is before, after or equivalent to date 2, respectively
    local dt1 = WF.DateTime(s1)
    local dt2 = WF.DateTime(s2)
    if dt1 < dt2 then return -1
    elseif dt1 > dt2 then return 1
    else return 0 end
end

WF.DateTime = function(s)
    -- pass in a string like "2020-05-11" or "06:21:00" or "2028-12-25 17:32:00" and get a datetime table out
    if not s then s = WF.DateTimeString() end

    local dt = { Year = 0, Month = 0, Day = 0, Hour = 0, Minute = 0, Second = 0 }
    local hasdate = s:find("-") and true or false
    local hastime = s:find(":") and true or false
    local datestr, timestr
    if hasdate and hastime then
        local sp = split(" ", s)
        datestr = sp[1]
        timestr = sp[2]
    else
        if not hastime then
            datestr = s
        else
            timestr = s
        end
    end

    if datestr then
        local datevals = datestr:split_tonumber("-")
        dt.Year = datevals[1]
        dt.Month = datevals[2]
        dt.Day = datevals[3]
    end
    if timestr then
        local timevals = timestr:split_tonumber(":")
        dt.Hour = timevals[1]
        dt.Minute = timevals[2]
        dt.Second = timevals[3]
    end

    setmetatable(dt, mt_datetime)
    return dt
end
mt_datetime = {
    __lt = function(a, b)
        if a.Year ~= b.Year then return (a.Year < b.Year)
        elseif a.Month ~= b.Month then return (a.Month < b.Month)
        elseif a.Day ~= b.Day then return (a.Day < b.Day)
        elseif a.Hour ~= b.Hour then return (a.Hour < b.Hour)
        elseif a.Minute ~= b.Minute then return (a.Minute < b.Minute)
        elseif a.Second ~= b.Second then return (a.Second < b.Second) end
        return false
    end,
    __le = function(a, b)
        if a.Year ~= b.Year then return (a.Year < b.Year)
        elseif a.Month ~= b.Month then return (a.Month < b.Month)
        elseif a.Day ~= b.Day then return (a.Day < b.Day)
        elseif a.Hour ~= b.Hour then return (a.Hour < b.Hour)
        elseif a.Minute ~= b.Minute then return (a.Minute < b.Minute)
        elseif a.Second ~= b.Second then return (a.Second < b.Second)
        else return true end
        return false
    end,
    __eq = function(a, b)
        local chk = {"Year","Month","Day","Hour","Minute","Second"}
        for field in ivalues(chk) do
            if a[field] ~= b[field] then return false end
        end
        return true
    end
}

string.split_tonumber = function(str, delim)
    -- assume all items can be converted to numbers
    -- i had to do this enough times in this file to warrant a utility function for it
    if not delim then delim = "," end
    local s = split(delim, str)
    for i = 1, #s do
        s[i] = tonumber(s[i])
    end
    return s
end
