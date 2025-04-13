-- A bunch of scripts to calculate EX scoring
-- Scoring system originally used for ITL 2022
-- Using a completely new script file (for now?) because I don't want to potentially mess up the stuff that Steve did
-- We don't need all the functions because this is purely for scoring, still using ITG lifebar
-- Introduced in 0.7.6

WF.EXScoreWeights = {
	3.5,	-- FantasticPlus, 15ms
	3, 		-- Fantastic
	2,		-- Excellent
	1,		-- Great
	0,		-- Decent
	0,		-- Way Off
	0,		-- Miss
	1,		-- Held
	0,		-- Dropped
	-1		-- Mine
}

WF.EXTimingWindows = {
	0.015, -- BLUE
    0.023, -- Fantastic
    0.0445, -- Excellent
    0.1035, -- Great
    0.1365, -- Decent
    0.1815 -- Way Off
}

WF.EXJudgments = enum_table({ 
	"FantasticPlus", 
	"Fantastic", 
	"Excellent", 
	"Great", 
	"Decent", 
	"Way Off", 
	"Miss", 
	"Held", 
	"Dropped", 
	"Mine" 
})

WF.EXClearTypes = enum_table({
	"Quint",
	"Quad",
	"FEC",
	"FC",
	"None"
})

WF.EXClearTypeColors = {
	"#f604e6",
	"#00a2e8",
	"#ffff00",
	"#00ce00",
	"#ffffff"
}

WF.NewGetEXJudgmentCounts = function(player)
	local pn = tonumber(player:sub(-1))
	local options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
	local stats = STATSMAN:GetCurStageStats():GetPlayerStageStats(pn)
	local StepsOrTrail = (GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player)) or GAMESTATE:GetCurrentSteps(player)
	
	local judgments = {}
	
	local held 			= WF.ITGJudgmentCounts[pn][7]
	local dropped		= WF.ITGJudgmentCounts[pn][8]
	local mine 			= WF.ITGJudgmentCounts[pn][9]
	
	judgments["W0"] = WF.FAPlusCount[pn][3]
	judgments["W1"] = WF.ITGJudgmentCounts[pn][1]- WF.FAPlusCount[pn][3]
	judgments["W2"] = WF.ITGJudgmentCounts[pn][2]
	judgments["W3"] = WF.ITGJudgmentCounts[pn][3]
	judgments["W4"] = WF.ITGJudgmentCounts[pn][4]
	judgments["W5"] = WF.ITGJudgmentCounts[pn][5]
	judgments["Miss"] = WF.ITGJudgmentCounts[pn][6]
	judgments["totalSteps"] = StepsOrTrail:GetRadarValues(player):GetValue("RadarCategory_TapsAndHolds")
	local RadarCategory = { "Holds", "Mines", "Rolls" }
	for RCType in ivalues(RadarCategory) do
		local number = stats:GetRadarActual():GetValue( "RadarCategory_"..RCType )
		local possible = StepsOrTrail:GetRadarValues(player):GetValue( "RadarCategory_"..RCType )

		if RCType == "Mines" then
			-- NoMines still report the total number of mines that exist in a chart, even if they weren't played in the chart.
			-- If NoMines was set, report 0 for the number of mines as the chart actually didn't have any.
			-- TODO(teejusb): Track AvoidMine in the future. This is fine for now as ITL compares serverside.
			if options:NoMines() then
				judgments[RCType] = 0
				judgments["total"..RCType] = 0
			else
				-- We want to keep track of mines hit.
				judgments[RCType] = possible - number
				judgments["total"..RCType] = possible
			end
		else
			judgments[RCType] = number
			judgments["total"..RCType] = possible
		end
	end

	return judgments
end

WF.GetEXJudgmentCounts = function(player)
	local pn = tonumber(player:sub(-1))

	local judgments = {}

	local fantasticPlus	= WF.FAPlusCount[pn][3] -- Created [3] in 0.7.6
	local fantastic		= WF.ITGJudgmentCounts[pn][1]- WF.FAPlusCount[pn][3]
	local excellent 	= WF.ITGJudgmentCounts[pn][2]
	local great 		= WF.ITGJudgmentCounts[pn][3]
	local decent 		= WF.ITGJudgmentCounts[pn][4]
	local wayOff 		= WF.ITGJudgmentCounts[pn][5]
	local miss 			= WF.ITGJudgmentCounts[pn][6]
	local held 			= WF.ITGJudgmentCounts[pn][7]
	local dropped		= WF.ITGJudgmentCounts[pn][8]
	local mine 			= WF.ITGJudgmentCounts[pn][9]

	table.insert(judgments,fantasticPlus)
	table.insert(judgments,fantastic)
	table.insert(judgments,excellent)
	table.insert(judgments,great)
	table.insert(judgments,decent)
	table.insert(judgments,wayOff)
	table.insert(judgments,miss)
	table.insert(judgments,held)
	table.insert(judgments,dropped)
	table.insert(judgments,mine)

	return judgments
