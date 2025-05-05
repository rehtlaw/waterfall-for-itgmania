local args = ...
local player = args.player
local side = player
if args.sec then side = (player == PLAYER_1) and PLAYER_2 or PLAYER_1 end
local pn = tonumber(player:sub(-1))

local mods = SL[ToEnumShortString(player)].ActiveModifiers

local percent = WF.ITGScore[pn]
local expercent = WF.GetEXScore(player)

local stats = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
local PercentDP = stats:GetPercentDancePoints()
local percent = FormatPercentScore(PercentDP)
-- Format the Percentage string, removing the % symbol
percent = string.format("%.2f",percent:gsub("%%", ""))

-- If EX scoring is enabled, always show instead of the marquee
local displayExScore = mods.EXScoring

local t = Def.ActorFrame{
	Name="PercentageContainer"..ToEnumShortString(player),
	OnCommand=function(self)
		self:y(_screen.cy - 26)
		if displayExScore then
			self:y(_screen.cy-12)
		end
	end,
	SendEventDataMessageCommand=function(self, eventData)
		self:y(_screen.cy - 12)
		-- local itlData = eventData[pn]["itl"]

		-- local score = expercent
		-- local scoreDelta = itlData["scoreDelta"]/100.0

		-- local steps = GAMESTATE:GetCurrentSteps(player)
		-- local chartName = steps:GetChartName()

		-- local currentPoints = itlData["topScorePoints"]
		-- local previousPoints = itlData["prevTopScorePoints"]
		-- local pointDelta = currentPoints - previousPoints

		-- local totalPasses = itlData["totalPasses"]

		-- local currentRankingPointTotal = itlData["currentRankingPointTotal"]
		-- local previousRankingPointTotal = itlData["previousRankingPointTotal"]
		-- local rankingDelta = currentRankingPointTotal - previousRankingPointTotal

		-- local currentSongPointTotal = itlData["currentSongPointTotal"]
		-- local previousSongPointTotal = itlData["previousSongPointTotal"]
		-- local totalSongDelta = currentSongPointTotal - previousSongPointTotal

		-- local currentExPointTotal = itlData["currentExPointTotal"]
		-- local previousExPointTotal = itlData["previousExPointTotal"]
		-- local totalExDelta = currentExPointTotal - previousExPointTotal

		-- local currentPointTotal = itlData["currentPointTotal"]
		-- local previousPointTotal = itlData["previousPointTotal"]
		-- local totalDelta = currentPointTotal - previousPointTotal
	end,
	-- dark background quad behind player percent score
	Def.Quad{
		InitCommand=function(self)
			self:diffuse(color("#101519")):zoomto(158.5, 60)
			self:horizalign(side==PLAYER_1 and left or right)
			self:x(150 * (side == PLAYER_1 and -1 or 1))
			if displayExScore then
				self:zoomto(158.5, 88)
			end
		end,
		SendEventDataMessageCommand=function(self)
			self:zoomto(158.5, 88)
		end
	},

	-- Only WF percent
	Def.ActorFrame {
		LoadFont("_wendy white")..{
			Name="Percent",
			Text=percent,
			InitCommand=function(self)
				self:horizalign(right):zoom(0.585)
				self:x( (side == PLAYER_1 and 1.5 or 141))
				if displayExScore then
					self:y(-15)
				end
			end,
			SendEventDataMessageCommand = function(self)
				self:visible(false)
			end,
		},
		Def.ActorFrame {
			Name="EventScore",
			InitCommand=function(self)
				self:visible(false)
			end,
			SendEventDataMessageCommand=function(self)
				self:visible(true)
			end,
			Def.ActorFrame{
				LoadFont("_wendy white")..{
						Name="EarnedPoints",
						Text="",
						InitCommand=function(self)
							self:horizalign(right):zoom(0.5)
							self:x( (side == PLAYER_1 and 1.5 or 141))
							self:y(-22)
						end,
						SendEventDataMessageCommand=function(self, eventData)
							local itlData = eventData[pn]["itl"]
							local points = itlData["topScorePoints"]
							self:settext(points)
							self:visible(true)
						end
					},
				Def.ActorFrame{
					LoadFont("_wendy white")..{
						Name="TotalPoints",
						Text="",
						InitCommand=function(self)
							self:horizalign(right):zoom(0.3)
							self:x( (side == PLAYER_1 and 1.5 or 141))
							self:y(12)
							self:diffuse(color("#bbbbbb"))
						end,
						SendEventDataMessageCommand=function(self, eventData)
							local itlData = eventData[pn]["itl"]
							local points = itlData["maxPoints"]
							self:settext(points)
							self:visible(true)
						end
					},
					LoadFont("Common Normal")..{
						Name="TotalPointsSlash",
						Text="/",
						InitCommand=function(self)
							local parent = self:GetParent():GetChild("TotalPoints")
							self:horizalign(right):zoom(1.2)
							-- self:x(parent:GetX() - (parent:GetWidth() * 2))
							self:x(-70)
							self:y(12)
							self:diffuse(color("#bbbbbb"))
						end,
						SendEventDataMessageCommand=function(self, eventData)
							self:visible(true)
						end
					}
				}
			}
		},
	}
}

if displayExScore then
	t[#t+1] = Def.ActorFrame {
		-- smaller EX score
		LoadFont("_wendy white")..{
			Name="Percent",
			Text=expercent,
			InitCommand=function(self)
				self:horizalign(right):zoom(0.4)
				self:x( ((side == PLAYER_1) and -0.5) or 139)
				self:y(25)
				self:diffuse(SL.JudgmentColors.ITG[1])
			end,
			SendEventDataMessageCommand=function(self)
				self:visible(false)
			end
		}
	}
	t[#t+1] = Def.ActorFrame {
		-- EX label
		LoadFont("_wendy white")..{
			Name="PercentLabel",
			Text="EX",
			InitCommand=function(self)
				self:zoom(0.3):horizalign(right)
				self:x( (side == PLAYER_1 and -113) or 30)
				self:y(26)
				self:diffuse(SL.JudgmentColors.ITG[1])
			end,
			SendEventDataMessageCommand=function(self)
				self:visible(false)
			end
		}
	}
end

return t

