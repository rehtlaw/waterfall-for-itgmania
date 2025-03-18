WF.InitHashCache()

local af = Def.ActorFrame{ InitCommand=function(self) self:Center() end }

-- check SM5 version, current game (dance, pump, etc.), and RTT support
af[#af+1] = LoadActor("./CompatibilityChecks.lua")

-- set stats prefix and leave it alone
PROFILEMAN:SetStatsPrefix("WF-")
WF.SwitchPrefixFlag = false
if not WF.MachineProfileStats then WF.LoadMachineProfileStats() end

-- -----------------------------------------------------------------------

local slc = SL.DefaultColor

-- semitransparent black quad as background for 7 decorative arrows
af[#af+1] = Def.Quad{
	InitCommand=function(self) self:zoomto(_screen.w,0):diffuse(Color.Black) end,
	OnCommand=function(self)
		-- go to hash cache screen if needed #HashCash
		if #WF.NewChartsToCache > 0 and (not UNSUPPORTED_VERSION) then
			WF.HashCacheNextScreen = "ScreenInit"
			SCREENMAN:SetNewScreen("ScreenBuildHashCache")
		end
		self:accelerate(0.3):zoomtoheight(128):diffusealpha(0.9):sleep(2.5)
	end,
	OffCommand=function(self) self:accelerate(0.3):zoomtoheight(0) end
}

-- loop to add 7 SM5 logo arrows to the primary ActorFrame
for i=1,7 do

	local arrow = Def.ActorFrame{
		InitCommand=function(self) self:x((i-4) * 50):diffusealpha(0) end,
		OnCommand=function(self)
			self:sleep(i*0.1 + 0.2)
			self:linear(0.75):diffusealpha(1):linear(0.75):diffusealpha(0)
			self:queuecommand("Hide")
		end,
		HideCommand=function(self) self:visible(false) end,
	}

	-- desaturated SM5 logo
	arrow[#arrow+1] = LoadActor("logo.png")..{
		InitCommand=function(self) self:zoom(0.1):diffuse(GetHexColor(slc-i-3)) end,
	}

	af[#af+1] = arrow
end

af[#af+1] = LoadFont("Common Normal")..{
	Text=ScreenString("ThemeDesign"),
	InitCommand=function(self) self:diffuse(GetHexColor(slc)):diffusealpha(0) end,
	OnCommand=function(self) self:sleep(3):linear(0.25):diffusealpha(1) end,
	OffCommand=function(self) self:linear(0.25):diffusealpha(0) end,
}

return af
