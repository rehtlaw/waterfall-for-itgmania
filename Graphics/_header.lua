-- tables of rgba values
local light = {0, 0, 0.25, 0.8}

return Def.ActorFrame{
	Name="Header",

	Def.Quad{
		InitCommand=function(self)
			self:zoomto(_screen.w, 32):vertalign(top):x(_screen.cx)
			self:diffuse(light)
		end
	},

	LoadFont("_wendy small")..{
		Name="HeaderText",
		Text=ScreenString("HeaderText"),
		InitCommand=function(self) self:diffusealpha(0):zoom(WideScale(0.5,0.6)):horizalign(left):xy(10, 15) end,
		OnCommand=function(self) self:sleep(0.1):decelerate(0.33):diffusealpha(1) end,
		OffCommand=function(self) self:accelerate(0.33):diffusealpha(0) end,
   		SetHeaderTextMessageCommand=function(self, params)
			self:settext(params.Text)
		end,
		ResetHeaderTextMessageCommand=function(self)
			self:settext(THEME:GetString(SCREENMAN:GetTopScreen():GetName(), "HeaderText"))
		end
	}
}
