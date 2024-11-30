local InputHandler = function( event )

	-- if (somehow) there's no event, bail
	if not event then return end

	if event.type == "InputEventType_FirstPress" then

		Trace(event.DeviceInput.button)

		if event.DeviceInput.button == "DeviceButton_3" then
			if not reflexhelp_hidden then
				REFLEX:Connect()
				REFLEX:SetPanelThresholds(260,200,120,260)
				REFLEX:SetPanelCooldowns(60,60,60,60)
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
		elseif event.DeviceInput.button == "DeviceButton_enter" then
			SCREENMAN:SetNewScreen('ScreenSelectProfile') 
		end

	end

end

local sw=SCREEN_WIDTH
local sh=SCREEN_HEIGHT
local scx=SCREEN_CENTER_X
local scy=SCREEN_CENTER_Y

local reflex_bars = {}
local bar_max = {0,0,0,0}

local function addbar(obj)

	local xv = table.getn(reflex_bars)

	table.insert(reflex_bars,obj)

	local bg = obj:GetChild('bg')
	local level1 = obj:GetChild('level1')
	local level2 = obj:GetChild('level2')
	local level3 = obj:GetChild('level3')
	local level4 = obj:GetChild('level4')
	local level5 = obj:GetChild('level5')
	local v1 = obj:GetChild('value1')
	local v2 = obj:GetChild('value2')
	local v3 = obj:GetChild('value3')
	local v4 = obj:GetChild('value4')

	x = (xv + 1) * sw/5

	obj:x(x)
	obj:y(sh - 100)

	bg:valign(1)
	bg:zoomto(16,280)
	bg:diffuse(0,.5,1,.3)
	bg:diffusetopedge(1,.5,0,.3)

	level1:blend('add')
	level1:diffuse(1,0,0,.7)
	level1:zoomto(32,4)
	level2:blend('add')
	level2:diffuse(0,1,0,.7)
	level2:zoomto(32,4)
	level3:blend('add')
	level3:diffuse(0,.3,1,1)
	level3:zoomto(32,4)
	level4:blend('add')
	level4:diffuse(0,.3,1,.25)
	level4:zoomto(24,4)
	level5:blend('add')
	level5:diffuse(1,1,1,0)
	level5:zoomto(24,4)

	v1:y(20)
	v1:zoom(.4)
	v2:y(30)
	v2:zoom(.4)
	v3:y(40)
	v3:zoom(.4)
	v4:y(50)
	v4:zoom(.4)

end

function math.clamp(val,min,max)
	if min > max then min,max = max,min end
	if val > max then return max end
	if val < min then return min end
	return val
end

function math.mod2(a, b)
	return a - math.floor(a/b)*b;
end

local function diffusebarbg(bar,val)
	local b = reflex_bars[bar+1]:GetChild('bg')
	b:diffusealpha(val)
end
local function positionbar(bar,v,val,min,max)
	local b = reflex_bars[bar+1]:GetChild('level'..v)
	b:y(-280*((val-min)/(max-min)))
end
local function diffusebar(bar,v,val)
	local b = reflex_bars[bar+1]:GetChild('level'..v)
	b:diffusealpha(val)
end

local function settextf(bar,v,val)
	local t = reflex_bars[bar+1]:GetChild('value'..v)
	t:settext(string.format('%.1f',val))
end
local function settexti(bar,v,val)
	local t = reflex_bars[bar+1]:GetChild('value'..v)
	t:settext(val)
end

local reflexhelp_hidden = false

local t = Def.ActorFrame {
	OnCommand=function(self)
		screen = SCREENMAN:GetTopScreen()
		screen:AddInputCallback( InputHandler )
	end,
	InitCommand=function(self)

		GAMESTATE:JoinPlayer(0)

	end
}

	--[[
	<CODE
		StepP1LeftPressMessageCommand="%function(self) diffusebarbg(0,.6) end"
		StepP1LeftLiftMessageCommand="%function(self) diffusebarbg(0,.3) end"
		StepP1DownPressMessageCommand="%function(self) diffusebarbg(1,.6) end"
		StepP1DownLiftMessageCommand="%function(self) diffusebarbg(1,.3) end"
		StepP1UpPressMessageCommand="%function(self) diffusebarbg(2,.6) end"
		StepP1UpLiftMessageCommand="%function(self) diffusebarbg(2,.3) end"
		StepP1RightPressMessageCommand="%function(self) diffusebarbg(3,.6) end"
		StepP1RightLiftMessageCommand="%function(self) diffusebarbg(3,.3) end"
	/>
	]]

t[#t+1] = Def.BitmapText {
	Font="_eurostile outline",
	Text="Test Reflex :D (1.1)",
	OnCommand=function(self) self:zoom(1.5):xy(scx,84) end
}

for _=0,3 do

	t[#t+1] = Def.ActorFrame {
		OnCommand=function(self) addbar(self) end,
		Def.Quad { Name="bg" },
		Def.Quad { Name="level5" },
		Def.Quad { Name="level4" },
		Def.Quad { Name="level3" },
		Def.Quad { Name="level2" },
		Def.Quad { Name="level1" },
		Def.BitmapText { Font="_eurostile outline", Text="0", Name="value1" },
		Def.BitmapText { Font="_eurostile outline", Text="0", Name="value2" },
		Def.BitmapText { Font="_eurostile outline", Text="0", Name="value3" },
		Def.BitmapText { Font="_eurostile outline", Text="0", Name="value4" }
	}

end

t[#t+1] = Def.Actor {
	OnCommand=function(self) self:queuecommand("Update") end,
	UpdateCommand=function(self)

		if not reflexhelp_hidden then

			local sens = {
				(REFLEX:GetPanelBaseline(0)+REFLEX:GetPanelThreshold(0))/5700,
				(REFLEX:GetPanelBaseline(1)+REFLEX:GetPanelThreshold(1))/5700,
				(REFLEX:GetPanelBaseline(2)+REFLEX:GetPanelThreshold(2))/5700,
				(REFLEX:GetPanelBaseline(3)+REFLEX:GetPanelThreshold(3))/5700
			}

			local pressure = hardware_readPressureNormalizedPersonal()

			for i=0,3 do

				positionbar(i,1,REFLEX:GetPanelValue(i),2500,8000)
				positionbar(i,2,REFLEX:GetPanelBaseline(i),2500,8000)
				positionbar(i,3,REFLEX:GetPanelBaseline(i)+REFLEX:GetPanelThreshold(i),2500,8000)
				positionbar(i,4,REFLEX:GetPanelBaseline(i)+REFLEX:GetPanelThreshold(i)-REFLEX:GetPanelCooldown(i),2500,8000)

				bar_max[i+1] = math.max(REFLEX:GetPanelValue(i),bar_max[i+1])
				positionbar(i,5,bar_max[i+1],2500,8000)

				settexti(i,1,REFLEX:GetPanelValue(i))
				settexti(i,2,REFLEX:GetPanelValueAboveBaseline(i))
				settexti(i,3,REFLEX:GetPanelBaseline(i))
				settexti(i,4,bar_max[i+1]-REFLEX:GetPanelBaseline(i))

				local val = math.floor(4000*pressure[i+1]/sens[i+1])
				REFLEX:SetLightArrow(0,i,math.clamp(255*val/5700,0,255)*0.1,0,math.clamp(255*val/5700,0,255)*0.2)

			end

		end

		self:sleep(0.02)
		self:queuecommand('Update')
	end
}

return t
