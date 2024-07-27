local player = ...
local pn = ToEnumShortString(player)
local n = player==PLAYER_1 and "1" or "2"
local IsUltraWide = (GetScreenAspectRatio() > 21/9)
local NoteFieldIsCentered = (GetNotefieldX(player) == _screen.cx)
local mods = SL[pn].ActiveModifiers

local NumEntries = 5

if not mods.Groovestats then return end

local border = 5
local width = 162
local height = 80

local cur_style = 0
local num_styles = 3

local loop_seconds = 5
local transition_seconds = 1

local all_data = {}

-- Initialize the all_data object.
for i=1,num_styles do
	local data = {
		["has_data"]=false,
		["scores"]={}
	}
	local scores = data["scores"]
	for i=1,5 do
		scores[#scores+1] = {
			["rank"]="",
			["name"]="",
			["score"]="",
			["isSelf"]=false,
			["isRival"]=false,
			["isFail"]=false,
            ["isEx"]=false,
		}
	end
	all_data[#all_data + 1] = data
end

-- Checks to see if any data is available.
local HasData = function(idx)
	return all_data[idx+1] and all_data[idx+1].has_data
end

local ResetAllData = function()
	for i=1,num_styles do
		local data = {
			["has_data"]=false,
			["scores"]={}
		}
		local scores = data["scores"]
		for i=1,NumEntries do
			scores[#scores+1] = {
				["rank"]="",
				["name"]="",
				["score"]="",
				["isSelf"]=false,
				["isRival"]=false,
				["isFail"]=false,
				["isEx"]=false,
			}
		end
		all_data[#all_data + 1] = data
	end
end

local SetScoreData = function(data_idx, score_idx, rank, name, score, isSelf, isRival, isFail, isEx)
	all_data[data_idx].has_data = true

	local score_data = all_data[data_idx]["scores"][score_idx]
	score_data.rank = rank..((#rank > 0) and "." or "")
	score_data.name = name
	score_data.score = score
	score_data.isSelf = isSelf
	score_data.isRival = isRival
	score_data.isFail = isFail
	score_data.isEx = isEx
end

local LeaderboardRequestProcessor = function(res, master)
	if master == nil then return end

	if res.error or res.statusCode ~= 200 then
		local error = res.error and ToEnumShortString(res.error) or nil
		local text = ""
		if error == "Timeout" then
			text = "Timed Out"
		elseif error or (res.statusCode ~= nil and res.statusCode ~= 200) then
			text = "Failed to Load 😞"
		end
		SetScoreData(1, 1, "", text, "", false, false, false, false)
		master:queuecommand("CheckScorebox")
		return
	end

	local playerStr = "player"..n
	local data = JsonDecode(res.body)

	-- First check to see if the leaderboard even exists.
	if data and data[playerStr] then
		-- These will get overwritten if we have any entries in the leaderboard below.
		SetScoreData(1, 1, "", "No Scores", "", false, false, false, false)
		SetScoreData(2, 1, "", "No Scores", "", false, false, false, false)

		local numEntries = 0
		if SL["P"..n].ActiveModifiers.EXScoring then
			-- If the player is using EX scoring, then we want to display the EX leaderboard first.
			if data[playerStr]["exLeaderboard"] then
				numEntries = 0
				for entry in ivalues(data[playerStr]["exLeaderboard"]) do
					numEntries = numEntries + 1
					SetScoreData(2, numEntries,
									tostring(entry["rank"]),
									entry["name"],
									string.format("%.2f", entry["score"]/100),
									entry["isSelf"],
									entry["isRival"],
									entry["isFail"],
									true
								)
				end
			end

			if data[playerStr]["gsLeaderboard"] then
				numEntries = 0
				for entry in ivalues(data[playerStr]["gsLeaderboard"]) do
					numEntries = numEntries + 1
					SetScoreData(1, numEntries,
									tostring(entry["rank"]),
									entry["name"],
									string.format("%.2f", entry["score"]/100),
									entry["isSelf"],
									entry["isRival"],
									entry["isFail"],
									false
								)
				end
			end
		else
			-- Display the main GrooveStats leaderboard first if player is not using EX scoring.
			if data[playerStr]["gsLeaderboard"] then
				numEntries = 0
				for entry in ivalues(data[playerStr]["gsLeaderboard"]) do
					numEntries = numEntries + 1
					SetScoreData(1, numEntries,
									tostring(entry["rank"]),
									entry["name"],
									string.format("%.2f", entry["score"]/100),
									entry["isSelf"],
									entry["isRival"],
									entry["isFail"],
									false
								)
				end
			end

			if data[playerStr]["exLeaderboard"] then
				numEntries = 0
				for entry in ivalues(data[playerStr]["exLeaderboard"]) do
					numEntries = numEntries + 1
					SetScoreData(2, numEntries,
									tostring(entry["rank"]),
									entry["name"],
									string.format("%.2f", entry["score"]/100),
									entry["isSelf"],
									entry["isRival"],
									entry["isFail"],
									true
								)
				end
			end
		end

		if data[playerStr]["rpg"] then
			local entryCount = 0
			SetScoreData(3, 1, "", "No Scores", "", false, false, false)

			if data[playerStr]["rpg"]["rpgLeaderboard"] then
				for entry in ivalues(data[playerStr]["rpg"]["rpgLeaderboard"]) do
					entryCount = entryCount + 1
					SetScoreData(3, entryCount,
									tostring(entry["rank"]),
									entry["name"],
									string.format("%.2f", entry["score"]/100),
									entry["isSelf"],
									entry["isRival"],
									entry["isFail"],
									false
								)
				end
			end
		end

		if data[playerStr]["itl"] then
			local numEntries = 0
			SetScoreData(4, 1, "", "No Scores", "", false, false, false)

			if data[playerStr]["itl"]["itlLeaderboard"] then
				for entry in ivalues(data[playerStr]["itl"]["itlLeaderboard"]) do
					numEntries = numEntries + 1
					SetScoreData(4, numEntries,
									tostring(entry["rank"]),
									entry["name"],
									string.format("%.2f", entry["score"]/100),
									entry["isSelf"],
									entry["isRival"],
									entry["isFail"],
									true
								)
				end
			end
		end
 	end
	master:queuecommand("CheckScorebox")
end

local af = Def.ActorFrame{
	Name="ScoreBox"..pn,
	InitCommand=function(self)
		self:xy(-70, -115)
		-- offset a bit more when NoteFieldIsCentered
		if NoteFieldIsCentered and IsUsingWideScreen() then
			self:addx( 2 * (player==PLAYER_1 and 1 or -1) )
		end

		-- ultrawide and both players joined
		if IsUltraWide and #GAMESTATE:GetHumanPlayers() > 1 then
			self:x(self:GetX() * -1)
		end
		self.isFirst = true
	end,
	CheckScoreboxCommand=function(self)
		self:queuecommand("LoopScorebox")
	end,
	LoopScoreboxCommand=function(self)
		local start = cur_style

		cur_style = (cur_style + 1) % num_styles
		while cur_style ~= start or self.isFirst do
			-- Make sure we have the next set of data.

			if HasData(cur_style) then
				-- If this is the first time we're looping, update the start variable
				-- since it may be different than the default
				if self.isFirst then
					start = cur_style
					self.isFirst = false
					-- Continue looping to figure out the next style.
				else
					break
				end
			end
			cur_style = (cur_style + 1) % num_styles
		end

		-- Loop only if there's something new to loop to.
		if start ~= cur_style then
			self:sleep(loop_seconds):queuecommand("LoopScorebox")
		end
	end,

	RequestResponseActor(0, 0)..{
		OnCommand=function(self)
			self:queuecommand("MakeRequest")
		end,
		CurrentSongChangedMessageCommand=function(self)
				if not self.isFirst then
						ResetAllData()
						self:queuecommand("MakeRequest")
				end
		end,
		MakeRequestCommand=function(self)
            local steps
			if GAMESTATE:IsCourseMode() then
				local songindex = GAMESTATE:GetCourseSongIndex()
				local trail = GAMESTATE:GetCurrentTrail(player):GetTrailEntries()[songindex+1]
				steps = trail:GetSteps()
			else
				steps = GAMESTATE:GetCurrentSteps(player)
			end

			local hash = HashCacheEntry(steps)
            local headers = {}
			local sendRequest = false
            local query = {
                maxLeaderboardResults=NumEntries
            }

			if SL[pn].ApiKey ~= "" and hash ~= "" then
				query["chartHashP"..n] = SL[pn].Streams.Hash
				headers["x-api-key-player-"..n] = SL[pn].ApiKey
				sendRequest = true
			end

			-- We technically will send two requests in ultrawide versus mode since
			-- both players will have their own individual scoreboxes.
			-- Should be fine though.
	        if sendRequest then
				self:GetParent():GetChild("Name1"):settext("Loading...")
				self:playcommand("MakeGrooveStatsRequest", {
					endpoint="player-leaderboards.php?"..NETWORK:EncodeQueryParameters(query),
					method="GET",
					headers=headers,
					timeout=10,
					callback=LeaderboardRequestProcessor,
					args=self:GetParent(),
				})
			end
		end

	},

	CurrentSongChangedMessageCommand=function(self)
		if not self.isFirst then			
			-- Create a new request after the first song of course mode
			self:queuecommand("MakeRequest")
		end
	end,

	-- Outline
	Def.Quad{
		Name="Outline",
		InitCommand=function(self)
			self:diffuse(color("#007b85")):setsize(width + border, height + border)
		end,
		LoopScoreboxCommand=function(self)
			if cur_style == 0 then
				self:linear(transition_seconds):diffuse(color("#007b85"))
			elseif cur_style == 1 then
				self:linear(transition_seconds):diffuse(color("0.38,0.26,1,1"))
			elseif cur_style == 2 then
				self:linear(transition_seconds):diffuse(color("1,0.2,0.406,1"))
			end
		end
	},
	-- Main body
	Def.Quad{
		Name="Background",
		InitCommand=function(self)
			self:diffuse(color("#000000")):setsize(width, height)
		end,
	},
	-- GrooveStats Logo
	Def.Sprite{
		Texture=THEME:GetPathG("", "GrooveStats.png"),
		Name="GrooveStatsLogo",
		InitCommand=function(self)
			self:zoom(0.8):diffusealpha(0.5)
		end,
		LoopScoreboxCommand=function(self)
			if cur_style == 0 or cur_style == 1 then
				self:sleep(transition_seconds/2):linear(transition_seconds/2):diffusealpha(0.5)
			else
				self:linear(transition_seconds/2):diffusealpha(0)
			end
		end
	},
	-- EX Text
	Def.BitmapText{
		Font="Common Normal",
		Text="EX",
		InitCommand=function(self)
			self:diffusealpha(0.3):x(2):y(-5)
		end,
		LoopScoreboxCommand=function(self)
			if cur_style == 1 then
				self:sleep(transition_seconds/2):linear(transition_seconds/2):diffusealpha(0.3)
			else
				self:linear(transition_seconds/2):diffusealpha(0)
			end
		end
	},
	-- SRPG Logo
	Def.Sprite{
		Texture=THEME:GetPathG("", "SRPG8"),
		Name="SRPG8Logo",
		InitCommand=function(self)
			self:diffusealpha(0.4):zoom(0.03):diffusealpha(0)
		end,
		LoopScoreboxCommand=function(self)
			if cur_style == 2 then
				self:linear(transition_seconds/2):diffusealpha(0.5)
			else
				self:sleep(transition_seconds/2):linear(transition_seconds/2):diffusealpha(0)
			end
		end
	},
	-- ITL Logo
	Def.Sprite{
		Texture=THEME:GetPathG("", "ITL.png"),
		Name="ITLLogo",
		InitCommand=function(self)
			self:diffusealpha(0.2):zoom(0.45):diffusealpha(0)
		end,
		LoopScoreboxCommand=function(self)
			if cur_style == 3 then
				self:linear(transition_seconds/2):diffusealpha(0.2)
			else
				self:sleep(transition_seconds/2):linear(transition_seconds/2):diffusealpha(0)
			end
		end
	},
}

for i=1,5 do
	local y = -height/2 + 16 * i - 8
	local zoom = 0.87


	-- Scores don't flush from the previous song in course mode
	-- So when there are less than 5 scores on the leaderboard for a song
	-- it will show scores from the previous song
	-- So flush scores before making the request
	-- Could probably have done this a better way
	-- Waterfall Expanded 0.7.7


	-- Rank 1 gets a crown.
	if i == 1 then
		af[#af+1] = Def.Sprite{
			Name="Rank"..i,
			Texture=THEME:GetPathG("", "crown.png"),
			InitCommand=function(self)
				self:zoom(0.09):xy(-width/2 + 14, y):diffusealpha(0)
			end,
			LoopScoreboxCommand=function(self)
				self:linear(transition_seconds/2):diffusealpha(0):queuecommand("SetScorebox")
			end,
			SetScoreboxCommand=function(self)
				local score = all_data[cur_style+1]["scores"][i]
				if score.rank ~= "" then
					self:linear(transition_seconds/2):diffusealpha(1)
				end
			end,
			CurrentSongChangedMessageCommand=function(self)
				if not self.isFirst then			
					self:diffusealpha(0)
				end
			end,
		}
	else
		af[#af+1] = LoadFont("Common Normal")..{
			Name="Rank"..i,
			Text="",
			InitCommand=function(self)
				self:diffuse(Color.White):xy(-width/2 + 27, y):maxwidth(30):horizalign(right):zoom(zoom)
			end,
			LoopScoreboxCommand=function(self)
				self:linear(transition_seconds/2):diffusealpha(0):queuecommand("SetScorebox")
			end,
			SetScoreboxCommand=function(self)
				local score = all_data[cur_style+1]["scores"][i]
				local clr = Color.White
				if score.isSelf then
					clr = color("#a1ff94")
				elseif score.isRival then
					clr = color("#c29cff")
				end
				self:settext(score.rank)
				self:linear(transition_seconds/2):diffusealpha(1):diffuse(clr)
			end,
			CurrentSongChangedMessageCommand=function(self)
				if not self.isFirst then			
					self:diffusealpha(0)
				end
			end,
		}
	end

	af[#af+1] = LoadFont("Common Normal")..{
		Name="Name"..i,
		Text="",
		InitCommand=function(self)
			self:diffuse(Color.White):xy(-width/2 + 30, y):maxwidth(100):horizalign(left):zoom(zoom)
		end,
		LoopScoreboxCommand=function(self)
			self:linear(transition_seconds/2):diffusealpha(0):queuecommand("SetScorebox")
		end,
		SetScoreboxCommand=function(self)
			local score = all_data[cur_style+1]["scores"][i]
			local clr = Color.White
			if score.isSelf then
				clr = color("#a1ff94")
			elseif score.isRival then
				clr = color("#c29cff")
			end
			self:settext(score.name)
			self:linear(transition_seconds/2):diffusealpha(1):diffuse(clr)
		end,
		CurrentSongChangedMessageCommand=function(self)
			if not self.isFirst then			
				self:diffusealpha(0)
			end
		end,
	}

	af[#af+1] = LoadFont("Common Normal")..{
		Name="Score"..i,
		Text="",
		InitCommand=function(self)
			self:diffuse(Color.White):xy(-width/2 + 160, y):horizalign(right):zoom(zoom)
		end,
		LoopScoreboxCommand=function(self)
			self:linear(transition_seconds/2):diffusealpha(0):queuecommand("SetScorebox")
		end,
		SetScoreboxCommand=function(self)
			local score = all_data[cur_style+1]["scores"][i]
			local clr = Color.White
			if score.isFail then
				clr = Color.Red
            elseif score.isEx then
                clr = color("#21CCE8")
			elseif score.isSelf then
				clr = color("#a1ff94")
			elseif score.isRival then
				clr = color("#c29cff")
			end
			self:settext(score.score)
			self:linear(transition_seconds/2):diffusealpha(1):diffuse(clr)
		end,
		CurrentSongChangedMessageCommand=function(self)
			if not self.isFirst then
				self:diffusealpha(0)
			end
		end,
	}
end
return af
