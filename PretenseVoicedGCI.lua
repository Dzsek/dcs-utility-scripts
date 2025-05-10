--[[
PretenseVoicedGCI
## Description:

Simple text and voiced GCI script.
Standalone version of the GCI from my Pretense mission.
Uses coalition EWR, Search Radars and AWACS.

Load script at mission start then call GCI:new(side) to initialize a GCI for the coalition you choose. 
Side should be 1 for red and 2 for blue coalition.

For voice transmissions to work over the radio add the Sounds folder from the repo inside your .miz file. (open the .miz file with 7zip or similar and drop it in the root folder)

See comments below for configuration

By default both text and radio callouts are enabled, and voiced callouts will happen for maximum 3 hot contacts per player, with a 60 second cooldown between callouts.
Default frequencies for voiced callouts are 264.500 AM, 124.500 AM and 34.000 FM.

@script PretenseVoicedGCI
@author Dzsekeb
]]

GCI = {}

do
    GCI.config = {}
    GCI.useRadio = true -- are radio transmissions enabled?
    GCI.textReports = true -- are text gci reports enabled?
    GCI.gciMaxCallouts = 3 --how many voiced callouts to transmit for each player, each time a transmission is triggered, prioritized by distance
    GCI.gciRadioTimeout = 60 -- how long to wait before sending another radio transmission from the last one (min 19 seconds)
    GCI.aspectLevels = {
        ['Hot'] = 1,
        ['Flanking'] = 2,
        ['Beaming'] = 3,
        ['Cold'] = 4
    }
    GCI.minCalloutAspect = 1 -- filter out voiced callouts by aspect, 1 means only Hot, 2 means Hot and Flanking, 3 means Hot, Flanking and Beaming, 4 means all aspects

    GCI.transmission = {}
    GCI.transmission.radio = {
        queue={},
        freqs = { -- define radio frequencies to transmit on here, transmissions will be delivered to all frequencies
            { frequency = 264.5E6, modulation = 0, power=500 }, -- frequency is in mhz, 264.5E6 means 264.500 mhz
            { frequency = 124.5E6, modulation = 0, power=500 }, -- modulation is 0 for AM, 1 for FM
            { frequency = 034E6, modulation = 1, power=500 }, -- power is in watts, source is pos of player who transmission is intended for, so power only really affects other players who are tuned to the same radio
        }
    }

    GCI.playerTracker = {}
    GCI.playerTracker.callsigns = { 'Caveman', 'Casper', 'Banjo', 'Boomer', 'Shaft', 'Wookie', 'Tiny', 'Tool', 'Trash', 'Orca', 'Irish', 'Flex', 'Grip', 'Dice', 'Duck', 'Poet', 'Jack', 'Lego', 'Hurl', 'Spin' }
    table.sort(GCI.playerTracker.callsigns)

    function GCI.playerTracker.getPlayerConfig(player)
        if not GCI.config[player] then
            GCI.config[player] = {
                noMissionWarning = false,
                gci_warning_radius = nil,
                gci_metric = nil,
                gci_callsign = GCI.playerTracker.generateCallsign()
            }
        end

        return GCI.config[player]
    end

    function GCI.playerTracker.setPlayerConfig(player, setting, value)
        local cfg = GCI.playerTracker.getPlayerConfig(player)
        cfg[setting] = value
    end

    function GCI.playerTracker.callsignToString(callsign)
        return callsign.name..' '..callsign.num1..'-'..callsign.num2
    end

    local function isCallsignTaken(choice, config)
        for i,v in pairs(config) do
            if GCI.playerTracker.callsignToString(v.gci_callsign) == GCI.playerTracker.callsignToString(choice) then
                return true
            end
        end
    end

    function GCI.playerTracker.generateCallsign(forcename)
        local choice = ''
        if forcename then
            choice = { name = forcename, num1=1, num2=1 }
        else
            choice = { name = GCI.playerTracker.callsigns[math.random(1,#GCI.playerTracker.callsigns)], num1=1, num2=1 }
            
            if isCallsignTaken(choice, GCI.config) then
                for i=1,10,1 do
                    choice = { name = GCI.playerTracker.callsigns[math.random(1,#GCI.playerTracker.callsigns)], num1=1, num2=1 }
                    if not isCallsignTaken(choice, GCI.config) then
                        break
                    end
                end
            end
        end 

        while isCallsignTaken(choice, GCI.config) do
            if choice.num2 < 9 then 
                choice.num2 = choice.num2 + 1 
            elseif choice.num1 < 9 then
                choice.num1 = choice.num1 + 1
                choice.num2 = 1
            else
                break
            end
        end

        return choice
    end


    GCI.utils = {}
    function GCI.utils.getTableSize(tbl)
		local cnt = 0
		for i,v in pairs(tbl) do cnt=cnt+1 end
		return cnt
    end

    function GCI.utils.log(func)
		return function(p1,p2,p3,p4,p5,p6,p7,p8,p9,p10)
			local err, msg = pcall(func,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10)
			if not err then
				env.info("ERROR - callFunc\n"..msg)
				env.info('Traceback\n'..debug.traceback())
			end
		end
    end

    function GCI.utils.getDist(p1, p2)
        if not p1.z then
			p1.z = p1.y
		end

        if not p2.z then
			p2.z = p2.y
		end

        local distVec = {x = p1.x - p2.x, y = 0, z = p1.z - p2.z}
        return (distVec.x^2 + distVec.z^2)^0.5
	end

    function GCI.utils.getBearing(fromvec, tovec)
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

    function GCI.utils.getHeadingDiff(heading1, heading2)
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

    function GCI.utils.round(number)
		return math.floor(number+0.5)
    end

    GCI.transmission.sounds = {
        ['generic.noise'] = { url='generic.noise.ogg',  length=0.70 },

        --gci
        ['gci.numbers.0'] = { url='gci/gci.numbers.0.ogg', length=0.61},
        ['gci.numbers.1'] = { url='gci/gci.numbers.1.ogg', length=0.41},
        ['gci.numbers.2'] = { url='gci/gci.numbers.2.ogg', length=0.41},
        ['gci.numbers.3'] = { url='gci/gci.numbers.3.ogg', length=0.42},
        ['gci.numbers.4'] = { url='gci/gci.numbers.4.ogg', length=0.51},
        ['gci.numbers.5'] = { url='gci/gci.numbers.5.ogg', length=0.48},
        ['gci.numbers.6'] = { url='gci/gci.numbers.6.ogg', length=0.52},
        ['gci.numbers.7'] = { url='gci/gci.numbers.7.ogg', length=0.56},
        ['gci.numbers.8'] = { url='gci/gci.numbers.8.ogg', length=0.40},
        ['gci.numbers.9'] = { url='gci/gci.numbers.9.ogg', length=0.51},

        ['gci.callsigns.Caveman'] = { url='gci/gci.callsigns.Caveman.ogg', length=0.69},
        ['gci.callsigns.Casper'] = { url='gci/gci.callsigns.Casper.ogg', length=0.66},
        ['gci.callsigns.Banjo'] = { url='gci/gci.callsigns.Banjo.ogg', length=0.72},
        ['gci.callsigns.Boomer'] = { url='gci/gci.callsigns.Boomer.ogg', length=0.48},
        ['gci.callsigns.Shaft'] = { url='gci/gci.callsigns.Shaft.ogg', length=0.57},
        ['gci.callsigns.Wookie'] = { url='gci/gci.callsigns.Wookie.ogg', length=0.53},
        ['gci.callsigns.Tiny'] = { url='gci/gci.callsigns.Tiny.ogg', length=0.52},
        ['gci.callsigns.Tool'] = { url='gci/gci.callsigns.Tool.ogg', length=0.47},
        ['gci.callsigns.Trash'] = { url='gci/gci.callsigns.Trash.ogg', length=0.53},
        ['gci.callsigns.Orca'] = { url='gci/gci.callsigns.Orca.ogg', length=0.53},
        ['gci.callsigns.Irish'] = { url='gci/gci.callsigns.Irish.ogg', length=0.61},
        ['gci.callsigns.Flex'] = { url='gci/gci.callsigns.Flex.ogg', length=0.53},
        ['gci.callsigns.Grip'] = { url='gci/gci.callsigns.Grip.ogg', length=0.39},
        ['gci.callsigns.Dice'] = { url='gci/gci.callsigns.Dice.ogg', length=0.52},
        ['gci.callsigns.Duck'] = { url='gci/gci.callsigns.Duck.ogg', length=0.40},
        ['gci.callsigns.Poet'] = { url='gci/gci.callsigns.Poet.ogg', length=0.50},
        ['gci.callsigns.Jack'] = { url='gci/gci.callsigns.Jack.ogg', length=0.47},
        ['gci.callsigns.Lego'] = { url='gci/gci.callsigns.Lego.ogg', length=0.58},
        ['gci.callsigns.Hurl'] = { url='gci/gci.callsigns.Hurl.ogg', length=0.44},
        ['gci.callsigns.Spin'] = { url='gci/gci.callsigns.Spin.ogg', length=0.57},

        -- 'Trash 1 1, fixed-wing, group of 2, bra: 3 4 6, for: 2 5 miles, at angels 3'
        ['gci.callout.helo'] = { url='gci/gci.callout.helo.ogg', length=0.82}, -- "helo"
        ['gci.callout.fixedwing'] = { url='gci/gci.callout.fixedwing.ogg', length=1.0}, -- "fixed wing"
        ['gci.callout.groupof'] = { url='gci/gci.callout.groupof.ogg', length=0.60}, -- "group of"
        ['gci.callout.bra'] = { url='gci/gci.callout.bra.ogg', length=0.81}, -- "bra"
        ['gci.callout.for'] = { url='gci/gci.callout.for.ogg', length=0.44}, -- "for"
        ['gci.callout.miles'] = { url='gci/gci.callout.miles.ogg', length=0.7}, -- "miles"
        ['gci.callout.atangels'] = { url='gci/gci.callout.atangels.ogg', length=0.58}, -- "at angels"
    }

    function GCI.transmission.gciCallout(radio, callsign, targetType, size, heading, miles, angels, sourcePos)
        local calls = ''
        if callsign then
            calls = {
                'gci.callsigns.'..callsign.name,
                'gci.numbers.'..callsign.num1,
                'gci.numbers.'..callsign.num2,
            }
        else
            calls = {
                'generic.noise'
            }
        end

        if targetType == "HELO" then
            table.insert(calls, 'gci.callout.helo')
        elseif targetType == "FXWG" then
            table.insert(calls, 'gci.callout.fixedwing')
        end

        if size > 1 then
            table.insert(calls, 'gci.callout.groupof')
            table.insert(calls, 'gci.numbers.'..size)
        end

        table.insert(calls, 'gci.callout.bra')

        local hstr = tostring(heading)
        for i=1,#hstr do
            local n = hstr:sub(i,i)
            table.insert(calls, 'gci.numbers.'..n)
        end

        table.insert(calls, 'gci.callout.for')

        local mstr = tostring(miles)
        for i=1,#mstr do
            local n = mstr:sub(i,i)
            table.insert(calls, 'gci.numbers.'..n)
        end
        
        table.insert(calls, 'gci.callout.miles')
        table.insert(calls, 'gci.callout.atangels')

        local astr = tostring(angels)
        for i=1,#astr do
            local n = astr:sub(i,i)
            table.insert(calls, 'gci.numbers.'..n)
        end

        GCI.transmission.queueMultiple(calls, radio, sourcePos)
    end

    function GCI.transmission.queueMultiple(keys, radio, pos)
        for _,key in ipairs(keys) do
            GCI.transmission.queueTransmission(key, radio, pos)
        end
    end

    function GCI.transmission.queueTransmission(key, radio, pos)
        if not GCI.useRadio then return end

        local instant = #radio.queue == 0
        if instant then table.insert(radio.queue, {key='generic.noise', pos=pos}) end

        table.insert(radio.queue, {key=key, pos=pos})

        if instant then
            GCI.transmission.playNext(radio)
        end
    end

    function GCI.transmission.playNext(radio)
        if #radio.queue > 0 then
            local trm = radio.queue[1]

            local sound = GCI.transmission.resolveKey(trm.key)

            local pos = trm.pos

            pos.y = pos.y + 10

            for _,fr in ipairs(radio.freqs) do
                env.info("TransmissionManager - "..sound.url..' '..tostring(fr.frequency)..' '..tostring(fr.modulation))
                trigger.action.radioTransmission(sound.url, pos, fr.modulation, false, fr.frequency, fr.power)
            end

            timer.scheduleFunction(function(param,time)
                table.remove(param.queue, 1)
                GCI.transmission.playNext(param)
            end, radio, timer.getTime()+sound.length+0.05)
        end
    end

    function GCI.transmission.resolveKey(key)
        local trsnd = GCI.transmission.sounds[key]
        if not trsnd then return { url = '', length=0.5 } end

        local url = trsnd.url
        local length = trsnd.length

        return { url='Sounds/'..url, length=length }
    end

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

    local function getCenter(unitslist)
        local center = { x=0,y=0,z=0}
        local count = 0
        for _,u in pairs(unitslist) do
            if u and u:isExist() then
                local up = u:getPoint()
                center = {
                    x = center.x + up.x,
                    y = center.y + up.y,
                    z = center.z + up.z,
                }
                count = count + 1
            end
        end

        center.x = center.x / count
        center.y = center.y / count
        center.z = center.z / count

        return center
    end

    function GCI:registerPlayer(name, unit, warningRadius, metric)
        if warningRadius > 0 then
            local msg = "Warning radius set to "..warningRadius
            if metric then
                msg=msg.."km" 
            else
                msg=msg.."nm"
            end
            
            local wRadius = 0
            if metric then
                wRadius = warningRadius * 1000
            else
                wRadius = warningRadius * 1852
            end

            local callsign = GCI.playerTracker.getPlayerConfig(name).gci_callsign
            
            self.players[name] = {
                unit = unit, 
                warningRadius = wRadius,
                metric = metric,
                callsign = callsign,
                lastTransmit = timer.getAbsTime() - 60
            }

            msg = '['..GCI.playerTracker.callsignToString(callsign)..'] '..msg
            
            trigger.action.outTextForUnit(unit:getID(), msg, 10)
            GCI.playerTracker.setPlayerConfig(name, "gci_warning_radius", warningRadius)
            GCI.playerTracker.setPlayerConfig(name, "gci_metric", metric)
        else
            self.players[name] = nil
            trigger.action.outTextForUnit(unit:getID(), "GCI Reports disabled", 10)
            GCI.playerTracker.setPlayerConfig(name, "gci_warning_radius", nil)
            GCI.playerTracker.setPlayerConfig(name, "gci_metric", nil)
        end
    end

    function GCI:setCallsign(name, unit, cname)
        local uid = unit:getID()
        
        local ptr = GCI.playerTracker
        local csign = ptr.generateCallsign(cname)
        ptr.setPlayerConfig(name, 'gci_callsign', csign)
        
        trigger.action.outTextForUnit(uid, "GCI callsign set to "..GCI.playerTracker.callsignToString(csign), 10)

        if not self.players[name] then return end
        self.players[name].callsign = csign
    end

    function GCI:start()
        local ev = {}
        ev.context = self
        function ev:onEvent(event)
            local context = self.context
			if (event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT or event.id == world.event.S_EVENT_BIRTH) and event.initiator and event.initiator.getPlayerName then
				local player = event.initiator:getPlayerName()
				if player then
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

                        missionCommands.addCommandForGroup(groupid, '10 KM',  kmMenu, GCI.utils.log(context.registerPlayer), context, player, unit, 10, true)
                        missionCommands.addCommandForGroup(groupid, '25 KM',  kmMenu, GCI.utils.log(context.registerPlayer), context, player, unit, 25, true)
                        missionCommands.addCommandForGroup(groupid, '50 KM',  kmMenu, GCI.utils.log(context.registerPlayer), context, player, unit, 50, true)
                        missionCommands.addCommandForGroup(groupid, '100 KM', kmMenu, GCI.utils.log(context.registerPlayer), context, player, unit, 100, true)
                        missionCommands.addCommandForGroup(groupid, '150 KM', kmMenu, GCI.utils.log(context.registerPlayer), context, player, unit, 150, true)

                        missionCommands.addCommandForGroup(groupid, '5 NM',  nmMenu, GCI.utils.log(context.registerPlayer), context, player, unit, 5, false)
                        missionCommands.addCommandForGroup(groupid, '10 NM', nmMenu, GCI.utils.log(context.registerPlayer), context, player, unit, 10, false)
                        missionCommands.addCommandForGroup(groupid, '25 NM', nmMenu, GCI.utils.log(context.registerPlayer), context, player, unit, 25, false)
                        missionCommands.addCommandForGroup(groupid, '50 NM', nmMenu, GCI.utils.log(context.registerPlayer), context, player, unit, 50, false)
                        missionCommands.addCommandForGroup(groupid, '80 NM', nmMenu, GCI.utils.log(context.registerPlayer), context, player, unit, 80, false)
                        missionCommands.addCommandForGroup(groupid, 'Disable Warning Radius', menu, GCI.utils.log(context.registerPlayer), context, player, unit, 0, false)

                        
                        local gcicsignmenu = missionCommands.addSubMenuForGroup(groupid, 'Callsign', menu)

                        local sub1 = gcicsignmenu
                        local count = 0
                        for i,v in ipairs(GCI.playerTracker.callsigns) do
                            count = count + 1
                            if count%9==1 and count>1 then
                                sub1 = missionCommands.addSubMenuForGroup(groupid, "More", sub1)
                                missionCommands.addCommandForGroup(groupid, v, sub1, GCI.utils.log(context.setCallsign), context, player, unit, v)
                            else
                                missionCommands.addCommandForGroup(groupid, v, sub1, GCI.utils.log(context.setCallsign), context, player, unit, v)
                            end
                        end

                        context.groupMenus[groupid] = menu
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

                local minsep = 1500
                local minaltsep = 500
                local dectgroups = {}
                local assignedUnits = {}
                for nm,dt in pairs(dect) do
                    for gnm, gdt in pairs(dectgroups) do
                        if gdt.leader and gdt.leader:isExist() and dt and dt:isExist() then
                            if gdt.leader:getDesc().typeName == dt:getDesc().typeName then
                                local dist = GCI.utils.getDist(gdt.center, dt:getPoint())
                                if dist < minsep and math.abs(gdt.center.y-dt:getPoint().y)<minaltsep then
                                    gdt.units[nm] = dt
                                    gdt.center = getCenter(gdt.units)
                                    assignedUnits[nm] = true
                                    break
                                end
                            end
                        end
                    end

                    if not assignedUnits[nm] then
                        dectgroups[nm] = { leader = dt, units={}, center = {}}
                        dectgroups[nm].units[nm] = dt
                        dectgroups[nm].center = getCenter(dectgroups[nm].units)
                        assignedUnits[nm] = true
                    end
                end

                for name, data in pairs(self.players) do
                    if data.unit and data.unit:isExist() then
                        local closeUnits = {}

                        local wr = data.warningRadius
                        if wr > 0 then
                            for _,dtg in pairs(dectgroups) do
                                local dt = dtg.leader
                                if dt:isExist() then
                                    local tgtPnt = dtg.center
                                    local dist = GCI.utils.getDist(data.unit:getPoint(), tgtPnt)
                                    if dist <= wr then
                                        local brg = math.floor(GCI.utils.getBearing(data.unit:getPoint(), tgtPnt))

                                        local myPos = data.unit:getPosition()
                                        local tgtPos = dt:getPosition()
                                        local tgtHeading = math.deg(math.atan2(tgtPos.x.z, tgtPos.x.x))
                                        local tgtBearing = GCI.utils.getBearing(tgtPos.p, myPos.p)
            
                                        local diff = math.abs(GCI.utils.getHeadingDiff(tgtBearing, tgtHeading))
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

                                        local type = "UNKN"
                                        if dt:hasAttribute("Helicopters") then
                                            type = "HELO"
                                        elseif dt:hasAttribute("Planes") then
                                            type = "FXWG"
                                        end

                                        table.insert(closeUnits, {
                                            type = type, --dt:getDesc().typeName,
                                            bearing = brg,
                                            range = dist,
                                            altitude = tgtPnt.y,
                                            score = dist*priority,
                                            aspect = aspect,
                                            size = GCI.utils.getTableSize(dtg.units)
                                        })
                                    end
                                end
                            end
                        end

                        env.info("GCI - "..#closeUnits.." enemy units within "..wr.."m of "..name)
                        if #closeUnits > 0 then
                            table.sort(closeUnits, function(a, b) return a.range < b.range end)
                            local strcallsign = GCI.playerTracker.callsignToString(data.callsign)
                            local msg = "GCI Report for ["..strcallsign.."]:\n"
                            local count = 0
                            local callouts = {}
                            for _,tgt in ipairs(closeUnits) do
                                if data.metric then
                                    local km = tgt.range/1000
                                    if km < 1 then
                                        msg = msg..'\n'..tgt.type..'  MERGED'
                                    else
                                        msg = msg..'\n'..tgt.type
                                        msg = msg..'  BRA: '..tgt.bearing..' for '
                                        msg = msg..GCI.utils.round(km)..'km at '
                                        msg = msg..(GCI.utils.round(tgt.altitude/250)*250)..'m, '
                                        msg = msg..tostring(tgt.aspect)
                                        if tgt.size > 1 then msg = msg..',    GROUP of '..tgt.size end
                                    end
                                else
                                    local nm = tgt.range/1852
                                    if nm < 1 then
                                        msg = msg..'\n'..tgt.type..'  MERGED'
                                    else
                                        msg = msg..'\n'..tgt.type
                                        msg = msg..'  BRA: '..tgt.bearing..' for '
                                        msg = msg..GCI.utils.round(nm)..'nm at '
                                        msg = msg..(GCI.utils.round((tgt.altitude/0.3048)/1000)*1000)..'ft, '
                                        msg = msg..tostring(tgt.aspect)
                                        if tgt.size > 1 then msg = msg..',    GROUP of '..tgt.size end
                                    end
                                end
                                
                                if GCI.aspectLevels[tgt.aspect] <= GCI.minCalloutAspect and data.lastTransmit < (timer.getAbsTime()-GCI.gciRadioTimeout) and #callouts <= GCI.gciMaxCallouts then
                                    local miles = GCI.utils.round(tgt.range/1852)
                                    local angels = GCI.utils.round((tgt.altitude/0.3048)/1000)
                                    table.insert(callouts, {
                                        type = tgt.type,
                                        size = tgt.size,
                                        bearing = tgt.bearing,
                                        miles = miles,
                                        angels = angels
                                    })
                                end

                                count = count + 1
                                if count >= 10 then break end
                            end

                            if #callouts > 0 then
                                local sourcePos = data.unit:getPoint()

                                for i,call in ipairs(callouts) do
                                    if i==1 then
                                        GCI.transmission.gciCallout(GCI.transmission.radio, data.callsign, call.type, call.size, call.bearing, call.miles, call.angels, sourcePos)
                                    else
                                        GCI.transmission.gciCallout(GCI.transmission.radio, nil, call.type, call.size, call.bearing, call.miles, call.angels, sourcePos)
                                    end 
                                end

                                data.lastTransmit = timer.getAbsTime()
                            end
                            
                            if GCI.textReports then
                                trigger.action.outTextForUnit(data.unit:getID(), msg, 19)
                            end
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