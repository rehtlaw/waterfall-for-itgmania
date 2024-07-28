local player = ...

-- simple actorframe that is invisible by default, but will temporarily show in order to signal
-- success/fail for gs requests

local notifwidth = 176
local notifheight = 24
local infoheight = 34
local textzoom = 0.8
local infotextzoom = 0.7
local notiftime = 3

return Def.ActorFrame{
    Name = "GSNotification",
    InitCommand = function(self)
        self:xy((player == PLAYER_1 and -1 or 1) * 32, 40)
    end,

    -- frame for main notification
    Def.ActorFrame{
        Name = "MainDialog",

        -- backing quad
        Def.Quad{
            InitCommand = function(self)
                self:vertalign("top"):zoomto(notifwidth, notifheight):diffuse(0,0,0,0)
            end,
            AppearCommand = function(self) self:diffusealpha(0.9):sleep(notiftime):linear(0.4):diffusealpha(0) end,
            SetSuccessCommand = function(self) self:queuecommand("Appear") end,
            SetFailCommand = function(self) self:queuecommand("Appear") end
        },
        -- groovestats logo :)
        LoadActor(THEME:GetPathG("", "GrooveStats.png"))..{
            InitCommand = function(self)
                self:xy(-notifwidth/2 + 2 + (notifheight-2)/2, notifheight/2):zoom((notifheight-2)/128)
                    :diffusealpha(0)
            end,
            AppearCommand = function(self) self:diffusealpha(1):sleep(notiftime):linear(0.4):diffusealpha(0) end,
            SetSuccessCommand = function(self) self:queuecommand("Appear") end,
            SetFailCommand = function(self) self:queuecommand("Appear") end
        },
        -- text
        LoadFont("Common Normal")..{
            Text = "",
            InitCommand = function(self)
                self:xy(-notifwidth/2 + (notifheight-2) + 4, notifheight/2):horizalign("left"):zoom(textzoom)
            end,
            DelayAndHideCommand = function(self) self:sleep(notiftime):linear(0.4):diffusealpha(0) end,
            SetSuccessCommand = function(self) self:settext("✔ ITG score submitted.")
                self:queuecommand("DelayAndHide") end,
            SetFailCommand = function(self) self:settext("❌ Failed to submit...")
                self:queuecommand("DelayAndHide") end,
            SetTimeoutCommand = function(self) self:settext("❌ Timed out")
                self:queuecommand("DelayAndHide") end
        }
    },

    -- frame for "info" box (either error dialog, or rpg notification if not showing by default)
    Def.ActorFrame{
        Name="InfoDialog",
        InitCommand = function(self) self:y(notifheight) end,

        -- backing quad
        Def.Quad{
            InitCommand = function(self)
                self:vertalign("top"):zoomto(notifwidth, infoheight):diffuse(0,0,0,0)
            end,
            AppearCommand = function(self) self:diffusealpha(0.9):sleep(notiftime):linear(0.4):diffusealpha(0) end,
            SetFailCommand = function(self) self:playcommand("Appear") end,
            SetSuccessCommand = function(self, arg)
                -- the arg passed here should be a flag for "show rpg notification" from the caller
                if (not arg) or (not arg[1]) then return end
                self:playcommand("Appear")
            end
        },
        -- text
        LoadFont("Common Normal")..{
            Text = "",
            InitCommand = function(self)
                self:xy(-notifwidth/2 + 4, 2):horizalign("left"):zoom(infotextzoom)
                :vertalign("top")
            end,
            DelayAndHideCommand = function(self) self:sleep(notiftime):linear(0.4):diffusealpha(0) end,
            SetSuccessCommand = function(self, arg)
                if (not arg) or (not arg[1]) then return end
                self:settext("You've gained stats for "..(arg[2] or "Stamina RPG")
                .."!\nView from the &MENULEFT;+&MENURIGHT; menu.")
                self:queuecommand("DelayAndHide") end,
            SetFailCommand = function(self) self:settext("You can submit the ITG score via"
            .."\nthe QR code instead.")
                self:queuecommand("DelayAndHide") end
        }
    }
}
