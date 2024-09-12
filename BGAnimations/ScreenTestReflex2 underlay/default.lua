local InputHandler = function( event )

	-- if (somehow) there's no event, bail
	if not event then return end

	if event.type == "InputEventType_FirstPress" then
		
		--Trace(event.DeviceInput.button)
		
		if event.DeviceInput.button == "DeviceButton_3" then
			if not reflexhelp_hidden then
				REFLEX:Connect()
				REFLEX:SetPanelThresholds(500,500,500,500)
				REFLEX:SetPanelCooldowns(100,100,100,100)
			end
		elseif event.DeviceInput.button == "DeviceButton_4" then
			if not reflexhelp_hidden then REFLEX:Disconnect() end
		elseif event.DeviceInput.button == "DeviceButton_6" then
			if not reflexhelp_hidden then
				bar_max = {0,0,0,0}
				for i=0,3 do
					bar_max[i+1] = REFLEX:GetPanelBaseline(i)
					positionbar(i,5,bar_max[i+1],2500,7000)
					diffusebar(i,5,.25)
				end
			end
		elseif event.DeviceInput.button == "DeviceButton_7" then
			--if not reflexhelp_hidden then SCREENMAN:SetNewScreen('ScreenTestReflex4') end
		elseif event.DeviceInput.button == "DeviceButton_8" then
			--if not reflexhelp_hidden then SCREENMAN:SetNewScreen('ScreenSelectMusic') end
		end
		
	end

end

local sw=SCREEN_WIDTH
local sh=SCREEN_HEIGHT
local scx=SCREEN_CENTER_X
local scy=SCREEN_CENTER_Y

local reflex_bars = {}
local bar_max = {0,0,0,0}

local function settextf(bar,v,val)
	local t = reflex_bars[bar+1]:GetChild('value'..v)
	t:settext(string.format('%.1f',val))
end
local function settexti(bar,v,val)
	local t = reflex_bars[bar+1]:GetChild('value'..v)
	t:settext(val)
end

local reflexhelp_hidden = false





local num_blocks = 0
local reflex_blocks = {}

local reflex_data = {
	{},
	{},
	{},
	{},
}

local function addblock(obj)

	reflex_blocks[num_blocks] = obj
	num_blocks = num_blocks+1
	
	obj:zoom(8)
	obj:diffuse(0,0,0,1)
	
end

local reflex_block_spatial = {
	{},
	{},
	{},
	{}
}

local function the_clamp(val,min,max)
	if min > max then min,max = max,min end
	if val > max then return max end
	if val < min then return min end
	return val
end

local function the_mod2(a, b)
	return a - math.floor(a/b)*b;
end


local function color_led(pan,x,y,r,g,b)
	local a = reflex_block_spatial[pan][y][x]
	if a then
	
		--a:diffuse(r,g,b,1)
		reflex_data[pan][a:getaux()+1] = {
			math.floor(128*the_clamp(r,0,1)),
			math.floor(128*the_clamp(g,0,1)),
			math.floor(128*the_clamp(b,0,1))
		}
		--todo writelight color correction, pow,2 intensity
		--REFLEX:SetLightData(0,pan-1,a:getaux(),128*math.clamp(r,0,1),128*math.clamp(g,0,1),128*math.clamp(b,0,1))
		
		--reflex_block_spatial[pan][y][x] = color(r..","..g..","..b..",1")
		reflex_block_spatial[pan][y][x]:diffuse(the_clamp(r,0,1),the_clamp(g,0,1),the_clamp(b,0,1),1)
		
		WriteLED(0,pan-1,a:getaux(),{0.5*the_clamp(r,0,1),0.5*the_clamp(g,0,1),0.5*the_clamp(b,0,1)})
		
	end
end
local function inOutCubic(t, b, c, d)
  t = t / d * 2
  if t < 1 then
	return c / 2 * t * t * t + b
  else
	t = t - 2
	return c / 2 * (t * t * t + 2) + b
  end
end

local function outCubic(t, b, c, d)
  t = t / d - 1
  return c * (math.pow(t, 3) + 1) + b
end

