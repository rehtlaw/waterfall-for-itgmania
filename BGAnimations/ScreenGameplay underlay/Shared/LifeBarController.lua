-- functions being called here control the custom lifebars; they are defined in Scripts/WF-LifeBars.lua
local af = Def.ActorFrame{
    JudgmentMessageCommand = function(self, params)
        local tns = ToEnumShortString(params.TapNoteScore)
        if params.EarlyTapNoteScore ~= nil then
            local earlyTns = ToEnumShortString(params.EarlyTapNoteScore)
            if earlyTns ~= "None" then
                if tns == "W5" then
                    return
                end
            end
        end
        WF.LifeBarProcessJudgment(params)
    end,
    EarlyHitMessageCommand = function(self, param)
        WF.LifeBarProcessJudgment(param)
    end,
    WFLifeChangedMessageCommand = function(self, params)
        local songtime = GAMESTATE:GetCurMusicSeconds()
        WF.TrackLifeChange(params.pn, params.ind, params.newlife, songtime)
    end
}

return af
