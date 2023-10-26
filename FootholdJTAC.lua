--[[
FootholdJTAC
## Description:

JTAC lase script.
Standalone version of the JTAC from my Foothold missions.

Load script at mission start then call GCI:new(side) to initialize a GCI for the coalition you choose. 
Side should be 1 for red and 2 for blue coalition.

Needs mist(Mission Scripting Tools) to function.

Load mist before loading this script.

Then you can deploy JTAC from script like this:

    jtacName = 'jtacDrone' --group name of jtac, jtac should be an aircraft, and can optionally be set to invisible and invincible in the mission editor to avoid it being shot down
    deployPoint = trigger.misc.getZone('deployZone').point --get the centerpoint of a triggerzone to deploy jtac above, size of zone does not matter here, we're only using it as an easy source of a coordinate

    Group.getByName(jtacName):destroy() --ensure jtac is removed from mission before we deploy it
    drone = JTAC:new({name = jtacName}) --create jtac object

    --add name of groups to target, jtac will despawn automatically when all these groups are dead
    drone:queueGroup('targetGroup1')
    drone:queueGroup('targetGroup2')
    drone:queueGroup('targetGroup3')
    drone:queueGroup('targetGroup4')

    --spawn jtac at defined point, deployPoint should be a table in the form of {x=number, y=number, z=number}, this is the format that coordinates of trigger zones are returned as
    drone:deployAtPoint(deployPoint) 

    --display radio menu for jtac, this should hide automatically once jtac runs out of targets
    drone:showMenu()

    -- to redeploy to a new location, you only need to queue new targets and call deployAtPoint and showMenu again
    -- to clear targets queue you can call drone:clearTargetQueue()

## Links:

If you'd like to buy me a beer: <https://www.buymeacoffee.com/dzsek>

Makes use of Mission scripting tools (Mist): <https://github.com/mrSkortch/MissionScriptingTools>

@script FootholdJTAC
@author Dzsekeb
]]

