local args = ...

local lbind = args.index
local player = args.player
local pn = tonumber(player:sub(-1))
local mods = SL["P"..pn].ActiveModifiers

local s = (mods.LifeMeterType == "Standard") and true or false
local c = PREFSMAN:GetPreference("Center1Player") and #GAMESTATE:GetHumanPlayers() == 1
local ws = IsUsingWideScreen()

-- Standard lifebar position/size
local w = 136
local h = 18
local _x = _screen.cx + WideScale(238, 288) * (pn*2-3)
local ystart = 20
local rot = 0
local voffset = 0
local yoffset = 0
local startlifew = w/2
local startlifeh = h

if not s then -- Vertical Lifebar position/size
	w = 250
	h = 16
	startlifew = w/2
	startlifeh = h
	_x = GetNotefieldX(player) + (GetNotefieldWidth(player)/2 + 16) * (pn*2-3)
	ystart = 275
	voffset = w/2
	yoffset = 125
	rot = -90
end

if GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred"):UsingReverse() and s then
	ystart = SCREEN_HEIGHT - 14
end

local swoosh, velocity

local c = WF.LifeBarColors[lbind]

local Update = function(self)
	velocity = -GAMESTATE:GetSongBPS()/2
	if GAMESTATE:GetSongFreeze() then velocity = 0 end
	if swoosh then swoosh:texcoordvelocity(velocity,0) end
end

local meter = Def.ActorFrame{

	InitCommand=function(self) self:y(ystart):SetUpdateFunction(Update):visible(false) end,
	OnCommand=function(self)
		self:visible(true)
		self:diffusealpha(WF.PreferredLifeBar[pn] == lbind and 1 or 0)
	end,

	ShowCommand = function(self)
		self:linear(0.2)
		self:diffusealpha(1)
		--self:visible(true)
	end,
	HideCommand = function(self)
		self:linear(0.2)
		self:diffusealpha(0)
		--self:visible(false)
	end,

	WFLifeBarFailedMessageCommand = function(self, params)
		if params.pn ~= pn then return end
		if params.ind > WF.PreferredLifeBar[pn] then return end
		if params.ind == lbind and lbind ~= WF.LowestLifeBarToFail[pn] then
			self:finishtweening()
			self:queuecommand("Hide")
		elseif params.ind == lbind + 1 and lbind >= WF.LowestLifeBarToFail[pn] then
			self:finishtweening()
			self:queuecommand("Show")
		end
	end,

	-- frame
	Def.Quad{ InitCommand=function(self) self:x(_x):zoomto(w+4, h+4):rotationz(rot) end },
	Def.Quad{ InitCommand=function(self) self:x(_x):zoomto(w, h):diffuse(0,0,0,1):rotationz(rot) end },

	-- the Quad that changes width/color depending on current Life
	Def.Quad{
		Name="MeterFill_"..lbind;
		InitCommand=function(self) self:zoomto(w,h):y(yoffset):diffuse(c[1],c[2],c[3],1):horizalign(left):rotationz(rot) end,
		OnCommand=function(self) self:x( _x - w/2 + voffset ) end,

		-- when the engine broadcasts that the player's LifeMeter value has changed
		-- change the width of this MeterFill Quad to accommodate
		WFLifeChangedMessageCommand=function(self,params)
			if (params.pn == pn and params.ind == lbind) then
				local life = (params.newlife / WF.LifeBarMetrics[lbind].MaxValue) * w
				self:finishtweening()
				self:decelerate(0.1):zoomx( life )
			end
		end,
	},

	-- a simple scrolling gradient texture applied on top of MeterFill
	LoadActor("swoosh.png")..{
		Name="MeterSwoosh"..lbind,
		InitCommand=function(self)
			swoosh = self

			self:zoomto(w,h)
				 :diffusealpha(0.2)
				 :horizalign( left )
				 :y(yoffset)
		end,
		OnCommand=function(self)
			self:x(_x - w/2 + voffset):rotationz(rot)
			self:customtexturerect(0,0,1,1)
			--texcoordvelocity is handled by the Update function below
		end,

		-- life-changing
		-- adjective
		--  /ˈlaɪfˌtʃeɪn.dʒɪŋ/
		-- having an effect that is strong enough to change someone's life
		-- synonyms: compelling, life-altering, puissant, blazing
		WFLifeChangedMessageCommand=function(self,params)
			if (params.pn == pn and params.ind == lbind) then
				local life = (params.newlife / WF.LifeBarMetrics[lbind].MaxValue) * w
				self:finishtweening()
				self:decelerate(0.1):zoomto( life, h )
			end
		end
	}
}

return meter

-- copyright 2008-2012 AJ Kelly/freem.
-- do not use this code in your own themes without my permission.