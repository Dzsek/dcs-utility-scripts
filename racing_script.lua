smokeSequence = {
	trigger.smokeColor.Orange,
	trigger.smokeColor.Red,
	trigger.smokeColor.Blue
}

Utils = {}
Utils.canAccessFS = true
function Utils.saveTable(filename, variablename, data)
	if not Utils.canAccessFS then 
		return
	end
	
	if not io then
		Utils.canAccessFS = false
		trigger.action.outText('Persistance disabled', 30)
		return
	end

	local str = variablename..' = {}'
	for i,v in pairs(data) do
		str = str..'\n'..variablename..'[\''..i..'\'] = '..Utils.serializeValue(v)
	end

	File = io.open(filename, "w")
	File:write(str)
	File:close()
end
	
function Utils.serializeValue(value)
	local res = ''
	if type(value)=='number' or type(value)=='boolean' then
		res = res..tostring(value)
	elseif type(value)=='string' then
		res = res..'\''..value..'\''
	elseif type(value)=='table' then
		res = res..'{ '
		for i,v in pairs(value) do
			if type(i)=='number' then
				res = res..'['..i..']='..Utils.serializeValue(v)..','
			else
				res = res..'[\''..i..'\']='..Utils.serializeValue(v)..','
			end
		end
		res = res:sub(1,-2)
		res = res..' }'
	end
	return res
end
	
function Utils.loadTable(filename)
	if not Utils.canAccessFS then 
		return
	end
	
	if not lfs then
		Utils.canAccessFS = false
		trigger.action.outText('Persistance disabled', 30)
		return
	end
	
	if lfs.attributes(filename) then
		dofile(filename)
	end
end

savefile = lfs.writedir()..'/racing_leaderboards.lua'
Utils.loadTable(savefile)
if playerBest then
	for i,v in pairs(playerBest) do
		if not bestPl or bestPl.time>v.time then
			
			bestPl = {name = i, time = v.time, aircraft = v.type}
		end
	end
else
	playerBest = {} 
	bestPl = nil
end



wpPrefix = 'w-'

wpCount = 0
for i=1,10000,1 do
	local z = wpPrefix..i
	local zn = trigger.misc.getZone(z)
	if not zn then
		wpCount = i - 1
		break
	end
end


function mag(vec)
	return (vec.x^2 + vec.y^2 + vec.z^2)^0.5
end
	
function makeVec3(vec, y)
	if not vec.z then
		if vec.alt and not y then
			y = vec.alt
		elseif not y then
			y = 0
		end
		return {x = vec.x, y = y, z = vec.y}
	else
		return {x = vec.x, y = vec.y, z = vec.z}
	end
end

function getDist(point1, point2)
	return mag({x = point1.x - point2.x, y = point1.y - point2.y, z = point1.z - point2.z})
end

function getPointOnSurface(point)
	return {x = point.x, y = land.getHeight({x = point.x, y = point.z}), z= point.z}
end

