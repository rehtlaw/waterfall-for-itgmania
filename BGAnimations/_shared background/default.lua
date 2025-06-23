local af = Def.ActorFrame{}

-- a simple Quad to serve as the backdrop
af[#af+1] = Def.Quad{
	InitCommand=function(self) self:FullScreen():Center():diffuse( Color.Black ) end
}

-- add common background here
--af[#af+1] = LoadActor("./wf07still.png")..{ -- If you are having performance issues, use this one instead
--af[#af+1] = LoadActor("./hd277.mp4")..{
af[#af+1] = LoadActor("./SRPG.mp4")..{
	InitCommand = function(self)
		self:zoom(SCREEN_HEIGHT/1080)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
	end
}

af[#af+1] = Def.Quad{
	ScreenChangedMessageCommand = function(self)
		self:visible(SCREENMAN:GetTopScreen():GetName() ~= "ScreenTitleMenu")
	end,
	InitCommand = function(self)
		self:zoom(SCREEN_WIDTH, SCREEN_HEIGHT)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		self:diffuse(0,0,0,0.4)
	end
}

return af
