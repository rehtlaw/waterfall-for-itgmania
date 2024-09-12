local af = Def.ActorFrame{}

local lightsmode = "judge"
--local lightsmode = "chart"

if not REFLEX then return af end

--used in knowing our judgment color
local useitg = SL.P1.ActiveModifiers.SimulateITGEnv
local env = "Waterfall"

function lightsUpdate ()
	local beat = GAMESTATE:GetSongBeat()
	
	--Trace("haha")
	
	for pn=1,1 do
	
		if lightsmode == "chart" then
			while lights_cur[pn] <= table.getn(lights_notedata[pn]) and beat >= lights_notedata[pn][lights_cur[pn] ][1]-0.1 do
				
				if beat < lights_notedata[pn][lights_cur[pn] ][1] + 1 then
					local btn = lights_notedata[pn][lights_cur[pn] ][2]+0
					--Trace('LIGHT BUTTON '..btn)
					if lights_lightobj[pn][btn] then
						
						lights_lightobj[pn][btn]:finishtweening();
						lights_color_quantize_light(lights_lightobj[pn][btn],lights_notedata[pn][lights_cur[pn] ][1])
						lights_lightobj[pn][btn]:aux(0);
						
						if lights_notedata[pn][lights_cur[pn] ].length then
							local l = lights_notedata[pn][lights_cur[pn] ].length
							local bps = 4
							bps = SCREENMAN:GetTopScreen():GetTrueBPS(PLAYER_1)
							lights_lightobj[pn][btn]:sleep(l / bps)
						end
						
						lights_lightobj[pn][btn]:linear(0.25);
						lights_set_colorpos(lights_lightobj[pn][btn],0,0,0,0)
					end
				end
				
				lights_cur[pn] = lights_cur[pn]+1
			end
		end
		
		for btn = 1,4 do
			if lights_lightobj[pn][btn] then
				local r = lights_lightobj[pn][btn]:GetX()
				local g = lights_lightobj[pn][btn]:GetY()
				local b = lights_lightobj[pn][btn]:GetZ()
				local w = lights_lightobj[pn][btn]:getaux()
				
				--[[
				if lights_show_lights and lights_lightobjvis[pn][btn] then
					lights_lightobjvis[pn][btn]:diffuse(r,g,b,1)
					lights_lightobjvis[pn][btn]:aux(w)
				end
				]]
				
				--Trace(r)
				
				--WriteLight(pn-1,btn-1,lights_lightobj[pn][btn], 0.5);
				REFLEX:SetLightArrow(0,btn-1,0.4*r*255,0.4*g*255,0.4*b*255)
				
			end
		end
		
	end
end

for btn = 1,4 do
	REFLEX:SetLightArrow(0,btn-1,0,0,0)
end

lights_lightobj = {{},{}}

for i=1,4 do
	af[#af+1] = Def.Quad{ InitCommand=function(self) table.insert(lights_lightobj[1],self) self:visible(false) end }
end
for i=1,4 do
	af[#af+1] = Def.Quad{ InitCommand=function(self) table.insert(lights_lightobj[2],self) self:visible(false) end }
end

af[#af+1] = Def.ActorFrame{
	InitCommand=function(self)
	
		function lights_color_quantize_light(obj, b)
			local r = b-math.floor(b)
			if r == 0 then lights_color_position(obj,4)
			elseif r == 0.5 then lights_color_position(obj,8)
			elseif (r > 0.33 and r < 0.34) or (r > 0.66 and r < 0.67) then lights_color_position(obj,12)
			elseif r == 0.25 or r == 0.75 then lights_color_position(obj,16)
			elseif (r > 0.166 and r < 0.167) or (r > 0.83 and r < 0.84) then lights_color_position(obj,12)
			elseif r == 0.125 or r == 0.375 or r == 0.625 or r == 0.875 then lights_color_position(obj,32)
			else lights_color_position(obj,64) end
		end
		
		function lights_color_position(obj, n)
			if n == 4 then obj:x(1) obj:y(.2) obj:z(0) end
			if n == 8 then obj:x(0) obj:y(.2) obj:z(.8) end
			if n == 12 then obj:x(1) obj:y(0) obj:z(.9) end
			if n == 16 then obj:x(.3) obj:y(.7) obj:z(0) end
			if n == 32 then obj:x(1) obj:y(.6) obj:z(0) end
			if n == 64 then obj:x(0) obj:y(.7) obj:z(.4) end
		end
		
		function lights_set_colorpos(obj, r, g, b, w)
			obj:x(r);
			obj:y(g);
			obj:z(b);
			obj:aux(w);
		end
		
		self:visible(false)
		
	end,
	OnCommand=function(self)
		self:sleep(0.2)
		self:queuecommand('The')
	end,
	TheCommand=function(self)
		
		lights_cur = {1,1}
		lights_notedata = {}
		
		for pn=1,1 do
			--table.insert(lights_notedata,SCREENMAN:GetTopScreen():GetChild('PlayerP'..pn):GetNoteData())
		end
		
		if not hardware_bullshit then
			self:queuecommand('Update')
		end
	end,
	JudgmentMessageCommand=function(self, params)
		if lightsmode == "judge" then
		
			if params.Notes and params.Player == 'PlayerNumber_P1' then
				
				local w = tonumber(params.TapNoteScore:sub(-1)) --get window of the judgment received
				
				--Checks all columns.
				for i=1,4 do
					--chech every column, and see if this column both exists AND isn't a mine
					if params.Notes[i] and params.Notes[i]:GetTapNoteType() ~= "TapNoteType_Mine" then
						local obj = lights_lightobj[1][i]
						
						--cancel this panel object's current light animation
						obj:finishtweening();
						
						--set the light object's color based on the THEME's judgment color for the judgment received
						if SL.JudgmentColors[env][w] then
							local col = SL.JudgmentColors[env][w]
							lights_set_colorpos(obj,col[1],col[2],col[3],1)
						else
							lights_set_colorpos(obj,.5,0,0,1) --miss
						end
						
						--fade back to black (off) over the course of 0.25 seconds after receiving the judgement
						obj:linear(0.25);
						lights_set_colorpos(obj,0,0,0,0)
					end
				end
				
			end
		end
	end,
	UpdateCommand=function(self)
		self:SetUpdateFunction(lightsUpdate)
	end
}

return af
