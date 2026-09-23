-- FA+ count pane
local args = ...
local name = args.sec and "FAPlus2" or "FAPlus"
local player = args.player
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
local pn = tonumber(player:sub(-1))
local notes = pss:GetRadarPossible():GetValue("RadarCategory_TapsAndHolds")
local perfects = pss:GetTapNoteScores("TapNoteScore_W1")

local percent1 = (notes ~= 0) and string.format("%0.2f", math.floor(10000*(WF.FAPlusCount[pn][1]/notes))/100) or "0.00"
local percent2 = (notes ~= 0) and string.format("%0.2f", math.floor(10000*(WF.FAPlusCount[pn][2]/notes))/100) or "0.00"
local percent3 = (notes ~= 0) and string.format("%0.2f", math.floor(10000*(perfects/notes))/100) or "0.00"

local af = Def.ActorFrame{
    Name = name,

    -- FA+ heading
    Def.ActorFrame{
        InitCommand=function(self)
            self:x( -115 )
            self:y( _screen.cy-40 )
        end,
    
        Def.Quad{
            InitCommand=function(self)
                self:diffuse( color("#101519") )
                    :y(-2)
                    :zoomto(70, 28)
            end
        },
    
        LoadFont("raxye/_main")..{
            Text="FA+",
            InitCommand=function(self) self:horizalign("center"):zoom(0.325):xy( 0, -6) end,
        }
    },

    -- table
    Def.ActorFrame{
        InitCommand = function(self)
            self:xy(-104, _screen.cy - 12)
        end,
        -- header texts
        LoadFont("Common Normal")..{
            Text = "Window",
            InitCommand = function(self) self:zoom(0.833):x(32) end
        },
        LoadFont("Common Normal")..{
            Text = "Count",
            InitCommand = function(self) self:zoom(0.833):x(112) end
        },
        LoadFont("Common Normal")..{
            Text = "Percent",
            InitCommand = function(self) self:zoom(0.833):x(200) end
        },
        -- line under header
        Def.Quad{
            InitCommand = function(self) self:xy(-34, 12):horizalign("left"):zoomto(264,2) end
        },
        -- window names
        LoadFont("Common Normal")..{
            Text = "Insane 10ms",
            InitCommand = function(self) self:xy(52, 30):horizalign("right"):zoom(0.833) end
        },
        LoadFont("Common Normal")..{
            Text = "Masterful 15ms",
            InitCommand = function(self) self:xy(52, 58):horizalign("right"):zoom(0.833) end
        },
        -- count numbers
        LoadFont("raxye/_numbers")..{
            Text = tostring(WF.FAPlusCount[pn][1]),
            InitCommand = function(self)
                self:xy(132, 24):horizalign("right"):zoom(0.2)
            end
        },
        LoadFont("raxye/_numbers")..{
            Text = tostring(perfects),
            InitCommand = function(self)
                self:xy(132, 52):horizalign("right"):zoom(0.2)
            end
        },
        -- percents
        LoadFont("raxye/_numbers")..{
            Text = percent1,
            InitCommand = function(self)
                self:xy(226, 24):horizalign("right"):zoom(0.2)
            end
        },
        LoadFont("raxye/_numbers")..{
            Text = percent3,
            InitCommand = function(self)
                self:xy(226, 52):horizalign("right"):zoom(0.2)
            end
        },
        -- step count
        LoadFont("Common Normal")..{
            Text = "Total Steps",
            InitCommand = function(self) self:xy(120, 106):horizalign("right"):zoom(0.833) end
        },
        LoadFont("raxye/_numbers")..{
            Text = tostring(notes),
            InitCommand = function(self)
                self:xy(226, 100):horizalign("right"):zoom(0.2)
            end
        },
    }
}

return af
