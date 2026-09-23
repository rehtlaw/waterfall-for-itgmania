local player = ...
local pn = ToEnumShortString(player)
local mods = SL[pn].ActiveModifiers
local center1p = PREFSMAN:GetPreference("Center1Player")

if mods.HideScore then return end

local displayExScore = mods.EXScoring
local style = GAMESTATE:GetCurrentStyle()
local styleType = style:GetStyleType()

local twoPlayer = styleType == "StyleType_TwoPlayersTwoSides" and true or false
local doubles = styleType == "StyleType_OnePlayerTwoSides" and true or false

if #GAMESTATE:GetHumanPlayers() > 1
and mods.NPSGraphAtTop
then return end -- [TODO] honestly we can still accommodate this if we try

local useitg = mods.SimulateITGEnv
local itgmaxdp
if useitg then
	itgmaxdp = WF.GetITGMaxDP(player)
end

local ystart = 56
if GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred"):UsingReverse() then
	ystart = SCREEN_HEIGHT - 44
end

local pos = {
	[PLAYER_1] = { x=(_screen.cx - _screen.w/4.3),  y=ystart },
	[PLAYER_2] = { x=(_screen.cx + _screen.w/2.75), y=ystart },
}

-- 0.7.6
-- 4:3 + center 1 player + step stats is selectable but does not get rendered.
-- When using NPSGraphAtTop mod, the scores should just go weird
-- NPSGraphAtTop doesn't obstruct the view in center 1 player mode
-- so I'm just going to fix the score positions in the same place
-- regardless of mod combo
-- Zarzob

--TODO create primary, secondary, and tertiary positions for score text to appear
-- and apply a position based on criteria.
-- This will make it much easier to deal with

-- TODO fix score positioning in reverse mode

local dance_points, percent
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)

local af = Def.ActorFrame{
	Name=pn.."Score",
	-- ITG score
	LoadFont("raxye/_numbers")..{
		--Name=pn.."Score",
		InitCommand=function(self)
			self:valign(1):halign(1)
			self:zoom(0.28)

			-- assume "normal" score positioning first, but there are many reasons it will need to be moved
			self:xy( pos[player].x, pos[player].y )
			
			if (not (twoPlayer and displayExScore)) and not (doubles and displayExScore and mods.NPSGraphAtTop)  then self:settext("0.00") end
			
			if mods.NPSGraphAtTop and not center1p then
				-- if NPSGraphAtTop and Step Statistics, move the score down
				-- into the stepstats pane under the jugdgment breakdown
				if mods.DataVisualizations=="Step Statistics" then
					if player==PLAYER_1 then
						self:x( _screen.w - WideScale(15, center1p and 9 or 67) )
					else
						self:x( WideScale(306, center1p and 280 or 358) )
					end

					local pushdown = (mods.FAPlus > 0) and 16 or 0
					self:y( _screen.cy + 40 + pushdown )

				-- if NPSGraphAtTop but not Step Statistics
				else
					-- if not Center1Player, move the score right or left
					-- within the normal gameplay header to where the
					-- other player's score would be if this were versus
					if not center1p then
						self:x( pos[ OtherPlayer[player] ].x )
						self:y( pos[ OtherPlayer[player] ].y )
					end
					-- if Center1Player, no need to move the score
				end
			end
		end,
		JudgmentMessageCommand=function(self)
			if (not (twoPlayer and displayExScore)) and not (doubles and displayExScore and mods.NPSGraphAtTop) then self:queuecommand("RedrawScore") end
		end,
		RedrawScoreCommand=function(self)
			dance_points = (not useitg) and pss:GetPercentDancePoints() or WF.GetITGPercentDP(player, itgmaxdp)
			--SCREENMAN:SystemMessage(tostring(GAMESTATE:GetCurrentSteps(player):GetRadarValues(player):GetValue("RadarCategory_TapsAndHolds")))
			percent = FormatPercentScore( dance_points ):sub(1,-2)
			self:settext(percent)
		end
	},
	-- EX Percent
	LoadFont("raxye/_numbers")..{
		--Name=pn.."EXScore",
		InitCommand=function(self)
			if not displayExScore then return end 
			self:valign(1):halign(1)
			self:zoom(0.28)
			self:diffuse(SL.JudgmentColors.ITG[1])
			
			-- 2 player mode only has room for 1 score. if ex score is on then show that in place of regular score
			-- if NPS graph is on then hide both
			
			if displayExScore and not (twoPlayer and mods.NPSGraphAtTop) then self:settext("0.00") end			
			-- TODO: if 2 player step stats is on, then we can show the score there
			
			-- assume "normal" score position first, and move for certain conditions
			-- EX score is in a secondary position due to ITG score taking priority
			
			self:y( pos[player].y )
			
			
			if twoPlayer and not mods.NPSGraphAtTop then self:x( pos[player].x)
			
			else 
				if player==PLAYER_1 then
					self:x( _screen.w - WideScale(15, center1p and 9 or 67) )
				else
					self:x( WideScale(306, center1p and 280 or 358) )
				end
				
				if center1p then self:x(pos[player].x) else self:x( pos[ OtherPlayer[player] ].x ) end
				
				if ((mods.NPSGraphAtTop and mods.DataVisualizations == "None") or center1p) and not doubles  then
						self:addy(45)
						
					
					-- TODO: extend the header box for the EX score
					-- TODO: Deal with center 1 player
					--else
					--	-- if not Center1Player, move the score right or left
					--	-- within the normal gameplay header to where the
					--	-- other player's score would be if this were versus
					--	if not center1p then
					--		self:x( pos[ OtherPlayer[player] ].x )
					--		self:y( pos[ OtherPlayer[player] ].y )
					--	end
					--	-- if Center1Player, no need to move the score
					--end
			
			end

			if GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred"):UsingReverse() then
				self:y(56)
			end
			
			end
		end,
		JudgmentMessageCommand=function(self) 
			if displayExScore then self:queuecommand("RedrawScore") end
		end,
		RedrawScoreCommand=function(self)			
			local expercent = WF.GetEXScore(player)
			self:settext(expercent)
		end
	}
}

return af
