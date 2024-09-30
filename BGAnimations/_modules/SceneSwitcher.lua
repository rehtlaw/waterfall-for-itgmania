local screen = ...

local t = Def.ActorFrame {}

-- Scene Switcher Text File
t[#t+1] = Def.ActorFrame {
    InitCommand=function(self)
		filepath = "Save/SMScene.txt"
		f = RageFileUtil.CreateRageFile()
		f:Open(filepath, 2)
		f:Write(screen) 
		f:Close()
    end
}

-- Scene Switcher text file - What game mode
t[#t+1] = Def.ActorFrame {
    InitCommand=function(self)
		local gamemode
		local style = GAMESTATE:GetCurrentStyle()
		local styleType = style:GetStyleType()

		if (styleType == "StyleType_OnePlayerTwoSides") then gamemode = "Doubles" end
		if (styleType == "StyleType_TwoPlayersTwoSides") then gamemode = "2p" end
		if (styleType == "StyleType_OnePlayerOneSide") then 
			local Players = GAMESTATE:GetHumanPlayers()	
			if (Players[1] == "PlayerNumber_P1") then gamemode = "p1"
			else gamemode = "p2"
			end
		end
		filepath = "Save/GameMode.txt"
		f = RageFileUtil.CreateRageFile()
		f:Open(filepath, 2)
		f:Write(gamemode) 
		f:Close()
    end
}

return t
