local args = ...
local player = args.player
local name = args.sec and "Achievements2" or "Achievements"
local pn = tonumber(player:sub(-1))
local hsdata
local iscourse = GAMESTATE:IsCourseMode()

if args.hsdata then
    hsdata = args.hsdata[pn]
else
    return nil
end

if not PROFILEMAN:IsPersistentProfile(player) then return nil end

local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
local scorestr = (FormatPercentScore(pss:GetPercentDancePoints()):gsub("%%", ""):gsub(" ", ""))
local scorestr_itg = WF.ITGScore[pn]

-- get the integer values to do the comparisons
-- using the post-stringified dp with .2f rounding applied makes sense, since we never store scores with higher
-- resolution than that anyway
local score = math.round(tonumber(scorestr) * 100)
local grade = CalculateGrade(score)
local so = (not iscourse) and WF.CurrentSongStatsObject[pn] or WF.CurrentCourseStatsObjects[pn][1]
local ct = so:GetClearType()
local ctstr = WF.ClearTypesShort[ct]
local faplus = {WF.FAPlusCount[pn][1], WF.FAPlusCount[pn][2], pss:GetTapNoteScores("TapNoteScore_W1")}
local score_itg = math.round(tonumber(scorestr_itg) * 100)
local grade_itg = WF.ITGFailed[pn] and 18 or tonumber(WF.GetITGGrade(scorestr_itg))

-- old values for comparisons with new values
local oldscore = 0
local oldgrade = 99
local oldscore_itg = 0
local oldgrade_itg = 99
local oldct
local oldctstr = "None"
local oldfaplus = {0,0,0}
local oldscorestr = "0.00"
local oldscorestr_itg = "0.00"

local oldstats = (not iscourse) and hsdata.PlayerSongStats_Old or hsdata.PlayerCourseStats_Old
if oldstats then
    oldscore = oldstats.BestPercentDP
    oldscorestr = string.format("%0.2f", oldscore / 100)
    oldgrade = CalculateGrade(oldscore)
    oldct = oldstats.BestClearType
    oldctstr = WF.ClearTypesShort[oldct]
    for i = 1, 3 do oldfaplus[i] = oldstats.BestFAPlusCounts[i] end
    oldscore_itg = oldstats.BestPercentDP_ITG
    oldscorestr_itg = string.format("%0.2f", oldscore_itg / 100)
    oldgrade_itg = CalculateGradeITG(oldstats)
end

-- function for setting the little arrow depending on the comparison
local function setarrow(actor, compare)
    -- compare should be new - old (negated in the case of things like cleartype or grade)
    if compare < 0 then
        actor:rotationz(180):diffuse(1,0.5,0.5,1)
    elseif compare > 0 then
        actor:diffuse(0.5,1,0.5,1)
    else
        actor:rotationz(90)
    end
end

