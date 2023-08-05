StreamCounter = {}
StreamCounter.playerOfInterest = "Dzsek"

do
    StreamCounter.stats = {
        helokills = 'Heli Kills',
        jetkills = 'Jet Kills',
        agkills = 'A/G Kills',
        ejects = 'Ejects',
        deaths = 'Deaths',
        rank = 'Rank',
        xp = 'XP'
    }

    StreamCounter.fnames = {
        helokills = 'helikills.txt',
        jetkills = 'jetkills.txt',
        agkills = 'agkills.txt',
        ejects = 'ejects.txt',
        deaths = 'deaths.txt',
        rank = 'rank.txt',
        xp = 'xp.txt'
    }

    local JSON = (loadfile('Scripts/JSON.lua'))()

    StreamCounter.loadTable = function(fn)
        local filename = StreamCounter.dir..fn
        if lfs.attributes(filename) then
            local File = io.open(filename, "r")
            local str = File:read('*all')
            File:close()

            return JSON:decode(str)
        end
    end

    StreamCounter.saveTable = function (fn, data)
        local filename = StreamCounter.dir..fn
		local str = JSON:encode(data)
		local File = io.open(filename, "w")
		File:write(str)
		File:close()
	end

    StreamCounter.saveText = function (fn, text)
        local filename = StreamCounter.dir..fn
        local File = io.open(filename, "w")
		File:write(text)
		File:close()
    end

    StreamCounter.saveStat = function(stat, file)
        StreamCounter.saveText(file, '['..stat..': '..StreamCounter.data[stat]..']')
    end

    StreamCounter.incrementStat = function(stat, file)
        StreamCounter.data[stat] = StreamCounter.data[stat] + 1
        StreamCounter.saveTable('data.json', StreamCounter.data)
        StreamCounter.saveStat(stat, file)
    end

    StreamCounter.updateStat = function(stat, file, content)
        StreamCounter.data[stat] = content
        StreamCounter.saveTable('data.json', StreamCounter.data)
        StreamCounter.saveStat(stat, file)
    end


    local dir = lfs.writedir()..'StreamData/'
    lfs.mkdir(dir)
    StreamCounter.dir = dir

    local save = StreamCounter.loadTable('data.json')
    if save then 
        StreamCounter.data = save
    else
        StreamCounter.data = {
            [StreamCounter.stats.helokills] = 0,
            [StreamCounter.stats.jetkills] = 0,
            [StreamCounter.stats.agkills] = 0,
            [StreamCounter.stats.ejects] = 0,
            [StreamCounter.stats.deaths] = 0,
            [StreamCounter.stats.rank] = 'New recruit',
            [StreamCounter.stats.xp] = 0
        }
    end

    StreamCounter.saveStat(StreamCounter.stats.helokills,StreamCounter.fnames.helokills)
    StreamCounter.saveStat(StreamCounter.stats.jetkills,StreamCounter.fnames.jetkills)
    StreamCounter.saveStat(StreamCounter.stats.agkills,StreamCounter.fnames.agkills)
    StreamCounter.saveStat(StreamCounter.stats.ejects,StreamCounter.fnames.ejects)
    StreamCounter.saveStat(StreamCounter.stats.deaths,StreamCounter.fnames.deaths)
    StreamCounter.saveStat(StreamCounter.stats.rank,StreamCounter.fnames.rank)
    StreamCounter.saveStat(StreamCounter.stats.xp,StreamCounter.fnames.xp)

    world.addEventHandler({
        onEvent = function(self, event)
            if event.initiator and event.initiator.getPlayerName and event.initiator:getPlayerName() then
                if event.initiator:getPlayerName() == StreamCounter.playerOfInterest then
                    if event.id == world.event.S_EVENT_KILL then
                        if event.target then
                            if event.target:hasAttribute('Planes') then
                                StreamCounter.incrementStat(StreamCounter.stats.jetkills,StreamCounter.fnames.jetkills)
                            elseif event.target:hasAttribute('Helicopters') then
                                StreamCounter.incrementStat(StreamCounter.stats.helokills,StreamCounter.fnames.helokills)
                            elseif event.target:hasAttribute('Ground Units') or event.target:hasAttribute('Buildings') or event.target:hasAttribute('Ships') then
                                StreamCounter.incrementStat(StreamCounter.stats.agkills,StreamCounter.fnames.agkills)
                            end
                        end
                    elseif event.id == world.event.S_EVENT_EJECTION then
                        StreamCounter.incrementStat(StreamCounter.stats.ejects,StreamCounter.fnames.ejects)
                    elseif event.id == world.event.S_EVENT_PILOT_DEAD then
                        StreamCounter.incrementStat(StreamCounter.stats.deaths,StreamCounter.fnames.deaths)
                    end
                end
            end
        end
    })

    if pt then
        timer.scheduleFunction(function(param, time)
            if pt then
                local rank = pt:getPlayerRank(StreamCounter.playerOfInterest) 
                if rank then
                    StreamCounter.updateStat(StreamCounter.stats.rank, StreamCounter.fnames.rank, rank.name)
                end

                if pt.stats[StreamCounter.playerOfInterest] then
                    local xp = pt.stats[StreamCounter.playerOfInterest][PlayerTracker.statTypes.xp]
                    if xp then
                        StreamCounter.updateStat(StreamCounter.stats.xp, StreamCounter.fnames.xp, xp)
                    end
                end

                return time+10
            end
        end, nil, timer.getTime()+10)
    end
end