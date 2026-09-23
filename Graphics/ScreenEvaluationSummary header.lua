local af = Def.ActorFrame{}

af[#af+1] = LoadActor( THEME:GetPathG("", "_header.lua") )

af[#af+1] = LoadFont("raxye/_main")..{
	Name="SummaryText",
	Text=GAMESTATE:IsCourseMode() and "MARATHON" or "STANDARD",
	InitCommand=function(self)
		self:diffusealpha(0):zoom( WideScale(0.25,0.3)):halign(1):y(13)

		-- move the text further left if MenuTimer is enabled
		if PREFSMAN:GetPreference("MenuTimer") then
			self:x(_screen.w - 70)
		else
			self:x(_screen.w - 10)
		end
	end,
	OnCommand=function(self)
		self:sleep(0.1):decelerate(0.33):diffusealpha(1)
	end
}

return af
