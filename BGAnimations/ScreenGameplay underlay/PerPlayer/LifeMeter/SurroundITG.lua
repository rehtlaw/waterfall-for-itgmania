local player = ...
local pn = tonumber(player:sub(-1))
local mods = SL["P"..pn].ActiveModifiers

local af = Def.ActorFrame{
	Name="LifeMeter_"..ToEnumShortString(player),
	InitCommand=function(self)
		self:xy(0,0)
	end,
	ITGLifeChangedMessageCommand=function(self,params)
		if (params.pn == pn) then					
			self:playcommand("ChangeSize", {CropAmount=(1-params.newlife) })
		end
	end,
}

-- if double style, we want two quads flanking the left/right sides of the screen that move in unison
if GAMESTATE:GetCurrentStyle():GetName():gsub("8","") == "double" then
	af[#af+1] = Def.Quad{
		Name="Left",
		InitCommand=function(self)
			self:vertalign(top):horizalign(left)
				:zoomto( _screen.w/2, _screen.h-80 ):diffuse(0.2,0.2,0.2,1)
				:faderight(0.8):xy(0, 80)
		end,
		OnCommand=function(self)
			local startlife = 1-WF.ITGLife[pn]
			self:croptop(startlife) 
		end,
		ChangeSizeCommand=function(self, params)
			self:finishtweening():smooth(0.2):croptop(params.CropAmount)
		end,
		DeadCommand=function(self)
			self:finishtweening():smooth(0.2):croptop(1)
		end
	}

	af[#af+1] = Def.Quad{
		Name="Right",
		InitCommand=function(self)
			self:vertalign(top):horizalign(right)
				:zoomto( _screen.w/2, _screen.h-80 ):diffuse(0.2,0.2,0.2,1)
				:fadeleft(0.8):xy(_screen.w, 80)
		end,
		OnCommand=function(self)
			local startlife = 1-WF.ITGLife[pn]
			self:croptop(startlife) 
		end,
		ChangeSizeCommand=function(self, params)
			self:finishtweening():smooth(0.2):croptop(params.CropAmount)
		end,
		DeadCommand=function(self)
			self:finishtweening():smooth(0.2):croptop(1)
		end
	}

----if single or versus style, we want one uniquely-moving quad per player
else
	af[#af+1] = Def.Quad{
		InitCommand=function(self)
			self:vertalign(top)
				:zoomto( _screen.w/2, _screen.h-80 )
			if player == PLAYER_1 then
				self:horizalign(left):diffuse(0.2,0.2,0.2,1):faderight(0.8):xy(0, 80)
			else
				self:horizalign(right):diffuse(0.2,0.2,0.2,1):fadeleft(0.8):xy(_screen.w, 80)
			end
		end,
		OnCommand=function(self)
			local startlife = 1-WF.ITGLife[pn]
			self:croptop(startlife) 
		end,
		ChangeSizeCommand=function(self, params)
			self:finishtweening():smooth(0.2):croptop(params.CropAmount)
		end,
		DeadCommand=function(self)
			self:finishtweening():smooth(0.2):croptop(1)
		end
	}
end

return af