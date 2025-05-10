--[[
PretenseGCI
## Description:

Simple text based GCI script.
Standalone version of the GCI from my Pretense mission.
Uses coalition EWR, Search Radars and AWACS.

Load script at mission start then call GCI:new(side) to initialize a GCI for the coalition you choose. 
Side should be 1 for red and 2 for blue coalition.

## Links:

Pretense: <https://www.digitalcombatsimulator.com/en/files/3331159/>

If you'd like to buy me a beer: <https://www.buymeacoffee.com/dzsek>

@script PretenseGCI
@author Dzsekeb
]]

GCI = {}

do
    function GCI:new(side)
        local o = {}
        o.side = side
        o.tgtSide = 0
        if side == 1 then
            o.tgtSide = 2
        elseif side == 2 then
            o.tgtSide = 1
        end

        o.radars = {}
        o.players = {}
        o.radarTypes = {
            'SAM SR',
            'EWR',
            'AWACS'
        }

        o.groupMenus = {}

        setmetatable(o, self)
		self.__index = self

        o:start()

		return o
    end

	function GCI.getBearing(fromvec, tovec)
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

    function GCI.getHeadingDiff(heading1, heading2) -- heading1 + result == heading2
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

    function GCI.round(number)
		return math.floor(number+0.5)
	end

    function GCI.getDist(p1, p2)
        if not p1.z then
			p1.z = p1.y
		end

        if not p2.z then
			p2.z = p2.y
		end

        local distVec = {x = p1.x - p2.x, y = 0, z = p1.z - p2.z}
        return (distVec.x^2 + distVec.z^2)^0.5
	end

    function GCI:registerPlayer(name, unit, warningRadius, metric)
        if warningRadius > 0 then
            local msg = "Warning radius set to "..warningRadius
            if metric then
                msg=msg.."km" 
            else
                msg=msg.."nm"
            end
            
            if metric then
                warningRadius = warningRadius * 1000
            else
                warningRadius = warningRadius * 1852
            end
            
            self.players[name] = {
                unit = unit, 
                warningRadius = warningRadius,
                metric = metric
            }
            
            trigger.action.outTextForUnit(unit:getID(), msg, 10)
        else
            self.players[name] = nil
            trigger.action.outTextForUnit(unit:getID(), "GCI Reports disabled", 10)
        end
    end

    function GCI:start()
        local ev = {}
        ev.context = self
        function ev:onEvent(event)
            local context = self.context
            if event.id == world.event.S_EVENT_BIRTH and event.initiator and event.initiator.getPlayerName then
				local player = event.initiator:getPlayerName()
				if player and event.initiator:getCoalition() == context.side then
					local groupid = event.initiator:getGroup():getID()
                    local groupname = event.initiator:getGroup():getName()
                    local unit = event.initiator
					
                    if context.groupMenus[groupid] then
                        missionCommands.removeItemForGroup(groupid, context.groupMenus[groupid])
                        context.groupMenus[groupid] = nil
                    end

                    if not context.groupMenus[groupid] then
                        
                        local menu = missionCommands.addSubMenuForGroup(groupid, 'GCI')
                        local setWR = missionCommands.addSubMenuForGroup(groupid, 'Set Warning Radius', menu)
                        local kmMenu = missionCommands.addSubMenuForGroup(groupid, 'KM', setWR)
                        local nmMenu = missionCommands.addSubMenuForGroup(groupid, 'NM', setWR)

                        missionCommands.addCommandForGroup(groupid, '10 KM',  kmMenu, context.registerPlayer, context, player, unit, 10, true)
                        missionCommands.addCommandForGroup(groupid, '25 KM',  kmMenu, context.registerPlayer, context, player, unit, 25, true)
                        missionCommands.addCommandForGroup(groupid, '50 KM',  kmMenu, context.registerPlayer, context, player, unit, 50, true)
                        missionCommands.addCommandForGroup(groupid, '100 KM', kmMenu, context.registerPlayer, context, player, unit, 100, true)
                        missionCommands.addCommandForGroup(groupid, '150 KM', kmMenu, context.registerPlayer, context, player, unit, 150, true)

                        missionCommands.addCommandForGroup(groupid, '5 NM',  nmMenu, context.registerPlayer, context, player, unit, 5, false)
                        missionCommands.addCommandForGroup(groupid, '10 NM', nmMenu, context.registerPlayer, context, player, unit, 10, false)
                        missionCommands.addCommandForGroup(groupid, '25 NM', nmMenu, context.registerPlayer, context, player, unit, 25, false)
                        missionCommands.addCommandForGroup(groupid, '50 NM', nmMenu, context.registerPlayer, context, player, unit, 50, false)
                        missionCommands.addCommandForGroup(groupid, '80 NM', nmMenu, context.registerPlayer, context, player, unit, 80, false)
                        missionCommands.addCommandForGroup(groupid, 'Disable', menu, context.registerPlayer, context, player, unit, 0, false)

                        context.groupMenus[groupid] = menu
                    end
				end
            elseif (event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT or event.id == world.event.S_EVENT_DEAD) and event.initiator and event.initiator.getPlayerName then
                local player = event.initiator:getPlayerName()
				if player then
					local groupid = event.initiator:getGroup():getID()
					
                    if context.groupMenus[groupid] then
                        missionCommands.removeItemForGroup(groupid, context.groupMenus[groupid])
                        context.groupMenus[groupid] = nil
                    end
				end
            end
        end
        
        world.addEventHandler(ev)

        timer.scheduleFunction(function(param, time)
            local self = param.context
            local allunits = coalition.getGroups(self.side)
  
            local radars = {}
            for _,g in ipairs(allunits) do
                for _,u in ipairs(g:getUnits()) do
                    for _,a in ipairs(self.radarTypes) do
                        if u:hasAttribute(a) then
                            table.insert(radars, u)
                            break
                        end
                    end
                end
            end

            self.radars = radars
            env.info("GCI - tracking "..#radars.." radar enabled units")

            return time+10
        end, {context = self}, timer.getTime()+1)

        timer.scheduleFunction(function(param, time)
            local self = param.context

            local plyCount = 0
            for i,v in pairs(self.players) do
                if not v.unit or not v.unit:isExist() then
                    self.players[i] = nil
                else
                    plyCount = plyCount + 1
                end
            end

            env.info("GCI - reporting to "..plyCount.." players")
            if plyCount >0 then
                local dect = {}
                local dcount = 0
                for _,u in ipairs(self.radars) do
                    if u:isExist() then
                        local detected = u:getController():getDetectedTargets(Controller.Detection.RADAR)
                        for _,d in ipairs(detected) do
                            if d and d.object and d.object.isExist and d.object:isExist() and 
                                Object.getCategory(d.object) == Object.Category.UNIT and
                                (d.object:hasAttribute("Planes") or d.object:hasAttribute("Helicopters")) and
                                d.object.getCoalition and
                                d.object:getCoalition() == self.tgtSide then
                                    
                                if not dect[d.object:getName()] then
                                    dect[d.object:getName()] = d.object
                                    dcount = dcount + 1
                                end
                            end
                        end
                    end
                end
                
                env.info("GCI - aware of "..dcount.." enemy units")

                for name, data in pairs(self.players) do
                    if data.unit and data.unit:isExist() then
                        local closeUnits = {}

                        local wr = data.warningRadius
                        if wr > 0 then
                            for _,dt in pairs(dect) do
                                if dt:isExist() then
                                    local tgtPnt = dt:getPoint()
                                    local dist = GCI.getDist(data.unit:getPoint(), tgtPnt)
                                    if dist <= wr then
                                        local brg = math.floor(GCI.getBearing(data.unit:getPoint(), tgtPnt))

                                        local myPos = data.unit:getPosition()
                                        local tgtPos = dt:getPosition()
                                        local tgtHeading = math.deg(math.atan2(tgtPos.x.z, tgtPos.x.x))
                                        local tgtBearing = GCI.getBearing(tgtPos.p, myPos.p)
            
                                        local diff = math.abs(GCI.getHeadingDiff(tgtBearing, tgtHeading))
                                        local aspect = ''
                                        local priority = 1
                                        if diff <= 30 then
                                            aspect = "Hot"
                                            priority = 1
                                        elseif diff <= 60 then
                                            aspect = "Flanking"
                                            priority = 1
                                        elseif diff <= 120 then
                                            aspect = "Beaming"
                                            priority = 2
                                        else
                                            aspect = "Cold"
                                            priority = 3
                                        end

                                        table.insert(closeUnits, {
                                            type = dt:getDesc().typeName,
                                            bearing = brg,
                                            range = dist,
                                            altitude = tgtPnt.y,
                                            score = dist*priority,
                                            aspect = aspect
                                        })
                                    end
                                end
                            end
                        end

                        env.info("GCI - "..#closeUnits.." enemy units within "..wr.."m of "..name)
                        if #closeUnits > 0 then
                            table.sort(closeUnits, function(a, b) return a.range < b.range end)

                            local msg = "GCI Report:\n"
                            local count = 0
                            for _,tgt in ipairs(closeUnits) do
                                if data.metric then
                                    local km = tgt.range/1000
                                    if km < 1 then
                                        msg = msg..'\n'..tgt.type..'  MERGED'
                                    else
                                        msg = msg..'\n'..tgt.type..'  BRA: '..tgt.bearing..' for '
                                        msg = msg..GCI.round(km)..'km at '
                                        msg = msg..(GCI.round(tgt.altitude/250)*250)..'m, '
                                        msg = msg..tostring(tgt.aspect)
                                    end
                                else
                                    local nm = tgt.range/1852
                                    if nm < 1 then
                                        msg = msg..'\n'..tgt.type..'  MERGED'
                                    else
                                        msg = msg..'\n'..tgt.type..'  BRA: '..tgt.bearing..' for '
                                        msg = msg..GCI.round(nm)..'nm at '
                                        msg = msg..(GCI.round((tgt.altitude/0.3048)/1000)*1000)..'ft, '
                                        msg = msg..tostring(tgt.aspect)
                                    end
                                end
                                
                                count = count + 1
                                if count >= 10 then break end
                            end

                            trigger.action.outTextForUnit(data.unit:getID(), msg, 19)
                        end
                    else
                        self.players[name] = nil
                    end
                end
            end

            return time+20
        end, {context = self}, timer.getTime()+6)
    end
end