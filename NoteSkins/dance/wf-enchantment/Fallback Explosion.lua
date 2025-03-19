--If a Command has "NOTESKIN:GetMetricA" in it, that means it gets the command from the metrics.ini, else use cmd(); to define command.
--If you dont know how "NOTESKIN:GetMetricA" works here is an explanation.
--NOTESKIN:GetMetricA("The [Group] in the metrics.ini", "The actual Command to fallback on in the metrics.ini");

--The NOTESKIN:LoadActor() just tells us the name of the image the Actor redirects on.
--Oh and if you wonder about the "Button" in the "NOTESKIN:LoadActor( )" it means that it will check for that direction.
--So you dont have to do "Down" or "Up" or "Left" etc for every direction which will save space ;)

local player = Var "Player"
local pn = tonumber(player:sub(-1))
local useitg = false

if WF and SL and SL["P"..pn] and SL["P"..pn].ActiveModifiers then
	useitg = SL["P"..pn].ActiveModifiers.SimulateITGEnv
end

local t = Def.ActorFrame {
	--Hold Explosion Commands
	NOTESKIN:LoadActor( Var "Button", "Hold Explosion" ) .. {
		HoldingOnCommand=NOTESKIN:GetMetricA("HoldGhostArrow", "HoldingOnCommand");
		HoldingOffCommand=NOTESKIN:GetMetricA("HoldGhostArrow", "HoldingOffCommand");
		InitCommand=cmd(playcommand,"HoldingOff";finishtweening);
	};
	--Roll Explosion Commands
	NOTESKIN:LoadActor( Var "Button", "Hold Explosion" ) .. {
		RollOnCommand=NOTESKIN:GetMetricA("HoldGhostArrow", "RollOnCommand");
		RollOffCommand=NOTESKIN:GetMetricA("HoldGhostArrow", "RollOffCommand");
		InitCommand=cmd(playcommand,"RollOff";finishtweening);
		BrightCommand=cmd(visible,false);
		DimCommand=cmd(visible,false);
	};
	--Mine Explosion Commands
	NOTESKIN:LoadActor( Var "Button", "HitMine Explosion" ) .. {
		InitCommand=cmd(blend,"BlendMode_Add";diffusealpha,0);
		HitMineCommand=NOTESKIN:GetMetricA("GhostArrowBright", "HitMineCommand");
	};
}
-- dynamically create tap explosions based on whether ITG is in use
if not useitg then
    --We use this for Seperate Explosions for every Judgement
	t[#t+1] = Def.ActorFrame {
		--W1 aka Marvelous Dim Explosion Commands
		NOTESKIN:LoadActor( Var "Button", "Tap Explosion Dim W1" ) .. {
			InitCommand=cmd(diffusealpha,0);
			W1Command=NOTESKIN:GetMetricA("GhostArrowDim", "W1Command");
			JudgmentCommand=cmd(finishtweening);
			BrightCommand=cmd(visible,false);
			DimCommand=cmd(visible,true);
		};
		--W1 aka Marvelous Bright Explosion Commands
		NOTESKIN:LoadActor( Var "Button", "Tap Explosion Dim W1" ) .. {
			InitCommand=cmd(diffusealpha,0);
			W1Command=NOTESKIN:GetMetricA("GhostArrowBright", "W1Command");
			JudgmentCommand=cmd(finishtweening);
			BrightCommand=cmd(visible,true);
			DimCommand=cmd(visible,false);
		};
	};
	t[#t+1] = Def.ActorFrame {
		--W2 aka Perfect Dim Explosion Commands
		NOTESKIN:LoadActor( Var "Button", "Tap Explosion Dim W2" ) .. {
			InitCommand=cmd(diffusealpha,0);
			W2Command=NOTESKIN:GetMetricA("GhostArrowDim", "W1Command");
			--HeldCommand=NOTESKIN:GetMetricA("GhostArrowDim", "HeldCommand");
			JudgmentCommand=cmd(finishtweening);
			BrightCommand=cmd(visible,false);
			DimCommand=cmd(visible,true);
		};
		--W2 aka Perfect Bright Explosion Commands
		NOTESKIN:LoadActor( Var "Button", "Tap Explosion Dim W2" ) .. {
			InitCommand=cmd(diffusealpha,0);
			W2Command=NOTESKIN:GetMetricA("GhostArrowBright", "W1Command");
			--HeldCommand=NOTESKIN:GetMetricA("GhostArrowBright", "HeldCommand");
			JudgmentCommand=cmd(finishtweening);
			BrightCommand=cmd(visible,true);
			DimCommand=cmd(visible,false);
		};
	};
	t[#t+1] = Def.ActorFrame {
		--W3 aka Great Dim Explosion Commands
		NOTESKIN:LoadActor( Var "Button", "Tap Explosion Dim W3" ) .. {
			InitCommand=cmd(diffusealpha,0);
			W3Command=NOTESKIN:GetMetricA("GhostArrowDim", "W1Command");
			JudgmentCommand=cmd(finishtweening);
			BrightCommand=cmd(visible,false);
			DimCommand=cmd(visible,true);
		};
		--W3 aka Great Bright Explosion Commands
		NOTESKIN:LoadActor( Var "Button", "Tap Explosion Dim W3" ) .. {
			InitCommand=cmd(diffusealpha,0);
			W3Command=NOTESKIN:GetMetricA("GhostArrowBright", "W1Command");
			JudgmentCommand=cmd(finishtweening);
			BrightCommand=cmd(visible,true);
			DimCommand=cmd(visible,false);
		};
	};
	t[#t+1] = Def.ActorFrame {
		--W4 aka Good Dim Explosion Commands
		NOTESKIN:LoadActor( Var "Button", "Tap Explosion Dim W4" ) .. {
			InitCommand=cmd(diffusealpha,0);
			W4Command=NOTESKIN:GetMetricA("GhostArrowDim", "W1Command");
			JudgmentCommand=cmd(finishtweening);
			BrightCommand=cmd(visible,false);
			DimCommand=cmd(visible,true);
		};
		--W4 aka Good Bright Explosion Commands
		NOTESKIN:LoadActor( Var "Button", "Tap Explosion Dim W4" ) .. {
			InitCommand=cmd(diffusealpha,0);
			W4Command=NOTESKIN:GetMetricA("GhostArrowBright", "W1Command");
			JudgmentCommand=cmd(finishtweening);
			BrightCommand=cmd(visible,true);
			DimCommand=cmd(visible,false);
		};
	};
	t[#t+1] = Def.ActorFrame {
		--W5 aka Boo Dim Explosion Commands
		NOTESKIN:LoadActor( Var "Button", "Tap Explosion Dim W5" ) .. {
			InitCommand=cmd(diffusealpha,0);
			W5Command=NOTESKIN:GetMetricA("GhostArrowDim", "W1Command");
			JudgmentCommand=cmd(finishtweening);
			BrightCommand=cmd(visible,false);
			DimCommand=cmd(visible,true);
		};
		--W5 aka Boo Bright Explosion Commands
		NOTESKIN:LoadActor( Var "Button", "Tap Explosion Dim W5" ) .. {
			InitCommand=cmd(diffusealpha,0);
			W5Command=NOTESKIN:GetMetricA("GhostArrowBright", "W1Command");
			JudgmentCommand=cmd(finishtweening);
			BrightCommand=cmd(visible,true);
			DimCommand=cmd(visible,false);
		};
	};
