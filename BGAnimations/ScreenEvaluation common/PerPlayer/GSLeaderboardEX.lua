local args = ...
local player = args.player
local pn = tonumber(player:sub(-1))
local name = "GSLeaderboardEX"
local sec = args.sec
if sec then name = name.."2" end
local Font = "Common Normal"
local row_height = 20.25

local af = Def.ActorFrame{
    Name = name,
    InitCommand = function(self) self:y(_screen.cy - 62):zoom(0.8):visible(false) end,
    AddEXLeaderboardCommand = function(self, arg)
        -- only add to list and make visible if arg (the leaderboard table) is passed in
        if arg then
            -- find index to place the pane (should be after GSLeaderboard) and insert it after
            local panes = sec and WF.EvalSecPanes or WF.EvalPanes[pn]
            local names = {}
            for i, pane in ipairs(panes) do
                table.insert(names, pane:GetName())
                if pane:GetName():find("GSLeaderboard") then
                    table.insert(panes, i+1, self)
                    break
                end
            end
        end
    end,

    -- heading quad
    Def.Quad{
        InitCommand = function(self)
            self:vertalign("top"):y(7):zoomto(300/0.8, row_height+2):diffuse(color("#101519"))
        end
    },

    -- heading text
    LoadFont("Common Normal")..{
        Text = "GrooveStats Records (EX)",
        InitCommand = function(self) self:y(row_height/2+8) end
    }
}

for i = 1, 10 do
    local pname, score, date
    pname	= "----"
    score	= "------"
    date	= "----------"

    local row = Def.ActorFrame{
        Name = "HSRow"..i,
        AddEXLeaderboardCommand = function(self, arg)
            if arg and arg[i] then
                if arg[i]["isRival"] then
                    self:diffuse(color("#BD94FF"))
                elseif arg[i]["isSelf"] then
                    self:diffuseshift():effectperiod(4/3)
                    self:effectcolor1( PlayerColor("PlayerNumber_P1") )
                    self:effectcolor2( Color.White )
                end
            end
        end
    }

    row[#row+1] = LoadFont(Font)..{
        Name = "PlaceNum",
        Text=i..". ",
        InitCommand=function(self) self:horizalign(right):xy(-132, (i+1)*row_height) end,
        AddEXLeaderboardCommand = function(self, arg)
            if arg and arg[i] then
                self:settext(arg[i]["rank"]..". ")
            end
        end
    }

    row[#row+1] = LoadFont(Font)..{
        Name = "PlayerName",
        Text=pname,
        InitCommand=function(self) self:horizalign(left):xy(-122, (i+1)*row_height):maxwidth(96) end,
        AddEXLeaderboardCommand = function(self, arg)
            if arg and arg[i] then
                self:settext(arg[i]["name"])
            end
        end
    }

    row[#row+1] = LoadFont(Font)..{
        Name = "Score",
        Text=score,
        InitCommand=function(self) self:horizalign(left):xy(-24, (i+1)*row_height) end,
        AddEXLeaderboardCommand = function(self, arg)
            if arg and arg[i] then
                self:settext(string.format("%0.2f%%", arg[i]["score"]/100)):diffuse(color("#21CCE8"))
                if arg[i]["isFail"] then self:stopeffect():diffuse(Color.Red) end
            end
        end
    }

    row[#row+1] = LoadFont(Font)..{
        Name = "Date",
        Text=date,
        InitCommand=function(self) self:horizalign(left):xy(50, (i+1)*row_height) end,
        AddEXLeaderboardCommand = function(self, arg)
            if arg and arg[i] then
                self:settext(ParseGroovestatsDate(arg[i]["date"]))
            end
        end
    }

    af[#af+1] = row
end

return af
