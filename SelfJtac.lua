SelfJtac = {}

do
    SelfJtac.categories = {}
	SelfJtac.categories['SAM'] = {'SAM SR', 'SAM TR', 'IR Guided SAM','SAM LL','SAM CC'}
	SelfJtac.categories['Infantry'] = {'Infantry'}
	SelfJtac.categories['Armor'] = {'Tanks','IFV','APC'}
	SelfJtac.categories['Support'] = {'Unarmed vehicles','Artillery'}
	SelfJtac.categories['Structures'] = {'StaticObjects'}

    	--{name = 'groupname'}
	function SelfJtac:new(obj)
		obj = obj or {}
		obj.lasers = {tgt=nil, ir=nil}
		obj.target = nil
		obj.priority = nil
		obj.jtacMenu = nil
		obj.laserCode = 1688
        obj.groupID = Group.getByName(obj.name):getID()
		obj.side = Group.getByName(obj.name):getCoalition()
        obj.timer = nil
		setmetatable(obj, self)
		self.__index = self
		return obj
	end

    function SelfJtac:setCode(code)
        if code>=1111 and code <= 1788 then
            self.laserCode = code
            trigger.action.outTextForGroup(self.groupID, 'Laser code set to '..code, 10)
        else
            trigger.action.outTextForGroup(self.groupID, 'Invalid laser code. Must be between 1111 and 1788 ', 10)
        end
    end
	
	function SelfJtac:showMenu()
		local gr = Group.getByName(self.name)
		if not gr then
			return
		end
		
		if not self.jtacMenu then
			self.jtacMenu = missionCommands.addSubMenuForGroup(self.groupID, 'Laser Designator')
			
			missionCommands.addCommandForGroup(self.groupID, 'Target info', self.jtacMenu, function(dr)
				if Group.getByName(dr.name) then
					dr:printTarget(true)
				end
			end, self)
			
			missionCommands.addCommandForGroup(self.groupID, 'Search', self.jtacMenu, function(dr)
				if Group.getByName(dr.name) then
					dr:searchTarget()
				end
			end, self)

            
			missionCommands.addCommandForGroup(self.groupID, 'Clear', self.jtacMenu, function(dr)
				if Group.getByName(dr.name) then
					dr:clearTarget()
                    trigger.action.outTextForGroup(dr.groupID, 'Target cleared', 10)
				end
			end, self)
			
			local priomenu = missionCommands.addSubMenuForGroup(self.groupID, 'Priority', self.jtacMenu)
			for i,v in pairs(SelfJtac.categories) do
				missionCommands.addCommandForGroup(self.groupID, i, priomenu, function(dr, cat)
					if Group.getByName(dr.name) then
						dr:setPriority(cat)
                        if dr.target then
						    dr:searchTarget()
                        end
					end
				end, self, i)
			end

            local dial = missionCommands.addSubMenuForGroup(self.groupID, 'Code', self.jtacMenu)
            for i2=1,7,1 do
                local digit2 = missionCommands.addSubMenuForGroup(self.groupID, '1'..i2..'__', dial)
                for i3=1,9,1 do
                    local digit3 = missionCommands.addSubMenuForGroup(self.groupID, '1'..i2..i3..'_', digit2)
                    for i4=1,9,1 do
                        local code = tonumber('1'..i2..i3..i4)
                        missionCommands.addCommandForGroup(self.groupID, '1'..i2..i3..i4, digit3, self.setCode, self, code)
                    end
                end
            end
			
			missionCommands.addCommandForGroup(self.groupID, "Clear", priomenu, function(dr)
				if Group.getByName(dr.name) then
					dr:clearPriority()
				end
			end, self)
		end
	end
	
	function SelfJtac:setPriority(prio)
		self.priority = SelfJtac.categories[prio]
		self.prioname = prio
        trigger.action.outTextForGroup(self.groupID, 'Focusing on '..prio, 10)
	end
	
	function SelfJtac:clearPriority()
		self.priority = nil
	end
	
	function SelfJtac:setTarget(unit)
		
		local me = Group.getByName(self.name)
		if not me then return end

        local meun = me:getUnit(1)
        local stats = SelfJtac.getAircraftStats(meun:getDesc().typeName)
		
		local pnt = unit:getPoint()

        local unitPos = meun:getPosition()
        local unitheading = math.deg(math.atan2(unitPos.x.z, unitPos.x.x))
        local bearing = SelfJtac.getBearing(meun:getPoint(), pnt)
        local unitDistance = SelfJtac.getDist(pnt, meun:getPoint())
        
        local deviation = math.abs(SelfJtac.getHeadingDiff(unitheading, bearing))

        local from = meun:getPoint()
        from.y = from.y+1.5
        local to = unit:getPoint()
        to.y = to.y+1.5

        if unitDistance > (stats.minDist * 1000) or deviation > stats.maxDeviation or not land.isVisible(from, to) then
            self:clearTarget()
			trigger.action.outTextForGroup(self.groupID, "Target out of bounds, stoping laser", 10)
            return
        end

        local dst = 99999
        if self.prevPnt then
            dst = SelfJtac.getDist(pnt, self.prevPnt)
        end
        
        if not self.prevPnt or dst >= 0.5 then

            
            if self.lasers.tgt then
                self.lasers.tgt:destroy()
                self.lasers.tgt = nil
            end
            
            if self.lasers.ir then
                self.lasers.ir:destroy()
                self.lasers.ir = nil
            end

            self.prevPnt = pnt
            self.lasers.tgt = Spot.createLaser(meun, { x = 0, y = 5.0, z = 0 }, pnt, self.laserCode)
            self.lasers.ir = Spot.createInfraRed(meun, stats.laserOffset, pnt)
        end
		
		self.target = unit:getName()

        timer.scheduleFunction(function(param, time)
            param:updateTarget()
        end, self, timer.getTime()+5)
	end
	
	function SelfJtac:printTarget(makeitlast)
		local toprint = ''
		if self.target then
			local tgtunit = Unit.getByName(self.target)
            local isStructure = false
            if not tgtunit then 
                tgtunit = StaticObject.getByName(self.target)
                isStructure = true
            end

			if tgtunit and tgtunit:isExist() then
				local pnt = tgtunit:getPoint()
                local tgttype = "Unidentified"
                if isStructure then
                    tgttype = "Structure"
                else
                    tgttype = tgtunit:getTypeName()
                end
				
				if self.priority then
					toprint = 'Priority targets: '..self.prioname..'\n'
				end
				
				toprint = toprint..'Lasing '..tgttype..'\nCode: '..self.laserCode..'\n'
                if mist then
                    local lat,lon,alt = coord.LOtoLL(pnt)
                    local mgrs = coord.LLtoMGRS(coord.LOtoLL(pnt))
                    toprint = toprint..'\nDDM:  '.. mist.tostringLL(lat,lon,3)
                    toprint = toprint..'\nDMS:  '.. mist.tostringLL(lat,lon,2,true)
                    toprint = toprint..'\nMGRS: '.. mist.tostringMGRS(mgrs, 5)
                    toprint = toprint..'\n\nAlt: '..math.floor(alt)..'m'..' | '..math.floor(alt*3.280839895)..'ft'
                end
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
			trigger.action.outTextForGroup(self.groupID, toprint, 60)
		else
			trigger.action.outTextForGroup(self.groupID, toprint, 10)
		end
	end
	
	function SelfJtac:clearTarget()
		self.target = nil
        self.prevPnt = nil
	
		if self.lasers.tgt then
			self.lasers.tgt:destroy()
			self.lasers.tgt = nil
		end
		
		if self.lasers.ir then
			self.lasers.ir:destroy()
			self.lasers.ir = nil
		end
	end

	function SelfJtac:updateTarget()
        if Group.getByName(self.name) then
			if self.target then
				local un = Unit.getByName(self.target)
                
				if un and un:isExist() then
					if un:getLife()>=1 then
						self:setTarget(un)
                    else
                        self:clearTarget()
					end
				else
                    local st = StaticObject.getByName(self.target)
                    if st and st:isExist() then
                        self:setTarget(st)
                    else
                        self:clearTarget()
					end
                end
			end
		else
			self:clearTarget()
		end
    end


	function SelfJtac.getBearing(fromvec, tovec)
		local fx = fromvec.x
		local fy = fromvec.z
		
		local tx = tovec.x
		local ty = tovec.z
		
		local brg = math.atan2(ty - fy, tx - fx)
		
		
		if brg < 0 then
			 brg = brg + 2 * math.pi
		end
		
		brg = brg * 180 / math.pi
		

		return brg
	end

	function SelfJtac.getHeadingDiff(heading1, heading2) -- heading1 + result == heading2
		local diff = heading1 - heading2
		local absDiff = math.abs(diff)
		local complementaryAngle = 360 - absDiff
	
		if absDiff <= 180 then 
			return -diff
		elseif heading1 > heading2 then
			return complementaryAngle
		else
			return -complementaryAngle
		end
	end

    function SelfJtac.getDist(point1, point2)
        local vec = {x = point1.x - point2.x, y = point1.y - point2.y, z = point1.z - point2.z}
        return (vec.x^2 + vec.y^2 + vec.z^2)^0.5
    end
	
	function SelfJtac:searchTarget()
		local gr = Group.getByName(self.name)
		if gr and gr:isExist() then
            local un = gr:getUnit(1)
            local stats = SelfJtac.getAircraftStats(un:getDesc().typeName)

            local ppos = un:getPoint()
            local volume = {
                id = world.VolumeType.SPHERE,
                params = {
                    point = {x=ppos.x, z=ppos.z, y=land.getHeight({x = ppos.x, y = ppos.z})},
                    radius = stats.minDist*1000
                }
            }

            local targets = {}
            world.searchObjects({Object.Category.UNIT, Object.Category.STATIC}, volume, function(unit, collection)
                if unit and unit:isExist() then 
                    collection[unit:getName()] = unit
                end

                return true
            end, targets)

            local viabletgts = {}
            for i,v in pairs(targets) do
                if v and v:isExist() and v:getLife()>=1 and i ~= un:getName() and v:getCoalition()~=un:getCoalition() then
                    local unitPos = un:getPosition()
                    local unitheading = math.deg(math.atan2(unitPos.x.z, unitPos.x.x))
                    local bearing = SelfJtac.getBearing(un:getPoint(), v:getPoint())
                    
                    local deviation = math.abs(SelfJtac.getHeadingDiff(unitheading, bearing))
                    local unitDistance = SelfJtac.getDist(un:getPoint(), v:getPoint())
    
                    if unitDistance <= (stats.minDist*1000) and deviation <= stats.maxDeviation then
                        local from = un:getPoint()
                        from.y = from.y+1.5
                        local to = v:getPoint()
                        to.y = to.y+1.5
                        if land.isVisible(from, to) then
                            table.insert(viabletgts, v)
                        end
                    end
                end
            end
            
            if self.priority then
                local priorityTargets = {}
                for i,v in ipairs(viabletgts) do
                    for i2,v2 in ipairs(self.priority) do
                        if v2 == "StaticObjects" and Object.getCategory(v) == Object.Category.STATIC then
                            table.insert(priorityTargets, v)
                            break
                        elseif v:hasAttribute(v2) and v:getLife()>=1 then
                            table.insert(priorityTargets, v)
                            break
                        end
                    end
                end
                
                if #priorityTargets>0 then
                    viabletgts = priorityTargets
                else
                    trigger.action.outTextForGroup(self.groupID, 'No priority targets found, searching for anything...', 10)
                end
            end
            
            if #viabletgts>0 then
                local chosentgt = math.random(1, #viabletgts)
                self:setTarget(viabletgts[chosentgt])
                self:printTarget()
            else
                trigger.action.outTextForGroup(self.groupID, 'No targets found', 10)
                self:clearTarget()
            end
		end
	end

    function SelfJtac.getAircraftStats(aircraftType)
        local stats = SelfJtac.aircraftStats[aircraftType]
        if not stats then
            return
        end

        return stats
    end

    SelfJtac.aircraftStats = {
        ['SA342L'] =        { minDist = 10, maxDeviation = 120, laserOffset = { x = 1.4, y = 1.1, z = -0.35 }  },
        ['SA342M'] =        { minDist = 15, maxDeviation = 120, laserOffset =  { x = 1.4, y = 1.23, z = -0.35 }   },
        ['UH-60L'] =        { minDist = 10,  maxDeviation = 45,  laserOffset = { x = 4.65, y = -1.8, z = 0 }   },
        ['OH-6A'] =         { minDist = 10,  maxDeviation = 45,  laserOffset = { x = 1.35, y = 0.1, z = 0 }   },
    }

    SelfJtac.jtacs = {}
    local ev = {}
    function ev:onEvent(event)
        if (event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT or event.id == world.event.S_EVENT_BIRTH) and event.initiator and event.initiator.getPlayerName then
            local player = event.initiator:getPlayerName()
            if player then
                local stats = SelfJtac.getAircraftStats(event.initiator:getDesc().typeName)
                if stats then
                    local groupid = event.initiator:getGroup():getID()
                    local groupname = event.initiator:getGroup():getName()
                    if SelfJtac.jtacs[groupid] then
                        local oldjtac = SelfJtac.jtacs[groupid]
                        oldjtac:clearTarget()
                        missionCommands.removeItemForGroup(groupid, oldjtac.jtacMenu)
                        SelfJtac.jtacs[groupid] = nil
                    end

                    if not SelfJtac.jtacs[groupid] then
                        local newjtac = SelfJtac:new({name = groupname})
                        newjtac:showMenu()
                        SelfJtac.jtacs[groupid] = newjtac
                    end
                end
            end
        end
    end
    
    world.addEventHandler(ev)
end

