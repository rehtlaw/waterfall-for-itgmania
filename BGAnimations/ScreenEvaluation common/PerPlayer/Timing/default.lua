-- Pane4 displays an aggregate histogram of judgment offsets
-- as well as the mean timing error, median, and mode of those offsets.

local args = ...
local player = args.player
local mode = args.mode or "Waterfall"
local name = "Timing"
if mode == "ITG" then name = name.."ITG" end
if args.sec then name = name.."2" end
local pn = ToEnumShortString(player)
local faplus = SL["P"..player:sub(-1)].ActiveModifiers.FAPlus
if faplus == 0 then faplus = 0.015 end

-- table of offset values obtained during this song's playthrough
-- obtained via ./BGAnimations/ScreenGameplay overlay/JudgmentOffsetTracking.lua
local detailed_judgments = (not GAMESTATE:IsCourseMode())
	and SL[pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].detailed_judgments
	or WF.DetailedJudgmentsFullCourse[tonumber(player:sub(-1))]
local pane_width, pane_height = 300, 180
local topbar_height = 26
local bottombar_height = 13
-- ---------------------------------------------

local abbreviations = {
	ITG = { "Fan", "Ex", "Gr", "Dec", "WO" },
	Waterfall = { "Mf", "Aw", "Sd", "OK", "Ft" }
}

local usewindows = SL.Global.ActiveModifiers.TimingWindows
if (mode == "ITG") and (not SL.Global.ActiveModifiers.TimingWindows) then
	usewindows = {true,true,true,false,false}
end

local colors = {}
for w=5,1,-1 do
	if usewindows[w] == true then
		colors[w] = DeepCopy(SL.JudgmentColors[mode][w])
	else
		abbreviations[mode][w] = abbreviations[mode][w+1]
		colors[w] = DeepCopy(colors[w+1] or SL.JudgmentColors[mode][w+1])
	end
end

-- ---------------------------------------------
-- if players have disabled W5 or W4+W5, there will be a smaller range
-- of judgments that could have possibly been earned
-- note that we use the "real" windows regardless of mode to get the "worst window" value
local num_judgments_available = 5
local worst_window = PREFSMAN:GetPreference("TimingWindowSecondsW5")
local windows = SL.Global.ActiveModifiers.TimingWindows

for i=5,1,-1 do
	if windows[i]==true then
		num_judgments_available = i
		worst_window = PREFSMAN:GetPreference("TimingWindowSecondsW"..i)
		break
	end
end

if mode == "ITG" and num_judgments_available < 5 then num_judgments_available = 3 end


-- ---------------------------------------------
-- detailed_judgments is a table of all timing offsets in the order they were earned.
-- The sequence is important for the Scatter Plot, but irrelevant here; we are only really
-- interested in how many +0.001 offsets were earned, how many -0.001, how many +0.002, etc.
-- So, we loop through detailed_judgments, and tally offset counts into a new offsets table.
-- Other judgments have also been added to this table, so ignore anything that isn't a tap note
local offsets = {}
local val

-- set worst_window value here if we want to scale the timing to the lowest judgment achieved
local worst_achieved = 1

for t in ivalues(detailed_judgments) do
	-- the first value in t is CurrentMusicSeconds when the offset occurred, which we don't need here
	-- the second is the short string for the judgment, and third is the panels
	-- the fourth value in t is the offset value for a tap note, which is what we care about
	if not (t[2] == "Miss" or t[2] == "HitMine" or t[2] == "Held" or t[2] == "LetGo") then
		val = t[4]

		if val then
			val = (math.floor(val*1000))/1000

			if not offsets[val] then
				offsets[val] = 1
			else
				offsets[val] = offsets[val] + 1
			end

			worst_achieved = math.max(worst_achieved, tonumber(t[2]:sub(-1)))
		end
	end
end

if worst_achieved < num_judgments_available then
	worst_window = PREFSMAN:GetPreference("TimingWindowSecondsW"..worst_achieved)
	num_judgments_available = worst_achieved
end

-- ---------------------------------------------
-- Actors

local pane = Def.ActorFrame{
	Name = name,
	InitCommand=function(self)
		self:visible(false)
			:xy(-pane_width*0.5, pane_height*1.95)
	end
}

-- the line in the middle indicating where truly flawless timing (0ms offset) is
pane[#pane+1] = Def.Quad{
	InitCommand=function(self)
		local x = pane_width/2

		self:vertalign(top)
			:zoomto(1, pane_height - (topbar_height+bottombar_height) )
			:vertalign(bottom):xy(x, 0)
			:diffuse(1,1,1,0.666)
	end,
}

-- "Early" text
pane[#pane+1] = Def.BitmapText{
	Font="_wendy small",
	Text=ScreenString("Early"),
	InitCommand=function(self)
		self:addx(10):addy(-125)
			:zoom(0.3)
			:horizalign(left)
	end,
}

-- "Late" text
pane[#pane+1] = Def.BitmapText{
	Font="_wendy small",
	Text=ScreenString("Late"),
	InitCommand=function(self)
		self:addx(pane_width-10):addy(-125)
			:zoom(0.3)
			:horizalign(right)
	end,
}

-- --------------------------------------------------------