JTAC = {}
do
	JTAC.categories = {}
	JTAC.categories['SAM'] = {'SAM SR', 'SAM TR', 'IR Guided SAM','SAM LL','SAM CC'}
	JTAC.categories['Infantry'] = {'Infantry'}
	JTAC.categories['Armor'] = {'Tanks','IFV','APC'}
	JTAC.categories['Support'] = {'Unarmed vehicles','Artillery'}
	
	--{name = 'groupname'}
	function JTAC:new(obj)
		obj = obj or {}
		obj.lasers = {tgt=nil, ir=nil}
		obj.target = nil
		obj.timerReference = nil
		obj.targets = {}
		obj.priority = nil
		obj.jtacMenu = nil
		obj.laserCode = 1688
		obj.side = Group.getByName(obj.name):getCoalition()
		setmetatable(obj, self)
		self.__index = self
		obj:initCodeListener()
		return obj
	end
	
	function JTAC:initCodeListener()
		local ev = {}
		ev.context = self
		function ev:onEvent(event)
			if event.id == 26 then
				if event.text:find('^jtac%-code:') then
					local s = event.text:gsub('^jtac%-code:', '')
					local code = tonumber(s)
					if code>=1111 and code <= 1788 then
						self.context.laserCode = code
						trigger.action.outTextForCoalition(self.context.side, 'JTAC code set to '..code, 10)
						trigger.action.removeMark(event.idx)
					end
				end
			end
		end
		
		world.addEventHandler(ev)
	end
	
	function JTAC:showMenu()
		local gr = Group.getByName(self.name)
		if not gr then
			return
		end
		
		if not self.jtacMenu then
			self.jtacMenu = missionCommands.addSubMenuForCoalition(self.side, 'JTAC')
			
			missionCommands.addCommandForCoalition(self.side, 'Target report', self.jtacMenu, function(dr)
				if Group.getByName(dr.name) then
					dr:printTarget(true)
				else
					missionCommands.removeItemForCoalition(dr.side, dr.jtacMenu)
					dr.jtacMenu = nil
				end
			end, self)
			
			missionCommands.addCommandForCoalition(self.side, 'Next Target', self.jtacMenu, function(dr)
				if Group.getByName(dr.name) then
					dr:searchTarget()
				else
					missionCommands.removeItemForCoalition(dr.side, dr.jtacMenu)
					dr.jtacMenu = nil
				end
			end, self)
			
			missionCommands.addCommandForCoalition(self.side, 'Deploy Smoke', self.jtacMenu, function(dr)
				if Group.getByName(dr.name) then
					local tgtunit = Unit.getByName(dr.target)
					if tgtunit then
						trigger.action.smoke(tgtunit:getPosition().p, 3)
						trigger.action.outTextForCoalition(dr.side, 'JTAC target marked with ORANGE smoke', 10)
					end
				else
					missionCommands.removeItemForCoalition(dr.side, dr.jtacMenu)
					dr.jtacMenu = nil
				end
			end, self)
			
			local priomenu = missionCommands.addSubMenuForCoalition(self.side, 'Set Priority', self.jtacMenu)
			for i,v in pairs(JTAC.categories) do
				missionCommands.addCommandForCoalition(self.side, i, priomenu, function(dr, cat)
					if Group.getByName(dr.name) then
						dr:setPriority(cat)
						dr:searchTarget()
					else
						missionCommands.removeItemForCoalition(dr.side, dr.jtacMenu)
						dr.jtacMenu = nil
					end
				end, drone, i)
			end
			
			missionCommands.addCommandForCoalition(self.side, "Clear", priomenu, function(dr)
				if Group.getByName(dr.name) then
					dr:clearPriority()
					dr:searchTarget()
				else
					missionCommands.removeItemForCoalition(dr.side, dr.jtacMenu)
					dr.jtacMenu = nil
				end
			end, drone)
		end
	end
	
	function JTAC:setPriority(prio)
		self.priority = JTAC.categories[prio]
		self.prioname = prio
	end
	
	function JTAC:clearPriority()
		self.priority = nil
	end
	
	function JTAC:setTarget(unit)
		
		if self.lasers.tgt then
			self.lasers.tgt:destroy()
			self.lasers.tgt = nil
		end
		
		if self.lasers.ir then
			self.lasers.ir:destroy()
			self.lasers.ir = nil
		end
		
		local me = Group.getByName(self.name)
		if not me then return end
		
		local pnt = unit:getPoint()
		self.lasers.tgt = Spot.createLaser(me:getUnit(1), { x = 0, y = 2.0, z = 0 }, pnt, self.laserCode)
		self.lasers.ir = Spot.createInfraRed(me:getUnit(1), { x = 0, y = 2.0, z = 0 }, pnt)
		
		self.target = unit:getName()
	end
	
	function JTAC:printTarget(makeitlast)
		local toprint = ''
		if self.target then
			local tgtunit = Unit.getByName(self.target)
			if tgtunit then
				local pnt = tgtunit:getPoint()
				local tgttype = tgtunit:getTypeName()
				
				if self.priority then
					toprint = 'Priority targets: '..self.prioname..'\n'
				end
				
				toprint = toprint..'Lasing '..tgttype..'\nCode: '..self.laserCode..'\n'
				local lat,lon,alt = coord.LOtoLL(pnt)
				local mgrs = coord.LLtoMGRS(coord.LOtoLL(pnt))
				toprint = toprint..'\nDDM:  '.. mist.tostringLL(lat,lon,3)
				toprint = toprint..'\nDMS:  '.. mist.tostringLL(lat,lon,2,true)
				toprint = toprint..'\nMGRS: '.. mist.tostringMGRS(mgrs, 5)
				toprint = toprint..'\n\nAlt: '..math.floor(alt)..'m'..' | '..math.floor(alt*3.280839895)..'ft'
			else
				makeitlast = false
				toprint = 'No Target'
			end
		else
			makeitlast = false
			toprint = 'No target'
		end
		
		local gr = Group.getByName(self.name)
		if makeitlast then
			trigger.action.outTextForCoalition(gr:getCoalition(), toprint, 60)
		else
			trigger.action.outTextForCoalition(gr:getCoalition(), toprint, 10)
		end
	end
	
	function JTAC:clearTarget()
		self.target = nil
	
		if self.lasers.tgt then
			self.lasers.tgt:destroy()
			self.lasers.tgt = nil
		end
		
		if self.lasers.ir then
			self.lasers.ir:destroy()
			self.lasers.ir = nil
		end
		
		if self.timerReference then
			mist.removeFunction(self.timerReference)
			self.timerReference = nil
		end
		
		local gr = Group.getByName(self.name)
		if gr then
			gr:destroy()
			missionCommands.removeItemForCoalition(self.side, self.jtacMenu)
			self.jtacMenu = nil
		end
	end
	
	function JTAC:searchTarget()
		local gr = Group.getByName(self.name)
		if gr then
			if self.targets then
				local viabletgts = {}
				for i,v in pairs(self.targets) do
					local tgtgr = Group.getByName(v)
					if tgtgr and tgtgr:getSize()>0 then
						for i2,v2 in ipairs(tgtgr:getUnits()) do
							if v2:getLife()>=1 then
								table.insert(viabletgts, v2)
							end
						end
					end
				end
				
				if self.priority then
					local priorityTargets = {}
					for i,v in ipairs(viabletgts) do
						for i2,v2 in ipairs(self.priority) do
							if v:hasAttribute(v2) and v:getLife()>=1 then
								table.insert(priorityTargets, v)
								break
							end
						end
					end
					
					if #priorityTargets>0 then
						viabletgts = priorityTargets
					else
						self:clearPriority()
						trigger.action.outTextForCoalition(gr:getCoalition(), 'JTAC: No priority targets found', 10)
					end
				end
				
				if #viabletgts>0 then
					local chosentgt = math.random(1, #viabletgts)
					self:setTarget(viabletgts[chosentgt])
					self:printTarget()
				else
					self:clearTarget()
				end
			else
				self:clearTarget()
			end
		end
	end
	
	function JTAC:searchIfNoTarget()
		if Group.getByName(self.name) then
			if not self.target or not Unit.getByName(self.target) then
				self:searchTarget()
			elseif self.target then
				local un = Unit.getByName(self.target)
				if un then
					if un:getLife()>=1 then
						self:setTarget(un)
					else
						self:searchTarget()
					end
				end
			end
		else
			self:clearTarget()
		end
	end
	
	function JTAC:queueGroup(grname)
		self.targets = self.targets or {}
		table.insert(self.targets, grname)
	end
	
	function JTAC:clearTargetQueue()
		self.targets = {}
	end
	
	function JTAC:deployAtPoint(point) -- point = { x=number, y=number, z=number}
		local p = point
		local vars = {}
		vars.gpName = self.name
		vars.action = 'respawn' 
		vars.point = {x=p.x, y=5000, z = p.z}
		mist.teleportToPoint(vars)
		
		mist.scheduleFunction(self.setOrbit, {self, p}, timer.getTime()+1)
		
		if not self.timerReference then
			self.timerReference = mist.scheduleFunction(self.searchIfNoTarget, {self}, timer.getTime()+5, 5)
		end
	end
	
	function JTAC:setOrbit(point)
		local gr = Group.getByName(self.name)
		if not gr then 
			return
		end
		
		local cnt = gr:getController()
		cnt:setCommand({ 
			id = 'SetInvisible', 
			params = { 
				value = true 
			} 
		})
  
		cnt:setTask({ 
			id = 'Orbit', 
			params = { 
				pattern = 'Circle',
				point = {x = point.x, y=point.z},
				altitude = 5000
			} 
		})
		
		self:searchTarget()
	end
end