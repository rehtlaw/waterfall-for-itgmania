local args = ...
local player = args.player
local hash = args.hash
local pn = tonumber(player:sub(-1))
local other_pn = ToEnumShortString(player)
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
local steps = GAMESTATE:GetCurrentSteps(player)
local radar_values = steps:GetRadarValues(player)

local failed = WF.ITGFailed[pn] and "1" or "0"
local rate = tostring(SL.Global.ActiveModifiers.MusicRate * 100):gsub("%.", "")
local judgmentCounts = WF.ITGJudgmentCounts[pn]

local difficulty = ""

if steps then
	difficulty = steps:GetDifficulty()
	-- GetDifficulty() returns a value from the Difficulty Enum
	-- "Difficulty_Hard" for example.
	-- Strip the characters up to and including the underscore.
	difficulty = ToEnumShortString(difficulty)
end

local fantastic_plus = pss:GetTapNoteScores( "TapNoteScore_W1" )
local fantastic = judgmentCounts[1] - fantastic_plus
local excellent = judgmentCounts[2]
local great = judgmentCounts[3]
local decent = judgmentCounts[4]
local wayOff = judgmentCounts[5]
local miss = judgmentCounts[6]
local total_steps = steps:GetRadarValues(player):GetValue( "RadarCategory_TapsAndHolds" )
local holds_held = judgmentCounts[7]
local total_holds = radar_values:GetValue("RadarCategory_Holds")
local mines_hit = judgmentCounts[9]
local total_mines = radar_values:GetValue("RadarCategory_Mines")
local rolls_held = judgmentCounts[8]
local total_rolls = radar_values:GetValue("RadarCategory_Rolls")

for option in ivalues(GAMESTATE:GetPlayerState(other_pn):GetPlayerOptionsArray("ModsLevel_Preferred")) do
	if option:match("NoMines") then
		total_mines = 0
	end
end

local preferredFaults = SL[ToEnumShortString(player)].ActiveModifiers.PreferredFaultWindow

-- Preemptively stringify the deceent and wayoff counts to account for nil values
if preferredFaults == 1 then
	decent = "N"
	wayOff = ("%x"):format(wayOff)
elseif preferredFaults == 2 then
	decent = "N"
	wayOff = "N"
elseif preferredFaults == 3 then
	decent = ("%x"):format(decent)
	wayOff = ("%x"):format(wayOff)
end

local cmod = GAMESTATE:GetPlayerState(other_pn):GetPlayerOptions("ModsLevel_Preferred"):CMod()
local used_cmod = cmod ~= nil and "1" or "0"

local rescored = {
  W0 = 0,
  W1 = 0,
  W2 = 0,
  W3 = 0,
  W4 = 0,
  W5 = 0
}

local rescored_str = ""

-- will need to update this to not be hardcoded to dance if GrooveStats supports other games in the future
local style = ""
if GAMESTATE:GetCurrentStyle():GetStyleType() == "StyleType_OnePlayerTwoSides" then
	style = "dance-double"
else
	style = "dance-single"
end

-- ************* CURRENT QR VERSION *************
-- * Update whenever we change relevant QR code *
-- *  and when the backend GrooveStats is also  *
-- *   updated to properly consume this value.  *
-- **********************************************
local hash_version = SL.GrooveStats.ChartHashVersion

local url = ("HTTPS://GROOVESTATS.COM/QR/%s/T%xG%xH%xI%xJ%xK%sL%sM%xH%xT%xR%xT%xM%xT%x%s/F%sR%xC%sV%x"):format(
        hash, total_steps, fantastic_plus, fantastic, excellent, great, decent, wayOff, miss,
        holds_held, total_holds, rolls_held, total_rolls, mines_hit, total_mines, rescored_str,
        failed, rate, used_cmod, hash_version):upper()

SM(url)
return url
