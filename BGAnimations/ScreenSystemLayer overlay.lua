-- This is mostly copy/pasted directly from SM5's _fallback theme with
-- very minor modifications.

local function CreditsText( pn )
	return LoadFont("Common Normal") .. {
		InitCommand=function(self)
			self:visible(false)
			self:name("Credits" .. PlayerNumberToString(pn))
			ActorUtil.LoadAllCommandsAndSetXY(self,Var "LoadingScreen")
		end,
		UpdateTextCommand=function(self)
			local str = ScreenSystemLayerHelpers.GetCreditsMessage(pn)
			self:settext(str)
		end,
		UpdateVisibleCommand=function(self)
			local screen = SCREENMAN:GetTopScreen()
			local bShow = true
			if screen then
				bShow = THEME:GetMetric( screen:GetName(), "ShowCreditDisplay" )
			end
			self:visible( bShow )
		end
	}
end


local t = Def.ActorFrame{}

-- Aux
t[#t+1] = LoadActor(THEME:GetPathB("ScreenSystemLayer","aux"))

-- Credits
t[#t+1] = Def.ActorFrame {
 	CreditsText( PLAYER_1 );
	CreditsText( PLAYER_2 );
}

local SystemMessageText = nil

-- SystemMessage Text
t[#t+1] = Def.ActorFrame {
	SystemMessageMessageCommand=function(self, params)
		SystemMessageText:settext( params.Message )
		self:playcommand( "On" )
		if params.NoAnimate then
			self:finishtweening()
		end
		self:playcommand( "Off" )
	end,
	HideSystemMessageMessageCommand=function(self) self:finishtweening() end,

	Def.Quad {
		InitCommand=function(self)
			self:zoomto(_screen.w, 30):horizalign(left):vertalign(top)
				:diffuse(Color.Black):diffusealpha(0)
		end,
		OnCommand=function(self)
			self:finishtweening():diffusealpha(0.85)
				:zoomto(_screen.w, (SystemMessageText:GetHeight() + 16) * WideScale(1, 0.8) )
		end,
		OffCommand=function(self) self:sleep(3.33):linear(0.5):diffusealpha(0) end,
	},

	LoadFont("Common Normal")..{
		Name="Text",
		InitCommand=function(self)
			self:maxwidth(_screen.w-20):horizalign(left):vertalign(top)
				:xy(10, 10):diffusealpha(0):zoom(WideScale(1, 0.8))
			SystemMessageText = self
		end,
		OnCommand=function(self) self:finishtweening():diffusealpha(1) end,
		OffCommand=function(self) self:sleep(3):linear(0.5):diffusealpha(0) end,
	}
}

-- Wendy CreditText at lower-center of screen
t[#t+1] = LoadFont("_wendy small")..{
	InitCommand=function(self) self:xy(_screen.cx, _screen.h-16):zoom(0.5):horizalign(center) end,

	OnCommand=function(self) self:playcommand("Refresh") end,
	ScreenChangedMessageCommand=function(self) self:playcommand("Refresh") end,
	CoinModeChangedMessageCommand=function(self) self:playcommand("Refresh") end,
	CoinsChangedMessageCommand=function(self) self:playcommand("Refresh") end,

	RefreshCommand=function(self)

		local screen = SCREENMAN:GetTopScreen()

		-- if this screen's Metric for ShowCreditDisplay=false, then hide this BitmapText actor
		-- PS: "ShowCreditDisplay" isn't a real Metric as far as the engine is concerned
		-- I invented it for Simply Love and it has (understandably) confused other themers.
		-- Sorry about this.
		if screen then
			self:visible( THEME:GetMetric( screen:GetName(), "ShowCreditDisplay" ) )
		end

		if PREFSMAN:GetPreference("EventMode") then
			self:settext( THEME:GetString("ScreenSystemLayer", "EventMode") )

		elseif GAMESTATE:GetCoinMode() == "CoinMode_Pay" then
			local credits = GetCredits()
			local text = THEME:GetString("ScreenSystemLayer", "Credits")..'  '

			text = text..credits.Credits..'  '

			if credits.CoinsPerCredit > 1 then
				text = text .. credits.Remainder .. '/' .. credits.CoinsPerCredit
			end
			self:settext(text)

		elseif GAMESTATE:GetCoinMode() == "CoinMode_Free" then
			self:settext( THEME:GetString("ScreenSystemLayer", "FreePlay") )

		elseif GAMESTATE:GetCoinMode() == "CoinMode_Home" then
			self:settext('')
		end
	end
}



-- -----------------------------------------------------------------------
-- The GrooveStats service info pane.
-- We put this in ScreenSystemLayer because if people move through the menus too fast,
-- it's possible that the available services won't be updated before one starts the set.
-- This allows us to set available services "in the background" as we're moving
-- through the menus.

local NewSessionRequestProcessor = function(res, gsInfo)
	if gsInfo == nil then return end
	
	local groovestats = gsInfo:GetChild("GrooveStats")
	local service1 = gsInfo:GetChild("Service1")
	local service2 = gsInfo:GetChild("Service2")
	local service3 = gsInfo:GetChild("Service3")

	service1:visible(false)
	service2:visible(false)
	service3:visible(false)

	SL.GrooveStats.IsConnected = false
	if res.error or res.statusCode ~= 200 then
		local error = res.error and ToEnumShortString(res.error) or nil
		if error == "Timeout" then
			groovestats:settext("Timed Out")
		elseif error or (res.statusCode ~= nil and res.statusCode ~= 200) then
			local text = ""
			if error == "Blocked" then
				text = "Access to GrooveStats Host Blocked"
			elseif error == "CannotConnect" then
				text = "Machine Offline"
			elseif error == "Timeout" then
				text = "Request Timed Out"
			else
				text = "Failed to Load 😞"
			end
			service1:settext(text):visible(true)

			-- These default to false, but may have changed throughout the game's lifetime.
			-- It doesn't hurt to explicitly set them to false.
			SL.GrooveStats.GetScores = false
			SL.GrooveStats.Leaderboard = false
			SL.GrooveStats.AutoSubmit = false
			groovestats:settext("❌ GrooveStats")

			DiffuseEmojis(service1:ClearAttributes())
		end
		DiffuseEmojis(groovestats:ClearAttributes())
		return
	end

	local data = JsonDecode(res.body) 
	if data == nil then return end

	if data["servicesAllowed"] ~= nil then
		local services = data["servicesAllowed"]
		local serviceCount = 1

		if services["playerScores"] ~= nil then
			if services["playerScores"] then
				SL.GrooveStats.GetScores = true
			else
				local curServiceText = gsInfo:GetChild("Service"..serviceCount)
				curServiceText:settext("❌ Get Scores"):visible(true)
				serviceCount = serviceCount + 1
				SL.GrooveStats.GetScores = false
			end
		end

		if services["playerLeaderboards"] ~= nil then
			if services["playerLeaderboards"] then
				SL.GrooveStats.Leaderboard = true
			else
				local curServiceText = gsInfo:GetChild("Service"..serviceCount)
				curServiceText:settext("❌ Leaderboard"):visible(true)
				serviceCount = serviceCount + 1
				SL.GrooveStats.Leaderboard = false
			end
		end

		if services["scoreSubmit"] ~= nil then
			if services["scoreSubmit"] then
				SL.GrooveStats.AutoSubmit = true
			else
				local curServiceText = gsInfo:GetChild("Service"..serviceCount)
				curServiceText:settext("❌ Auto-Submit"):visible(true)
				serviceCount = serviceCount + 1
				SL.GrooveStats.AutoSubmit = false
			end
		end
	end

	-- All services are enabled, display a green check.
	if SL.GrooveStats.GetScores and SL.GrooveStats.Leaderboard and SL.GrooveStats.AutoSubmit then
		if ThemePrefs.Get("UseBoogieStats") then
			if string.find(PREFSMAN:GetPreference("HttpAllowHosts"), "boogiestats.andr.host") then
				groovestats:settext("✔ BoogieStats")
			else
				groovestats:settext("✔ GrooveStats (BoogieStats host not in allow list)")
			end
		else
			groovestats:settext("✔ GrooveStats")
		end
        SL.GrooveStats.IsConnected = true
	-- All services are disabled, display a red X.
	elseif not SL.GrooveStats.GetScores and not SL.GrooveStats.Leaderboard and not SL.GrooveStats.AutoSubmit then
		groovestats:settext("❌ GrooveStats")
		-- We would've displayed the individual failed services, but if they're all down then hide the group.
		service1:visible(false)
		service2:visible(false)
		service3:visible(false)
	-- Some combination of the two, we display a caution symbol.
	else
		groovestats:settext("⚠️ GrooveStats")
        SL.GrooveStats.IsConnected = true
	end

end

local TextColor = Color.White

t[#t+1] = Def.ActorFrame{
	Name="GrooveStatsInfo",
	InitCommand=function(self)
		-- Put the info in the top right corner.
		self:zoom(0.8):x(10):y(15)
	end,
	ScreenChangedMessageCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen:GetName() == "ScreenTitleMenu" then
			self:queuecommand("Reset")
			self:diffusealpha(0):sleep(0.2):linear(0.4):diffusealpha(1):visible(true)
            self:queuecommand("SendRequest")
		else
			self:visible(false)
		end
	end,

	LoadFont("Common Normal")..{
		Name="GrooveStats",
		Text="     GrooveStats",
		InitCommand=function(self)
            self:visible(ThemePrefs.Get("EnableGrooveStats"))
            self:diffuse(TextColor):horizalign(left)
        end,
		ResetCommand=function(self)
            self:visible(ThemePrefs.Get("EnableGrooveStats"))
            if ThemePrefs.Get("EnableBoogieStats") then
				if string.find(PREFSMAN:GetPreference("HttpAllowHosts"), "boogiestats.andr.host") then
					self:settext("     BoogieStats")
				else
					self:settext("     GrooveStats (BoogieStats host not in allow list)")
				end
			else
				self:settext("     GrooveStats")
			end
        end
	},

	LoadFont("Common Normal")..{
		Name="Service1",
		Text="",
		InitCommand=function(self) self:diffuse(TextColor):visible(true):addy(18):horizalign(left) end,
		ResetCommand=function(self) self:settext("") end
	},

	LoadFont("Common Normal")..{
		Name="Service2",
		Text="",
		InitCommand=function(self) self:diffuse(TextColor):visible(true):addy(36):horizalign(left) end,
		ResetCommand=function(self) self:settext("") end
	},

	LoadFont("Common Normal")..{
		Name="Service3",
		Text="",
		InitCommand=function(self) self:diffuse(TextColor):visible(true):addy(54):horizalign(left) end,
		ResetCommand=function(self) self:settext("") end
	},

	RequestResponseActor(5, 0)..{
		SendRequestCommand=function(self)
			if ThemePrefs.Get("EnableGrooveStats") then
				-- These default to false, but may have changed throughout the game's lifetime.
				-- Reset these variable before making a request.
				SL.GrooveStats.GetScores = false
				SL.GrooveStats.Leaderboard = false
				SL.GrooveStats.AutoSubmit = false
				self:playcommand("MakeGrooveStatsRequest", {
					endpoint="new-session.php?chartHashVersion="..SL.GrooveStats.ChartHashVersion,
					method="GET",
					timeout=10,
					callback=NewSessionRequestProcessor,
					args=self:GetParent()
				})
			end
		end
	}
}

-- -----------------------------------------------------------------------
-- Loads the UnlocksCache from disk for SRPG unlocks.
--LoadUnlocksCache()

return t