-- darkened quad behind bottom judgment labels
pane[#pane+1] = Def.Quad{
	InitCommand=function(self)
		self:vertalign(top)
			:zoomto(pane_width, bottombar_height )
			:xy(pane_width/2, 0)
			:diffuse(color("#101519"))
	end,
}

-- centered text for W1
pane[#pane+1] = Def.BitmapText{
	Font="Common Normal",
	Text=abbreviations[mode][1],
	InitCommand=function(self)
		local x = pane_width/2

		self:diffuse( colors[1] )
			:addx(x):addy(7)
			:zoom(0.65)
	end,
}

-- loop from W2 to the worst_window and add judgment text
-- underneath that portion of the histogram
for i=2,num_judgments_available do

	-- ignore if itg and decent is disabled
	if not (mode == "ITG" and WF.SelectedErrorWindowSetting == 1 and i == 4) then
		-- early (left) judgment text
		pane[#pane+1] = Def.BitmapText{
			Font="Common Normal",
			Text=abbreviations[mode][i],
			InitCommand=function(self)
				local window = -1 * SL.Preferences[mode]["TimingWindowSecondsW"..i]
				if i == num_judgments_available then
					-- don't let itg go off the graph because its windows are wider than what actually might be there
					window = -1 * PREFSMAN:GetPreference("TimingWindowSecondsW"..i)
				end
				local better_window = -1 * SL.Preferences[mode]["TimingWindowSecondsW"..i-1]

				local x = scale(window, -worst_window, worst_window, 0, pane_width )
				local x_better = scale(better_window, -worst_window, worst_window, 0, pane_width)
				local x_avg = (x+x_better)/2

				self:diffuse( colors[i] )
					:addx(x_avg):addy(7)
					:zoom(0.65)
			end,
		}

		-- late (right) judgment text
		pane[#pane+1] = Def.BitmapText{
			Font="Common Normal",
			Text=abbreviations[mode][i],
			InitCommand=function(self)
				local window = SL.Preferences[mode]["TimingWindowSecondsW"..i]
				if i == num_judgments_available then
					window = PREFSMAN:GetPreference("TimingWindowSecondsW"..i)
				end
				local better_window = SL.Preferences[mode]["TimingWindowSecondsW"..i-1]

				local x = scale(window, -worst_window, worst_window, 0, pane_width )
				local x_better = scale(better_window, -worst_window, worst_window, 0, pane_width)
				local x_avg = (x+x_better)/2

				self:diffuse( colors[i] )
					:addx(x_avg):addy(7)
					:zoom(0.65)
			end,
		}
	end

end

-- --------------------------------------------------------
-- TOPBAR

-- topbar background quad
pane[#pane+1] = Def.Quad{
	InitCommand=function(self)
		self:vertalign(top)
			:zoomto(pane_width, topbar_height )
			:xy(pane_width/2, -pane_height + topbar_height/2)
			:diffuse(color("#101519"))
	end,
}

-- only bother crunching the numbers and adding extra BitmapText actors if there are
-- valid offset values to analyze; (MISS has no numerical offset and can't be analyzed)
if next(offsets) ~= nil then
	pane[#pane+1] = LoadActor("./Calculations.lua", {offsets, worst_window, pane_width, pane_height, colors, mode,
		faplus, detailed_judgments})
end

local label = {}
label.y = -pane_height+20
label.zoom = 0.575
label.padding = 3

-- Cleanly positioning the labels for "mean timing error", "median", and "mode"
-- can be tricky because some languages use very few characters to express these ideas
-- while other languages use many.  This max_width calculation works for now.
label.max_width = ((pane_width/3)/label.zoom) - ((label.padding/label.zoom)*3)

-- avg_timing_error label
pane[#pane+1] = Def.BitmapText{
	Font="Common Normal",
	Text=ScreenString("MeanTimingError"),
	InitCommand=function(self)
		self:x(60):y(label.y)
			:zoom(label.zoom):maxwidth(label.max_width)

		if self:GetWidth() > label.max_width then
			self:horizalign(left):x(label.padding)
		end
	end,
}

-- avg_timing_offset label
pane[#pane+1] = Def.BitmapText{
	Font="Common Normal",
	Text=ScreenString("MeanTimingOffset"),
	InitCommand=function(self)
		self:x(120):y(label.y)
			:zoom(label.zoom):maxwidth(label.max_width)

		if self:GetWidth() > label.max_width then
			self:horizalign(left):x(label.padding)
		end
	end,
}

-- median_offset label
pane[#pane+1] = Def.BitmapText{
	Font="Common Normal",
	Text=ScreenString("Median"),
	InitCommand=function(self)
		self:x(180):y(label.y)
			:zoom(label.zoom):maxwidth(label.max_width)
	end,
}

-- max_timing_error label
pane[#pane+1] = Def.BitmapText{
	Font="Common Normal",
	Text=ScreenString("MaxTimingError"),
	InitCommand=function(self)
		self:x(pane_width-40):y(label.y)
			:zoom(label.zoom):maxwidth(label.max_width)

		if self:GetWidth() > label.max_width then
			self:horizalign(right):x(pane_width - label.padding)
		end
	end,
}

return pane