end

WF.GetEXClearType = function(player, customJudgments)

	judgments = (true and customJudgments) or WF.GetEXJudgmentCounts(player)
	if judgments[9] + judgments[7] + judgments[6] + judgments[5] > 0 then
		return WF.EXClearTypes[5]
	end
	
	for ind = 4,2,-1 do
		if judgments[ind] > 0 then
			return WF.EXClearTypes[ind]
		end
	end
	return WF.EXClearTypes[1]
end

WF.GetEXMaxDP = function(player, steps)
    -- if no steps (or trail) passed, use current
    if not steps then
        steps = (not GAMESTATE:IsCourseMode()) and GAMESTATE:GetCurrentSteps(player)
            or GAMESTATE:GetCurrentTrail(player)
    end
    local iscourse = (steps.GetAllSongs == nil)
    local radar = steps:GetRadarValues((not iscourse) and player or nil)
    local weights = WF.EXScoreWeights
    local totalholdjudgments = radar:GetValue("RadarCategory_Holds") + radar:GetValue("RadarCategory_Rolls")
    local totaltapjudgments = radar:GetValue("RadarCategory_TapsAndHolds")
    
	return totalholdjudgments * weights[WF.EXJudgments.Held]
        + totaltapjudgments * weights[WF.EXJudgments.FantasticPlus]
end

WF.EXDP = function(player, customJudgments)
	local dp = 0
	local judgments = (true and customJudgments) or WF.GetEXJudgmentCounts(player)
	for i=1,#judgments do
		dp = dp + (WF.EXScoreWeights[i] * judgments[i])
	end

	return dp
end
	
WF.GetEXPercentDP = function(player, maxdp, incourse)
    -- if maxdp is passed in, just use that so we don't have to call current steps every time
    local steps = ((incourse) and (not maxdp)) and GAMESTATE:GetCurrentSteps(player) or nil
    if not maxdp then maxdp = WF.GetEXMaxDP(player, steps) end

    if maxdp == 0 then return 0 end

    local pn = tonumber(player:sub(-1))
    local raw = (not incourse) and (WF.EXDP(player) / maxdp) or WF.ITGDP_CurSongInCourse[pn] / maxdp -- Courses don't work yet
    return math.max(0, math.floor(raw * 10000) / 10000)
end

WF.GetEXScore = function(player)
	return string.format("%.2f", WF.GetEXPercentDP(player)*100)
end

WF.EXClearTypeColor = function(ct)
    --return color("#000000")
	return color(WF.EXClearTypeColors[WF.EXClearTypes[ct]])
end

WF.EXBonusPoints = function(ct)
	local clearNum = (6 - WF.EXClearTypes[ct]) * 100
	if clearNum < 400 then clearNum = clearNum - 100 end
	return clearNum
end

WF.GetEXJudgment = function(offset)
    for i, v in ipairs(WF.EXTimingWindows) do
        if math.abs(offset) <= v then
            -- only use Decent if "Extended" is selected for Fault
            if i == 5 then return (WF.SelectedErrorWindowSetting == 3) and 5 or 6 end
            return i
        end
    end

    return WF.ITGJudgments.Miss -- this should never happen but who knows
end

ITL = {}

ITL.logConstant = math.log(1.0638215)
ITL.maxPoints = 9000
ITL.ITLPoints = function(percEX, points)
	local ihateluastrings = (type(percEX) == "number" and percEX) or tonumber(percEX)
	local firstTerm = math.log(math.min(ihateluastrings,75)+1) / ITL.logConstant 
	local secondTerm = 31 ^ ( math.max(0,ihateluastrings-75) / 25 )
	local finalPerc = (firstTerm + secondTerm - 1) / 100
	return finalPerc * points
end

ITL.getChartPoints = function(chartName)
	return (tonumber(string.sub(chartName,1,4)))
end
