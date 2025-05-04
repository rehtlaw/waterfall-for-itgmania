-- arguments passed in from Graphs.lua
local args = ...
local player = args.player
local pn = tonumber(player:sub(-1))
local GraphWidth = args.GraphWidth
local GraphHeight = args.GraphHeight
local mode = args.mode
local faplus = SL["P"..player:sub(-1)].ActiveModifiers.FAPlus
if faplus == 0 then faplus = 0.015 end
local iscourse = GAMESTATE:IsCourseMode()

local gw = THEME:GetMetric("GraphDisplay", "BodyWidth")
local gh = THEME:GetMetric("GraphDisplay", "BodyHeight")
local songstart = 0
local songend = GAMESTATE:GetCurrentSong():GetLastSecond()

-- a table to store the AMV's vertices
local verts= {}
-- TotalSeconds is used in scaling the x-coordinates of the AMV's vertices
local FirstSecond = 0
local TotalSeconds = (not iscourse) and GAMESTATE:GetCurrentSong():GetLastSecond()
	or TotalCourseLength(player)
local trail = (iscourse) and GAMESTATE:GetCurrentTrail(player) or nil

-- detailed_judgments gathered in ./BGAnimations/ScreenGameplay overlay/DetailedJudgmentTracking.lua
local detailed_judgments
detailed_judgments = (not iscourse) and
	SL[ToEnumShortString(player)].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].detailed_judgments
	or WF.DetailedJudgmentsFullCourse[tonumber(player:sub(-1))]

-- variables that will be used and re-used in the loop while calculating the AMV's vertices
local Offset, CurrentSecond, TimingWindow, x, y, c, r, g, b

-- ---------------------------------------------
-- if players have disabled W4 or W4+W5, there will be a smaller pool
-- of judgments that could have possibly been earned
local worst_window = PREFSMAN:GetPreference("TimingWindowSecondsW5")
local worstind = 5
local windows = SL.Global.ActiveModifiers.TimingWindows
for i=5,1,-1 do
	if windows[i] then
		worst_window = PREFSMAN:GetPreference("TimingWindowSecondsW"..i)
		worstind = i
		break
	end
end

-- ---------------------------------------------

local usewindows = SL.Global.ActiveModifiers.TimingWindows
if (mode == "ITG") and (not SL.Global.ActiveModifiers.TimingWindows) then
	usewindows = {true,true,true,false,false}
end
local colors = {}
for w=5,1,-1 do
	if usewindows[w] == true then
		colors[w] = DeepCopy(SL.JudgmentColors[mode][w])
	else
		-- what actually is this for.....???
		colors[w] = DeepCopy(colors[w+1] or SL.JudgmentColors[mode][w+1])
	end
end

-- extra bit of logic to "zoom" the graph in the case you didn't hit outside a certain window

local worsthit = 1
for j in ivalues(detailed_judgments) do
	if not (j[2] == "Miss" or j[2] == "HitMine" or j[2] == "Held" or j[2] == "LetGo") then
		local w = tonumber(j[2]:sub(-1))
		if w > worsthit then worsthit = w end
		if w >= worstind then break end
	end
end
worst_window = math.max(0.020, math.min(worst_window, PREFSMAN:GetPreference("TimingWindowSecondsW"..worsthit)))

-- ---------------------------------------------

-- transparent backing quads for every other song in a course
local af

if iscourse then
	af = Def.ActorFrame{}
	local start = 0
	for i, te in ipairs(trail:GetTrailEntries()) do
		local length = te:GetSong():GetLastSecond()
		local curx = (-GraphWidth/2) + (start / TotalSeconds) * GraphWidth
		local curw = (length / TotalSeconds) * GraphWidth
		if i % 2 == 0 then
			af[#af+1] = Def.Quad{
				InitCommand = function(self)
					self:horizalign("left"):x(curx):vertalign("top"):zoomto(curw, GraphHeight)
					:diffuse(1,1,1,0.075)
				end
			}
		end
		start = start + length
	end
end