local reflex_arrow = {
	{ 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0},
	{ 0, 0, 0, 0, 1,.4,.4, 1, 0, 0, 0, 0, 0, 0},
	{ 0, 0, 0, 0, 1,.4,.4,.4, 1, 0, 0, 0, 0, 0},
	{ 0, 0, 0, 0, 0, 1,.4,.4,.4, 1, 0, 0, 0, 0},
	{ 0, 1, 1, 1, 1, 1, 1,.4,.4,.4, 1, 0, 0, 0},
	{ 1,.4,.4,.4,.4,.4,.4,.4,.4,.4,.4, 1, 0, 0},
	{ 1,.4,.4,.4,.4,.4,.4,.4,.4,.4,.4, 1, 0, 0},
	{ 0, 1, 1, 1, 1, 1, 1,.4,.4,.4, 1, 0, 0, 0},
	{ 0, 0, 0, 0, 0, 1,.4,.4,.4, 1, 0, 0, 0, 0},
	{ 0, 0, 0, 0, 1,.4,.4,.4, 1, 0, 0, 0, 0, 0},
	{ 0, 0, 0, 0, 1,.4,.4, 1, 0, 0, 0, 0, 0, 0},
	{ 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0}
}

local reflex_arrowkun = {
	{ 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0},
	{ 0, 0, 0, 0, 1,.4,.4, 1, 0, 0, 0, 0, 0, 0},
	{ 0, 0, 0, 0, 1,.4,.4,.4, 1, 0, 0, 0, 0, 0},
	{ 0, 0, 0, 0, 0, 1,.4, 2, 2, 1, 0, 0, 0, 0},
	{ 0, 1, 1, 1, 1, 1, 1, 3, 2,.4, 1, 0, 0, 0},
	{ 1,.4,.4,.4,.4,.4,.4,.4,.4,.4,.4, 1, 0, 0},
	{ 1,.4,.4,.4,.4,.4,.4,.4,.4,.4,.4, 1, 0, 0},
	{ 0, 1, 1, 1, 1, 1, 1, 3, 2,.4, 1, 0, 0, 0},
	{ 0, 0, 0, 0, 0, 1,.4, 2, 2, 1, 0, 0, 0, 0},
	{ 0, 0, 0, 0, 1,.4,.4,.4, 1, 0, 0, 0, 0, 0},
	{ 0, 0, 0, 0, 1,.4,.4, 1, 0, 0, 0, 0, 0, 0},
	{ 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0}
}

local reflex_donchan = {
	{0,0,0,0,0,0,0,0,0,0,0,0},
	{0,0,0,0,1,1,1,1,0,0,0,0},
	{0,0,0,1,2,2,2,2,1,0,0,0},
	{0,0,1,2,2,2,2,2,2,1,0,0},
	{0,1,2,0,0,2,2,0,0,2,1,0},
	{0,1,2,0,0,2,2,0,0,2,1,0},
	{0,1,2,2,2,2,2,2,2,2,1,0},
	{0,1,2,2,3,3,3,3,2,2,1,0},
	{0,0,1,2,2,3,3,2,2,1,0,0},
	{0,0,0,1,2,2,2,2,1,0,0,0},
	{0,0,0,0,1,1,1,1,0,0,0,0},
	{0,0,0,0,0,0,0,0,0,0,0,0}
}

local function trace_panel(pan,dim)
	str = '{'
	for i=0,83 do
		str = str.. ' '..math.floor(reflex_data[pan][i][1]*dim)..','
		str = str.. ' '..math.floor(reflex_data[pan][i][2]*dim)..','
		str = str.. ' '..math.floor(reflex_data[pan][i][3]*dim)
		if i < 83 then str = str..',' end
	end
	str = str..' }'
	Trace(str);
end

local uptime = 0





local t = Def.ActorFrame {
	OnCommand=function(self)
		screen = SCREENMAN:GetTopScreen()
		screen:AddInputCallback( InputHandler )
		
		SCREENMAN:SystemMessage("HELP");
		
	end,
	InitCommand=function(self)
	
		GAMESTATE:JoinPlayer(0)
		
	end
}
	
t[#t+1] = Def.BitmapText {
	Font="_eurostile outline",
	Text="Test Reflex Lights :D",
	OnCommand=function(self) self:zoom(1.5):xy(scx,84) end
}

