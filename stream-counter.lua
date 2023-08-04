StreamCounter = {}
StreamCounter.playerOfInterest = "your name here"

do
    StreamCounter.stats = {
        helokills = 'Heli Kills',
        jetkills = 'Jet Kills',
        agkills = 'A/G Kills',
        ejects = 'Ejects',
        deaths = 'Deaths'
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

    StreamCounter.incrementStat = function(stat, file)
        StreamCounter.data[stat] = StreamCounter.data[stat] + 1
        StreamCounter.saveTable('data.json', StreamCounter.data)
        StreamCounter.saveText(file, '['..stat..': '..StreamCounter.data[stat]..']')
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
            [StreamCounter.stats.deaths] = 0
        }
    end

    world.addEventHandler({
        onEvent = function(self, event)
            if event.initiator and event.initiator.getPlayerName and event.initiator:getPlayerName() then
                if event.initiator:getPlayerName() == StreamCounter.playerOfInterest then
                    if event.id == world.event.S_EVENT_KILL then
                        if event.target then
                            if event.target:hasAttribute('Planes') then
                                StreamCounter.incrementStat(StreamCounter.stats.jetkills,'jetkills.txt')
                            elseif event.target:hasAttribute('Helicopters') then
                                StreamCounter.incrementStat(StreamCounter.stats.helokills,'helikills.txt')
                            elseif event.target:hasAttribute('Ground Units') or event.target:hasAttribute('Buildings') or event.target:hasAttribute('Ships') then
                                StreamCounter.incrementStat(StreamCounter.stats.agkills,'agkills.txt')
                            end
                        end
                    elseif event.id == world.event.S_EVENT_EJECTION then
                        StreamCounter.incrementStat(StreamCounter.stats.ejects,'ejects.txt')
                    elseif event.id == world.event.S_EVENT_PILOT_DEAD then
                        StreamCounter.incrementStat(StreamCounter.stats.deaths,'deaths.txt')
                    end
                end
            end
        end
    })
end