else
	local dir = Var "Button"
	local side = Var "Controller"
	local isdouble = (GAMESTATE:GetCurrentStyle():GetStyleType() == "StyleType_OnePlayerTwoSides")
	local coladd = ((isdouble) and side == "GameController_2") and 4 or 0 -- fuck
	local rot = {
		Down = 0,
		Left = 90,
		Up = 180,
		Right = 270
	}
	local col = {
		Left = 1 + coladd, Down = 2 + coladd, Up = 3 + coladd, Right = 4 + coladd
	}
	for i = 1,5 do
		t[#t+1] = Def.ActorFrame{
			LoadActor("ITGExpW"..i..".png")..{
				InitCommand = function(self)
					self:diffusealpha(0)
					self:rotationz(rot[dir])
				end,
				JudgmentMessageCommand = function(self, params)
					if params.Player ~= player or params.HoldNoteScore or params.TapNoteScore == "TapNoteScore_HitMine" or params.TapNoteScore == "TapNoteScore_AvoidMine"
					or params.TapNoteScore == "TapNoteScore_Miss" then return end

					if DetermineTimingWindow(params.TapNoteOffset, "ITG") ~= i then return end

					for c, v in pairs(params.Notes) do
						local tnt = v:GetTapNoteType()
						if c == col[dir] and (tnt == "TapNoteType_Tap" or tnt == "TapNoteType_HoldHead" or tnt == "TapNoteType_Lift") then
							self:finishtweening()
							self:playcommand("Flash")
							return
						end
					end
				end,
				JudgmentCommand = cmd(finishtweening),
				FlashCommand = NOTESKIN:GetMetricA("GhostArrowDim", "W1Command")
			}
		}
	end
end

return t;