t[#t+1] = Def.Quad{ OnCommand=function(self) self:xy(sw*0.25,sh*0.55):diffuse(1,1,1,.4):zoom(140) end}
t[#t+1] = Def.Quad{ OnCommand=function(self) self:xy(sw*0.5,sh*0.35):diffuse(1,1,1,.4):zoom(140) end}
t[#t+1] = Def.Quad{ OnCommand=function(self) self:xy(sw*0.5,sh*0.75):diffuse(1,1,1,.4):zoom(140) end}
t[#t+1] = Def.Quad{ OnCommand=function(self) self:xy(sw*0.75,sh*0.55):diffuse(1,1,1,.4):zoom(140) end}

for i=1,(84*4) do
	
	t[#t+1] = Def.Quad{ InitCommand=function(self) addblock(self) end }
	
end
	
t[#t+1] = Def.Actor {
	
	OnCommand=function(self) self:queuecommand("Setup"):sleep(.1):queuecommand("Update") end,
	SetupCommand=function(self)
	
		local pos = {
			{sw*0.25,sh*0.55},
			{sw*0.50,sh*0.75},
			{sw*0.50,sh*0.35},
			{sw*0.75,sh*0.55}
		}
		
		for pan = 0,3 do
			--for led = 0,83 do
				
				local xp, yp = scx, scy
				
				if pan == 0 then
					xp = sw*0.25
				elseif pan == 1 then
					yp = sh*0.75
				elseif pan == 2 then
					yp = sh*0.25
				else
					xp = sw*0.75
				end
				
				local cur = 0 --start of each row
				
				local num = {1,2,3,4,5,6,6,5,4,3,2,1}
				
				for i=0,11 do
					local rt = {}
					table.insert(reflex_block_spatial[pan+1],rt)
				end
				
				for i=1,12 do
					for j=1,num[i]*2 do
						xp = pos[pan+1][1] + (-num[i] + 0.5 + (j-1)) * 10
						yp = pos[pan+1][2] + (i-6.4) * 10
						
						--Trace(pan*84 + cur)
						
						local ys = i
						local xs = j + (6-num[i])
						
						reflex_block_spatial[pan+1][ys][xs] = reflex_blocks[pan*84 + cur]
						
						reflex_blocks[pan*84 + cur]:xy(xp,yp)
						reflex_blocks[pan*84 + cur]:aux(cur)
						
						cur = cur+1
					end
				end
				
				--[[
				if pan == 0 then
					for y=1,12 do
						str = ''
						for x=1,12 do
							str = str..(reflex_block_spatial[pan+1][y][x] and '1,' or '0,')
						end
						Trace(str)
					end
				end
				]]
				
			--end
		end
		
	end,
	UpdateCommand=function(self)
		
		local ang = uptime * 3.1415926*2
		
		for y=1,12 do
			for x=1,12 do
				
				--RADAR
				local myang = -math.atan2((y-6.5),(x-6.5))
				
				local brt = the_mod2((0+(math.mod(myang,3.1415926*2)-math.mod(ang,3.1415926*2)))/3.1415926,1)
				
				color_led(1,y,x,(brt*2)+0.5,(brt*2)-0.5,0)
				
				
				--PULSE
				local rad = (uptime)-math.floor(uptime)
				local brt2 = math.mod((math.sqrt((y-6.5)*(y-6.5)+(x-6.5)*(x-6.5)))/6 + 1 - rad,1)
				
				color_led(2,x,y,the_clamp(brt2,0,1),the_clamp(brt2*1.5,0,1),the_clamp(brt2*3,0,1))
				
				
				--RAINBOW
				local r = 0.5+0.6*math.sin((x*math.pi*2)/12 + ang)
				local g = 0.7+0.7*math.sin((x*math.pi*2)/12 + ang + math.pi*1.4)
				local b = 0.5+0.5*math.sin((x*math.pi*2)/12 + ang + math.pi*0.66)
				
				color_led(3,x,y,r,g,b)
				
				
				
				--ARROW
				local pos4 = (uptime-math.floor(uptime))
				pos4 = 14*outCubic(pos4,0,1,1) --float position
				
				local bval4 = reflex_arrowkun[y][the_clamp(math.floor(the_mod2((x-1)-pos4,14))+1,1,14)]
				
				if bval4 <= 1 then
					color_led(4,x,y,0,bval4,0)
				elseif bval4 == 2 then
					color_led(4,x,y,1,1,1)
				else
					color_led(4,x,y,0,.5,1)
				end
				
				
				--[[
				--DON/KATSU
				local bval4 = reflex_donchan[y][x]
				
				if bval4 == 1 then
					color_led(1,x,y,1,1,1)
					color_led(4,x,y,1,1,1)
				elseif bval4 == 2 then
					color_led(1,x,y,1,.3,.3)
					color_led(4,x,y,0,.7,.7)
				elseif bval4 == 3 then
					color_led(1,x,y,.5,0,0)
					color_led(4,x,y,.5,0,0)
				else
					color_led(1,x,y,0,0,0)
					color_led(4,x,y,0,0,0)
				end
				
				color_led(2,x,y,0,0,0)
				color_led(3,x,y,0,0,0)
				]]
				
				
			end
		end
		
		--REFLEX:SetArrow(0,0,255,0,0)
		--REFLEX:SetArrow(0,1,255,128,0)
		--REFLEX:SetArrow(0,2,0,255,0)
		--REFLEX:SetArrow(0,3,0,0,255)
		
		uptime = uptime + 1/62.5

		self:sleep(1/62.5)
		self:queuecommand('Update')
	end
	
}

return t