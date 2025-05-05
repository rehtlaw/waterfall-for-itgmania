local args = ...
local player = args.player
local side = player
if args.sec then side = (player == PLAYER_1) and PLAYER_2 or PLAYER_1 end
local pn = tonumber(player:sub(-1))

local mods = SL[ToEnumShortString(player)].ActiveModifiers

local percent = WF.ITGScore[pn]
local expercent = WF.GetEXScore(player)

-- If EX scoring is enabled, always show instead of the marquee
local displayExScore = mods.EXScoring

local t = Def.ActorFrame{
	Name="PercentageContainer"..ToEnumShortString(player),
	OnCommand=function(self)
		self:y( _screen.cy-12 )
	end,
	-- dark background quad behind player percent score
	Def.Quad{
		InitCommand=function(self)
			self:diffuse(color("#101519")):zoomto(158.5, 88)
			self:horizalign(side==PLAYER_1 and left or right)
			self:x(150 * (side == PLAYER_1 and -1 or 1))
		end
	},

	-- Always show EX score big on top with ITG score smaller below
	Def.ActorFrame {
		LoadFont("_wendy white")..{
			Name="EXPercent",
			Text=expercent,
			InitCommand=function(self)
				self:horizalign(right):zoom(0.585)
				self:x( (side == PLAYER_1 and 1.5 or 141))
				self:y(-15)
				self:diffuse(SL.JudgmentColors.ITG[1])
			end
		},
	},

	-- smaller ITG score
	Def.ActorFrame {
		LoadFont("_wendy white")..{
			Name="Percent",
			Text=percent,
			InitCommand=function(self)
				self:horizalign(right):zoom(0.4)
				self:x( ((side == PLAYER_1) and -0.5) or 139)
				self:y(25)
			end
		}
	},
	-- ITG label
	Def.ActorFrame {
		LoadFont("_wendy white")..{
			Name="PercentLabel",
			Text="ITG",
			InitCommand=function(self)
				self:zoom(0.3):horizalign(right)
				self:x( (side == PLAYER_1 and -103) or 40)
				self:y(26)
			end
		}
	}
}

return t