local af = Def.ActorFrame{
    Name = name,
    InitCommand=function(self)
        self:y( _screen.cy-40 )
    end,

    -- heading
    Def.ActorFrame{
        Def.Quad{
            InitCommand=function(self)
                self:diffuse( color("#101519") )
                    :y(-2)
                    :zoomto(300, 28)
            end
        },
    
        LoadFont("raxye/_main")..{
            Text="ACHIEVEMENTS",
            InitCommand=function(self) self:horizalign("center"):zoom(0.3):xy( 0, -6) end,
        }
    },

    -- Scores
    LoadFont("Common Normal")..{
        Text = "Standard",
        InitCommand = function(self) self:xy(-140, 22):horizalign("left") end
    },
    LoadFont("raxye/_numbers")..{
        Text = oldscorestr,
        InitCommand = function(self) self:xy(-86, 35):horizalign("right"):diffuse(0.8,0.8,0.8,1):zoom(0.14) end
    },
    LoadFont("raxye/_numbers")..{
        Text = scorestr,
        InitCommand = function(self) self:xy(-70, 35):horizalign("left"):zoom(0.14) end
    },
    LoadActor("./arrow.png")..{
        InitCommand = function(self) setarrow(self, score-oldscore) self:xy(-78, 40):zoom(0.4) end
    },
    LoadFont("Common Normal")..{
        Text = "ITG",
        InitCommand = function(self) self:xy(10, 22):horizalign("left") end
    },
    LoadFont("raxye/_numbers")..{
        Text = oldscorestr_itg,
        InitCommand = function(self) self:xy(150-86, 35):horizalign("right"):diffuse(0.8,0.8,0.8,1):zoom(0.14) end
    },
    LoadFont("raxye/_numbers")..{
        Text = scorestr_itg,
        InitCommand = function(self) self:xy(150-70, 35):horizalign("left"):zoom(0.14) end
    },
    LoadActor("./arrow.png")..{
        InitCommand = function(self) setarrow(self, score_itg-oldscore_itg) self:xy(150-78, 40):zoom(0.4) end
    },

    -- Grades
    LoadActor(THEME:GetPathG("","_GradesSmall/LetterGrade.lua"), {grade = oldgrade})..{
        OnCommand = function(self) self:xy(-108, 60):zoom(0.3):diffuse(0.8,0.8,0.8,1) end
    },
    LoadActor(THEME:GetPathG("","_GradesSmall/LetterGrade.lua"), {grade = grade})..{
        OnCommand = function(self) self:xy(-48, 60):zoom(0.3) end
    },
    LoadActor("./arrow.png")..{
        InitCommand = function(self) setarrow(self, oldgrade-grade) self:xy(-78, 60):zoom(0.4) end
    },
    LoadActor(THEME:GetPathG("","_GradesSmall/LetterGrade.lua"), {grade = oldgrade_itg, itg = true})..{
        OnCommand = function(self) self:xy(150-108, 60):diffuse(0.8,0.8,0.8,1):zoom(0.3) end
    },
    LoadActor(THEME:GetPathG("","_GradesSmall/LetterGrade.lua"), {grade = grade_itg, itg = true})..{
        OnCommand = function(self) self:xy(150-48, 60):zoom(0.3) end
    },
    LoadActor("./arrow.png")..{
        InitCommand = function(self) setarrow(self, oldgrade_itg-grade_itg) self:xy(150-78, 60):zoom(0.4) end
    },

    -- Clear Type
    LoadFont("Common Normal")..{
        Text = oldctstr,
        InitCommand = function(self) self:xy(-108, 80):diffuse(WF.ClearTypeColor(oldct)):zoom(0.8) end
    },
    LoadFont("Common Normal")..{
        Text = ctstr,
        InitCommand = function(self) self:xy(-48, 80):diffuse(WF.ClearTypeColor(ct)):zoom(0.8) end
    },
    LoadActor("./arrow.png")..{
        InitCommand = function(self) setarrow(self, (oldct or 20)-ct) self:xy(-78, 80):zoom(0.4) end
    },

    -- FA+
    LoadFont("Common Normal")..{
        Text = "FA+",
        InitCommand = function(self) self:xy(-140, 104):horizalign("left") end
    }
}

-- FA+ (continued because i like loops)
--local c = {WF.LifeBarColors[3], SL.JudgmentColors.Waterfall[1]}
local l = {"10ms", "15ms"}
for i = 1, 2 do
    local j = i
    if i == 2 then j = 3 end -- lol
    af[#af+1] = LoadFont("Common Normal")..{
        Text = l[i],
        InitCommand = function(self) self:xy(-100, 122 + (i-1)*15):horizalign("right"):zoom(0.75) end
    }
    af[#af+1] = LoadFont("raxye/_numbers")..{
        Text = tostring(oldfaplus[j]),
        InitCommand = function(self) self:xy(-40, 117 + (i-1)*15):horizalign("right"):zoom(0.12)
            :diffusealpha(0.75) end
    }
    af[#af+1] = LoadFont("raxye/_numbers")..{
        Text = tostring(faplus[j]),
        InitCommand = function(self) self:xy(32, 117 + (i-1)*15):horizalign("right"):zoom(0.12) end
    }
    af[#af+1] = LoadActor("./arrow.png")..{
        InitCommand = function(self) setarrow(self, faplus[j]-oldfaplus[j]) self:xy(-26, 122 + (i-1)*15):zoom(0.4) end
    }
end

return af