for t in ivalues(detailed_judgments) do
	CurrentSecond = t[1]
	TimingWindow = t[2]
	if (TimingWindow ~= "Held" and TimingWindow ~= "LetGo") then
		Offset = (t[2] ~= "HitMine") and t[4] or 0

		if TimingWindow ~= "Miss" then
			CurrentSecond = CurrentSecond - Offset
		else
			CurrentSecond = CurrentSecond - worst_window
		end

		-- pad the right end because the time measured seems to lag a little...
		x = (CurrentSecond / TotalSeconds) * (GraphWidth - 1.5)

		if TimingWindow ~= "Miss" and TimingWindow ~= "HitMine" then
			local wid = (mode ~= "ITG") and tonumber(TimingWindow:sub(-1)) or DetermineTimingWindow(Offset, "ITG")
			y = scale(Offset, worst_window, -worst_window, 0, GraphHeight)

			-- get the appropriate color from the global SL table
			c = colors[wid]
			if faplus > 0 and wid == 1 and math.abs(Offset) > faplus then
				c = {1,1,1}
			end
			-- get the red, green, and blue values from that color
			r = c[1]
			g = c[2]
			b = c[3]

			-- insert four datapoints into the verts tables, effectively generating a single quadrilateral
			-- top left,  top right,  bottom right,  bottom left
			table.insert( verts, {{x-0.75,y-0.75,0}, {r,g,b,0.666}} )
			table.insert( verts, {{x+0.75,y-0.75,0}, {r,g,b,0.666}} )
			table.insert( verts, {{x+0.75,y+0.75,0}, {r,g,b,0.666}} )
			table.insert( verts, {{x-0.75,y+0.75,0}, {r,g,b,0.666}} )
		else
			-- else, a miss should be a quadrilateral that is the height of the entire graph and red
			-- similarly for a mine, but make mines gray
			local clr = TimingWindow == "Miss" and color("#ff000077") or color("#82828277")
			table.insert( verts, {{x-0.5, 0, 0}, clr} )
			table.insert( verts, {{x+0.5, 0, 0}, clr} )
			table.insert( verts, {{x+0.5, GraphHeight, 0}, clr} )
			table.insert( verts, {{x-0.5, GraphHeight, 0}, clr} )
		end
	end
end

-- the scatter plot will use an ActorMultiVertex in "Quads" mode
-- this is more efficient than drawing n Def.Quads (one for each judgment)
-- because the entire AMV will be a single Actor rather than n Actors with n unique Draw() calls.
local dg = Def.ActorFrame{
	InitCommand = function(self)
		self:x(-gw/2)
		self:y(gh)
		self:diffusealpha(0.35)
	end
}

dg[#dg+1] = (not GAMESTATE:IsCourseMode()) and NPS_Histogram_Static(player, gw, gh)
    or NPS_Histogram_Static_Course(player, gw, gh)

local amv = Def.ActorFrame{}

-- Density graph
amv[#amv+1] = dg

-- Scatter plot
amv[#amv+1] = Def.ActorMultiVertex{
	InitCommand=function(self) self:x(-GraphWidth/2) end,
	OnCommand=function(self)
		self:SetDrawState({Mode="DrawMode_Quads"})
			:SetVertices(verts)
	end,
	}


if mode == "Waterfall" then 
	-- Waterfall lifebar
	for ind in ivalues(WF.ActiveLifeBars) do
		local life_wf = (not GAMESTATE:IsCourseMode()) and WF.GetLifeGraphVertices(pn, ind, gw, gh, songstart, songend)
			or WF.GetLifeGraphVerticesCourse(pn, ind, gw, gh)
	
		if life_wf then
			local fail = WF.IsLifeBarFailed(pn, ind)
			local order = 50 + ind * (fail and -1 or 1)
			amv[#amv+1] = Def.ActorMultiVertex{
				InitCommand = function(self)
					self:x(-gw/2)
					self:draworder(order)
					if ind < WF.LowestLifeBarToFail[pn] then self:visible(false) end
				end,
				OnCommand = function(self)
					self:SetDrawState({Mode="DrawMode_LineStrip"}):SetLineWidth(1)
						:SetVertices(life_wf)
				end
			}
		end
	end
else
	-- ITG lifebar
	local life_itg = (not GAMESTATE:IsCourseMode()) and WF.GetITGLifeVertices(pn, gw, gh, songstart, songend)
    or WF.GetITGLifeVerticesCourse(pn, gw, gh)

	amv[#amv+1] = Def.ActorMultiVertex{
		InitCommand = function(self)
			self:x(-gw/2)
		end,
		OnCommand = function(self)
			self:SetDrawState({Mode="DrawMode_LineStrip"}):SetLineWidth(1)
				:SetVertices(life_itg)
		end
	}
end
	
if iscourse then af[#af+1] = amv end

return (not iscourse) and amv or af
