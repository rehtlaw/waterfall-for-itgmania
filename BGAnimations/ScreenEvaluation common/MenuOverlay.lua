-- pressing menu left + menu right will bring up a menu with various commands including screenshot
-- and saving detailed scores. when we determine not to show srpg overlay automatically (neither player is on
-- itg mode and got an rpg response back), viewing the rpg overlay will be accessible from here.

-- menu selections can dynamically be added or removed depending on the state of the game/menu itself.
-- the boolean is whether the item is currently selectable.
local args = ...
local upscores = args and args.CourseUpscores

WF.MenuSelections = {}
local selected = {}
local activeplayer = 1
local maxselections = 4
for i = 1, 2 do
    WF.MenuSelections[i] = {
        { "Save screenshot", true, false }
    }

    if WF.PlayerProfileStats[i] then
        if (not GAMESTATE:IsCourseMode()) then
            table.insert(WF.MenuSelections[i], { "Save detailed stats", true } )
        else
            if upscores and upscores[i] and (#upscores[i].WF > 0 or #upscores[i].ITG > 0) then
                table.insert(WF.MenuSelections[i], { "Save detailed stats\nfor upscores", true } )
            else
                table.insert(WF.MenuSelections[i], { "No upscores", false } )
            end
            table.insert(WF.MenuSelections[i], { "Save all detailed stats", true } )
        end
    end

    selected[i] = 1
end

local SelectionActions = {
    ["Save screenshot"] = function(pn)
        MESSAGEMAN:Broadcast("DelayAndScreenshot", {PlayerNumber = "PlayerNumber_P"..pn})
    end,
    ["Save detailed stats"] = function(pn)
        MESSAGEMAN:Broadcast("WriteDetailed", {PlayerNumber = "PlayerNumber_P"..pn})
    end,
    ["Save detailed stats\nfor upscores"] = function(pn)
        MESSAGEMAN:Broadcast("WriteUpscoresDetailed", {PlayerNumber = "PlayerNumber_P"..pn, 
            Data = upscores and upscores[pn]})
    end,
    ["Save all detailed stats"] = function(pn)
        MESSAGEMAN:Broadcast("WriteAllDetailed", {PlayerNumber = "PlayerNumber_P"..pn,
            Data = upscores and upscores[pn]})
    end,
    ["View Event stats"] = function(pn)
        -- we actually want to just show the overlay for both players if available, since 2
        -- people are not going to hit this at the same time obviously
        --local show = WF.RPGData and (WF.RPGData[1] or WF.RPGData[2])
        --if not show then
        --    SM("No Event Data!")
        --    return false
        --end
        local overlay = SCREENMAN:GetTopScreen():GetChild("Overlay"):GetChild("ScreenEval Common")
        overlay:GetChild("AutoSubmitMaster"):GetChild("EventOverlay"):visible(true)
       -- for p = 1, 2 do
       --     if WF.RPGData[p] then
       --         overlay:GetChild("AutoSubmitMaster"):GetChild("RpgOverlay"):GetChild("P"..p.."RpgAf")
       --         :playcommand("Show", {data = WF.RPGData[p]})
       --     end
       -- end
        overlay:queuecommand("DirectInputToEventHandler")
        return true
    end
	--["View ITL 2022 stats"] = function(pn)
    --   -- we actually want to just show the overlay for both players if available, since 2
    --   -- people are not going to hit this at the same time obviously
    --   local show = WF.RPGData and (WF.RPGData[1] or WF.RPGData[2])
    --   if not show then
    --       SM("No ITL 2022 Data!")
    --       return false
    --   end
    --   local overlay = SCREENMAN:GetTopScreen():GetChild("Overlay"):GetChild("ScreenEval Common")
    --   overlay:GetChild("AutoSubmitMaster"):GetChild("RpgOverlay"):visible(true)
    --   for p = 1, 2 do
    --       if WF.RPGData[p] then
    --           overlay:GetChild("AutoSubmitMaster"):GetChild("RpgOverlay"):GetChild("P"..p.."RpgAf")
    --           :playcommand("Show", {data = WF.RPGData[p]})
    --       end
    --   end
    --   overlay:queuecommand("DirectInputToRpgHandler")
    --   return true
    --end
}

local af = Def.ActorFrame{
    Name = "MenuOverlay",
    EvalMenuInputEventMessageCommand = function(self, arg)
        if arg.action == "Confirm" then
            local stable = WF.MenuSelections[arg.pn][selected[arg.pn]]
            local key = stable[1]
            local noredirect = false
            if stable[2] then
                noredirect = SelectionActions[key](arg.pn)
                self:playcommand("Hide")
                if (not noredirect) then self:GetParent():queuecommand("DirectInputToEngine") end
                selected[1] = 1
                selected[2] = 1
            end
            self:playcommand("Update")
        elseif arg.action == "Cancel" then
            self:playcommand("Hide")
            self:GetParent():queuecommand("DirectInputToEngine")
            selected[arg.pn] = 1
        elseif arg.action == "Up" then
            selected[arg.pn] = (selected[arg.pn] > 1) and (selected[arg.pn] - 1) or #WF.MenuSelections[arg.pn]
            self:playcommand("SetSelection")
        elseif arg.action == "Down" then
            selected[arg.pn] = (selected[arg.pn] < #WF.MenuSelections[arg.pn]) and (selected[arg.pn] + 1) or 1
            self:playcommand("SetSelection")
        end
    end
}

local menuwidth = 140
local border = 2
local selheight = 32
local xoff = 186
local menuy = 64

-- create a frame for each player
for pn, player in ipairs(PlayerNumber) do
    local pf = Def.ActorFrame{
        Name = "P"..pn.."Menu",
        InitCommand = function(self)
            self:xy(_screen.cx + xoff * (pn == 1 and -1 or 1), menuy):visible(false)
        end,
        ShowCommand = function(self, arg)
            if GAMESTATE:IsHumanPlayer(player) then
                self:playcommand("Update")
                self:visible(true)
            end
        end,
        HideCommand = function(self) self:visible(false) end,

        -- border
        Def.Quad{
            InitCommand = function(self)
                self:vertalign("top"):playcommand("SetSize")
            end,
            SetSizeCommand = function(self)
                self:zoomto(menuwidth + border*2, selheight*#WF.MenuSelections[pn] + border*2)
            end,
            UpdateCommand = function(self) self:playcommand("SetSize") end,
            EvalMenuInputEventMessageCommand = function(self) self:playcommand("SetSize") end
        },

        -- backing for menu portion
        Def.Quad{
            InitCommand = function(self)
                self:y(border):vertalign("top"):diffuse(0.1,0.1,0.1,1):playcommand("SetSize")
            end,
            SetSizeCommand = function(self)
                self:zoomto(menuwidth, selheight*#WF.MenuSelections[pn])
            end,
            UpdateCommand = function(self) self:playcommand("SetSize") end,
            EvalMenuInputEventMessageCommand = function(self) self:playcommand("SetSize") end
        },

        -- highlight for current selection
        Def.Quad{
            InitCommand = function(self)
                self:y(border):vertalign("top"):diffuse(PlayerColor(player)):zoomto(menuwidth, selheight)
            end,
            SetSelectionCommand = function(self)
                self:y(border + selheight*(selected[pn]-1))
            end,
            UpdateCommand = function(self) self:playcommand("SetSelection") end
        }
    }

    -- texts for each actual selections
    for i = 1, maxselections do
        pf[#pf+1] = LoadFont("Common Normal")..{
            Text = WF.MenuSelections[pn][i] and WF.MenuSelections[pn][i][1] or "",
            InitCommand = function(self)
                self:xy(-menuwidth/2 + 2, border + selheight/2 + (i-1)*selheight):maxwidth((menuwidth-4)/0.9)
                    :horizalign("left"):vertspacing(-9):zoom(0.9)
                if self:GetText():find("\n") then self:addy(-2) end -- lol??
                self:playcommand("EvaluateSelection")
            end,
            EvaluateSelectionCommand = function(self)
                if not WF.MenuSelections[pn][i] then
                    self:settext("")
                    return
                end
                self:settext(WF.MenuSelections[pn][i][1])
                self:diffusealpha(WF.MenuSelections[pn][i][2] and 1 or 0.3)
            end,
            EvalMenuInputEventMessageCommand = function(self) self:playcommand("EvaluateSelection") end,
            UpdateCommand = function(self) self:playcommand("EvaluateSelection") end
        }
    end

    af[#af+1] = pf
end

return af