timer.scheduleFunction(function(param, time)
	for i=1,wpCount,1 do
		local z = wpPrefix..i
		local zn = trigger.misc.getZone(z)
		
		local p = getPointOnSurface(zn.point)
		
		local zn1 = trigger.misc.getZone(z..'-1')
		local zn2 = trigger.misc.getZone(z..'-2')
		
		local smColor = smokeSequence[(i%#smokeSequence)+1]
		
		if zn1 and zn2 then
			trigger.action.smoke(getPointOnSurface(zn1.point), smColor)
			trigger.action.smoke(getPointOnSurface(zn2.point), smColor)
		else
			trigger.action.smoke(p, smColor)
		end
	end
	
	return time+290
end,{},timer.getTime()+2)

lastPoint = nil
for i=1,wpCount,1 do
	local z = wpPrefix..i
	local zn = trigger.misc.getZone(z)
	
	local p = getPointOnSurface(zn.point)
	if lastPoint then
		trigger.action.lineToAll(-1, 5000+i, lastPoint, p, {0,0,1,1}, 1, true)
	end

	lastPoint = p
	
	trigger.action.markToAll(1000+i , 'w-'..i , p, true)
end

pdata = {}
--nextWp = 1
--doneWp = 0
--startTime = 0
--endTime = 0
timer.scheduleFunction(function(param,time)
	local players = coalition.getPlayers(2)
	for i,v in ipairs(players) do
		local pl = v
		
		local pname = pl:getPlayerName()
		local ptype = pl:getDesc().typeName
		
		local nextWp = pdata[pname].nextWp
		local doneWp = pdata[pname].doneWp
		local startTime = pdata[pname].startTime
		local endTime = pdata[pname].endTime
		
		local pd = pl:getPoint()
		
		if nextWp > wpCount then --race ended check if we are in first wp to restart it
			local z = wpPrefix..'1'
			local zn = trigger.misc.getZone(z)
			local p = getPointOnSurface(zn.point)
			local d = getDist(pd, p)
			if d <= zn.radius then -- player at first wp
				nextWp = 1
				doneWp = 0
				startTime = 0
				endTime = 0
			end
		end
		
		for i=nextWp,wpCount,1 do
			local z = wpPrefix..i
			local zn = trigger.misc.getZone(z)
			local p = getPointOnSurface(zn.point)
			local d = getDist(pd, p)
			if d <= zn.radius then
				doneWp = doneWp + 1
				
				if i == 1 then
					--first wp
					startTime = time
					trigger.action.outText('['..doneWp..'/'..wpCount..']['..z..'] started.\n\nName: '..pname..'\nAircraft: '..ptype,5)
					nextWp = 2
				elseif i == wpCount then
					--last wp
					endTime = time
					
					local runTime = endTime-startTime
					trigger.action.outText('['..doneWp..'/'..wpCount..']['..z..'] ended.\n\nName: '..pname..'\nTime: '..endTime-startTime..' sec\nAircraft: '..ptype,60)
					
					if playerBest[pname] == nil then
						trigger.action.outText('New personal best.\nPlayer: '..pname..'\nTime: '..runTime,60)
						playerBest[pname] = {time = runTime, type = ptype}
					elseif runTime < playerBest[pname].time then
						trigger.action.outText('New personal best.\nPlayer: '..pname..'\nTime: '..runTime..'\n-'..playerBest[pname].time - runTime..'sec',60)
						playerBest[pname] = {time = runTime, type = ptype}
					end
					
					if bestPl == nil or runTime < bestPl.time then
						bestPl = {name = pname, time = runTime, aircraft = ptype}
						trigger.action.outText('New leader.\nPlayer: '..pname..'\nTime: '..runTime..'\nAircraft: '..ptype,60)
					end
					
					Utils.saveTable(savefile, 'playerBest', playerBest)
					
					nextWp = nextWp+1
				elseif i ~= nextWp then
					nextWp = i+1 -- missed wp
					trigger.action.outTextForUnit(pl:getID(),'['..doneWp..'/'..wpCount..']['..z..'] WP missed.\n\nName: '..pname..'\nTime: '..time-startTime..' sec\nAircraft: '..ptype,5)
				else
					nextWp = nextWp+1
					trigger.action.outTextForUnit(pl:getID(),'['..doneWp..'/'..wpCount..']['..z..']\n\nName: '..pname..'\nTime: '..time-startTime..' sec\nAircraft: '..ptype,5)
				end
				
				break
			end
		end
		
		pdata[pname].nextWp = nextWp
		pdata[pname].doneWp = doneWp
		pdata[pname].startTime = startTime
		pdata[pname].endTime = endTime
	end
	
	
	return time+0.1
end,{},timer.getTime()+2)

local ev = {}
function ev:onEvent(event)
	if (event.id==20 or event.id==15) and event.initiator and event.initiator.getPlayerName then
		local pname = event.initiator:getPlayerName()
		if pname then
			pdata[pname] = {nextWp = 1, doneWp = 0, startTime = 0, endTime = 0}
		end
	end
end

world.addEventHandler(ev)

missionCommands.addCommand('Show leaderboard', nil, function()
	local sorted = {}

	for i,v in pairs(playerBest) do table.insert(sorted,{i,v}) end
	
	table.sort(sorted, function(a,b) return a[2].time< b[2].time end)
	
	local outstr = "Leaderboard"
	for i,v in ipairs(sorted) do
		outstr = outstr..'\n'..i..'. '..v[1]..' ['..v[2].type..'] '..v[2].time..' sec'
	end
	
	trigger.action.outText(outstr, 30)
end)