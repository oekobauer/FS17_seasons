---------------------------------------------------------------------------------------------------------
-- WEATHER MANAGER SCRIPT
---------------------------------------------------------------------------------------------------------
-- Purpose:  to create and manage the weather
-- Authors:  Authors:  ian898, Jarvixes, theSeb, reallogger
--

ssWeatherManager = {}
ssWeatherManager.forecast = {} --day of week, low temp, high temp, weather condition
ssWeatherManager.forecastLength = 8
ssWeatherManager.snowDepth = 0
ssWeatherManager.rains = {};

function ssWeatherManager:loadMap(name)
    g_currentMission.environment:addDayChangeListener(self)
    g_currentMission.environment:addHourChangeListener(self)

    g_currentMission.environment.minRainInterval = 1
    g_currentMission.environment.minRainDuration = 30*60*60*1000
    g_currentMission.environment.maxRainInterval = 1
    g_currentMission.environment.maxRainDuration = 30*60*60*1000
    g_currentMission.environment.rainForecastDays = self.forecastLength
    g_currentMission.environment.autoRain = 'false'
    
    -- FIXME: should only be done on server
    self:buildForecast() -- Should be read from savegame
    -- self.snowDepth = -- Enable read from savegame
    --self.rains = g_currentMission.environment.rains -- should only be done for a fresh savegame, otherwise read from savegame
end

function ssWeatherManager:deleteMap()
end

function ssWeatherManager:mouseEvent(posX, posY, isDown, isUp, button)
end

function ssWeatherManager:keyEvent(unicode, sym, modifier, isDown)
end

function ssWeatherManager:update(dt)
end

function ssWeatherManager:draw()
end

function ssWeatherManager:buildForecast()
    local startDayNum = ssSeasonsUtil:currentDayNumber()
    local ssTmax
    --log("Building forecast based on today day num: " .. startDayNum)

    self.forecast = {}

    for n = 1, self.forecastLength do
        oneDayForecast = {}
        local oneDayRain = {}
        local ssTmax = {}
        local Tmaxmean = {}

        oneDayForecast.day = startDayNum + n - 1 -- To match forecast with actual game
        oneDayForecast.weekDay =  ssSeasonsUtil:dayName(startDayNum + n - 1)
        oneDayForecast.season = ssSeasonsUtil:seasonName(startDayNum + n - 1)

        ssTmax = self:Tmax(oneDayForecast.season)

        oneDayForecast.highTemp = ssSeasonsUtil:ssNormDist(ssTmax[2],2.5)
        oneDayForecast.lowTemp = ssSeasonsUtil:ssNormDist(0,2) + 0.75 * ssTmax[2]-5
        --oneDayForecast.weatherState = self:getWeatherStateForDay(startDayNum + n)

        if n == 1 then
            --log('First day and endDayTime = 0')
            oneDayRain = self:updateRain(oneDayForecast,0)
        else
            if oneDayForecast.day == self.rains[n-1].endDay then
                --log('Day ',n,' and endDayTime = ',self.rains[n-1].endDayTime)
                oneDayRain = self:updateRain(oneDayForecast,self.rains[n-1].endDayTime)
            else
                --log('Day ',n,' and endDayTime = 0')
                oneDayRain = self:updateRain(oneDayForecast,0)
            end
        end
        oneDayForecast.weatherState = oneDayRain.rainTypeId

        table.insert(self.forecast, oneDayForecast)
        table.insert(self.rains, oneDayRain)

        --log'Here is the rains table'
        --print_r(self.rains)

    end

    --log('The original raintable')
    --print_r(g_currentMission.environment.rains)

    g_currentMission.environment.rains = {}
    self:switchRainHail()
    self:owRaintable()

    --print_r(self.forecast)
    --print_r(g_currentMission.environment.rains)
end

function ssWeatherManager:updateForecast()
    local dayNum = ssSeasonsUtil:currentDayNumber() + self.forecastLength-1;
    --log("Updating forecast based on today day num: " .. dayNum);
    local oneDayRain = {}

    table.remove(self.forecast,1)

    oneDayForecast = {};
    local ssTmax = {};

    oneDayForecast.day = dayNum; -- To match forecast with actual game
    oneDayForecast.weekDay =  ssSeasonsUtil:dayName(dayNum);
    oneDayForecast.season = ssSeasonsUtil:seasonName(dayNum)

    if self.forecast[self.forecastLength-1].season == oneDayForecast.season then
        --Seasonal average for a day in the season
        ssTmax = self:Tmax(oneDayForecast.season)
        oneDayForecast.Tmaxmean = self.forecast[self.forecastLength-1].Tmaxmean

    elseif self.forecast[self.forecastLength-1].season ~= oneDayForecast.season then
        --Seasonal average for a day in the next season
        ssTmax = self:Tmax(oneDayForecast.season)
        oneDayForecast.Tmaxmean = ssSeasonsUtil:ssTriDist(ssTmax)

    end

    oneDayForecast.highTemp = ssSeasonsUtil:ssNormDist(ssTmax[2],2.5)
    oneDayForecast.lowTemp = ssSeasonsUtil:ssNormDist(0,2) + 0.75 * ssTmax[2]-5
    oneDayForecast.weatherState = self:getWeatherStateForDay(dayNum);

    if oneDayForecast.day == self.rains[self.forecastLength-1].endDay then
        oneDayRain = self:updateRain(oneDayForecast,self.rains[self.forecastLength-1].endDayTime)
    else
        oneDayRain = self:updateRain(oneDayForecast,0)
    end

    oneDayForecast.weatherState = oneDayRain.rainTypeId

    table.insert(self.forecast, oneDayForecast)
    table.insert(self.rains, oneDayRain)

    self:switchRainHail()
    self:owRaintable()

    --print_r(self.forecast)
    --print_r(g_currentMission.environment.rains)
    table.remove(self.rains,1)
end

-- FIXME: not the best to be iterating within another loop, but since we are only doing this once a day, not a massive issue
--perhaps rewrite so that initial forecast is generated for 7 days and then next day only remove the first element and add the next day?
function ssWeatherManager:getWeatherStateForDay(dayNumber)
    local weatherState = "sun"
    local ssTmax = {}
    local Tmaxmean = {}

    for index, rain in ipairs(g_currentMission.environment.rains) do
        --log("Bad weather predicted for day: " .. tostring(rain.startDay) .. " weather type: " .. rain.rainTypeId .. " index: " .. tostring(index))
        if rain.startDay > dayNumber then
            break
        end
        if (rain.startDay == dayNumber) then
            weatherState = rain.rainTypeId
        end
    end

    --for k, v in pairs( g_currentMission.environment.rainFadeCurve ) do
    --    log (k, v)
    --end

    return weatherState
end

function ssWeatherManager:dayChanged()
    self:updateForecast()
end

function ssWeatherManager:hourChanged()
    self:calculateSnowAccumulation()
end

function ssWeatherManager:Tmax(ss) --sets the minimum, mode and maximum of the seasonal average maximum temperature. Simplification due to unphysical bounds.
    if ss == 'Winter' then
        -- return {5.0,8.6,10.7} --min, mode, max Temps from the data
        return {-3.0,0.6,2.7} --min, mode, max adjusted -7 deg C

    elseif ss == "Spring" then
        return {12.1, 14.2, 17.9} --min, mode, max

    elseif ss == "Summer" then
        return {19.4, 21.7, 26.0} --min, mode, max

    elseif ss == "Autumn" then
        return {14.0, 15.6, 17.3} --min, mode, max
    end
end

-- function to output the temperature during the day and night
function ssWeatherManager:diurnalTemp(hour, minute)
    -- need to have the high temp of the previous day
    -- hour is hour in the day from 0 to 23
    -- minute is minutes from 0 to 59

    prevDayTemp = self.forecast[1].highTemp -- not completely correct, but instead of storing the temp of the previous day

    local currentTime = hour*60 + minute

    if currentTime < 420 then
        currentTemp = (math.cos(((currentTime + 540) / 960) * math.pi / 2)) ^ 3 * (prevDayTemp - self.forecast[1].lowTemp) + self.forecast[1].lowTemp
    elseif currentTime > 900 then
        currentTemp = (math.cos(((currentTime - 900) / 960) * math.pi / 2)) ^ 3 * (self.forecast[1].highTemp - self.forecast[2].lowTemp) + self.forecast[1].lowTemp
    else
        currentTemp = (math.cos((1 - (currentTime -  420) / 480) * math.pi / 2) ^ 3) * (self.forecast[1].highTemp - self.forecast[1].lowTemp) + self.forecast[1].lowTemp
    end

    return currentTemp
end

--- function to keep track of snow accumulation
--- snowDepth in meters
function ssWeatherManager:calculateSnowAccumulation()

    local currentRain = g_currentMission.environment.currentRain
    local currentTemp = ssWeatherManager:diurnalTemp(g_currentMission.environment.currentHour, g_currentMission.environment.currentMinute)
    local currentSnow = self.snowDepth

    --- more radiation during spring
    local meltFactor = 1
    if self.forecast[1].season ~= 'Winter' then
        meltFactor = 5
    end


    if currentRain == nil then
        if currentTemp > -1 then
        -- snow melts at -1 if the sun is shining
        self.snowDepth = self.snowDepth - math.max((currentTemp+1)/1000,0)*meltFactor
        end

    elseif currentRain.rainTypeId == "rain" and currentTemp > 0 then
        -- assume snow melts three times as fast if it rains
        self.snowDepth = self.snowDepth - math.max((currentTemp+1)*3/1000,0)*meltFactor

    elseif currentRain.rainTypeId == "rain" and currentTemp <= 0 then
        -- cold rain acts as hail
        if self.snowDepth < 0 then
            self.snowDepth = 0
        end
        self.snowDepth = self.snowDepth + 10/1000

    elseif currentRain.rainTypeId == "hail" and currentTemp < 0 then
        -- Initial value of 10 mm/hr accumulation rate
        if self.snowDepth < 0 then
            self.snowDepth = 0
        end
        self.snowDepth = self.snowDepth + 10/1000

    elseif currentRain.rainTypeId == "hail" and currentTemp >= 0 then
        -- warm hail acts as rain
        self.snowDepth = self.snowDepth - math.max((currentTemp+1)*3/1000,0)*meltFactor
        --g_currentMission.environment.currentRain.rainTypeId = nil
        --currentRain.rainTypeId = 'rain'

    elseif currentRain.rainTypeId == "cloudy" and currentTemp > 0 then
        -- 75% melting (compared to clear conditions) when there is cloudy and fog
        self.snowDepth = self.snowDepth - math.max((currentTemp+1)*0.75/1000,0)*meltFactor

    elseif currentRain.rainTypeId == "fog" and currentTemp > 0 then
        -- 75% melting (compared to clear conditions) when there is cloudy and fog
        self.snowDepth = self.snowDepth - math.max((currentTemp+1)*0.75/1000,0)*meltFactor

    end




    --log('currentTemp = ', currentTemp," lowTemp = ",self.forecast[1].lowTemp,' highTemp = ',self.forecast[1].highTemp,' snowDepth = ', self.snowDepth)
    --if currentRail ~= nil then
    --    print_r(currentRain)
    --end

    return self.snowDepth
end

--- function for predicting when soil is not workable
function ssWeatherManager:isGroundWorkable()
    local avgSoilTemp = (self.forecast[1].highTemp + self.forecast[1].lowTemp) / 2
    if  avgSoilTemp < 5 then
        return true
    else
        return false
    end
end

function ssWeatherManager:getSnowHeight()
    return self.snowDepth
end

function ssWeatherManager:switchRainHail()
    for index, rain in ipairs(g_currentMission.environment.rains) do
        for jndex, fCast in ipairs(self.forecast) do
             if (rain.startDay == fCast.day) then
                if fCast.lowTemp < -1 and rain.rainTypeId == 'rain' then
                    g_currentMission.environment.rains[index].rainTypeId = 'hail'
                    self.forecast[jndex].weatherState = 'hail'
                elseif fCast.lowTemp >= -1 and rain.rainTypeId == 'hail' then
                    g_currentMission.environment.rains[index].rainTypeId = 'rain'
                    self.forecast[jndex].weatherState = 'rain'
                end
            end
        end
    end
end

function ssWeatherManager:updateRain(oneDayForecast,endRainTime)
    rainFactors = self:_loadRainFactors(oneDayForecast.season)
    
    --log('This is the oneDayForecast')
    --print_r(oneDayForecast)
    local noTime = 'false'
    local oneDayRain = {}

    --while noTime ~= 'true' do 
        local oneRainEvent = {};

        p = self:_randomRain()    
        --log('p = ',p,' p_rain = ',rainFactors.probRain,' p_clouds = ',rainFactors.probClouds)

        if p < rainFactors.probRain then
            oneRainEvent = self:_rainStartEnd(rainFactors.beta,rainFactors.gamma,p,endRainTime)

            if oneDayForecast.lowTemp < 1 then
                oneRainEvent.rainTypeId = "hail" -- forecast snow if temp < 1
            else
                oneRainEvent.rainTypeId = "rain"
            end

        elseif p > rainFactors.probRain and p < rainFactors.probClouds then
            oneRainEvent = self:_rainStartEnd(rainFactors.beta,rainFactors.gamma,p,endRainTime)
            oneRainEvent.rainTypeId = "cloudy"
        elseif oneDayForecast.lowTemp > -1 and oneDayForecast.lowTemp < 2 and endRainTime < 10800000 then
            -- morning fog
            oneRainEvent.startDay = oneDayForecast.day
            oneRainEvent.endDay = oneDayForecast.day
            local dayStart, dayEnd, nightEnd, nightStart = ssTime:calculateStartEndOfDay(oneDayForecast.day) 
            
            oneRainEvent.startDayTime = nightEnd*60*60*1000
            oneRainEvent.endDayTime = (dayStart+1)*60*60*1000+0.000001
            oneRainEvent.duration = oneRainEvent.endDayTime - oneRainEvent.startDayTime
            oneRainEvent.rainTypeId = "fog"
        else
            oneRainEvent.rainTypeId = 'sun'
            oneRainEvent.duration = 0
            oneRainEvent.startDayTime = 0
            oneRainEvent.endDayTime = 0
            oneRainEvent.startDay = oneDayForecast.day
            oneRainEvent.endDay = oneDayForecast.day
        end

        --log('This is the oneRainEvent for day ',oneDayForecast.day)
        --print_r(oneRainEvent)

        --table.insert(oneDayRain,oneRainEvent)
        oneDayRain = oneRainEvent 
        return oneDayRain

        --if oneRainEvent.rainTypeId == 'sun' then
        --    noTime = 'true'
        --    log('justbeforebreak - no rain')
        --
        --    log('This is the oneDayRain')
        --    print_r(oneDayRain)
        --    
        --    return oneDayRain

        --elseif oneRainEvent.endDay > oneDayForecast.day or oneRainEvent.endDayTime > 75600000 then
        --    noTime = 'true'
        --    log('justbeforebreak - with rain')
        -- 
        --    log('This is the oneDayRain')
        --    print_r(oneDayRain)

        --    return oneDayRain
        --end

    --end

end

function ssWeatherManager:_rainStartEnd(beta,gamma,p,endRainTime)
    local oneRainEvent = {};
    
    oneRainEvent.startDay = oneDayForecast.day
    oneRainEvent.duration = math.exp(ssSeasonsUtil:ssLognormDist(beta,gamma,p))*60*60*1000
    -- rain can start from 01:00 (or 1 hour after last rain ended) to 23.00
    oneRainEvent.startDayTime = math.random(3600 + endRainTime,82800) *1000+0.1

    --log("startDayTime ",oneRainEvent.startDayTime)
    --log("oneRainEvent.duration ",oneRainEvent.duration)
    if oneRainEvent.startDayTime + oneRainEvent.duration < 86400000 then
        oneRainEvent.endDay = oneRainEvent.startDay
        oneRainEvent.endDayTime =  oneRainEvent.startDayTime + oneRainEvent.duration + 0.000001
    else
        oneRainEvent.endDay = oneRainEvent.startDay + 1
        oneRainEvent.endDayTime =  oneRainEvent.startDayTime + oneRainEvent.duration - 86400000 + 0.000001
    end

    return oneRainEvent
end

function ssWeatherManager:_randomRain()
    math.random() -- to initiate random number generator
    
    ssTmax = self:Tmax(oneDayForecast.season)

    if oneDayForecast.season == "Winter" or oneDayForecast.season == "Autumn" then
        if oneDayForecast.highTemp > ssTmax[2] then
            p = math.random()^1.5 --increasing probability for precipitation if the temp is high
        else
            p = math.random()^0.75 --decreasing probability for precipitation if the temp is high
        end
    elseif oneDayForecast.season == "Spring" or oneDayForecast.season == "Summer" then
        if oneDayForecast.highTemp < ssTmax[2] then
            p = math.random()^1.5 --increasing probability for precipitation if the temp is high
        else
            p = math.random()^0.75 --decreasing probability for precipitation if the temp is high
        end
    end

    return p
end

function ssWeatherManager:_loadRainFactors(ss)
    -- maybe save factors in a file
    local mu = {}
    local sigma = {}
    local cov = {}
    local r = {}

    if ss == "Winter" then
        mu = 1.6
        sigma = 0.25
        r.probRain = 0.55
        r.probClouds = 0.70
		
    elseif ss == "Spring" then
        mu = 1.1
        sigma = 0.2
        r.probRain = 0.4
        r.probClouds = 0.55

    elseif ss == "Summer" then
        mu = 0.7
        sigma = 0.1
        r.probRain = 0.15
        r.probClouds = 0.30		

    elseif ss == "Autumn" then
        mu = 1.2
        sigma = 0.25
        r.probRain = 0.50
        r.probClouds = 0.65
    end

    cov = (sigma/mu)

    r.beta = 1 / math.sqrt(math.log(1+cov*cov))
    r.gamma = mu / math.sqrt(1+cov*cov)

    return r
end

function ssWeatherManager:owRaintable()

    local rain = {}

    for index=1,self.forecastLength do
        if self.rains[index].rainTypeId ~= "sun" then
            table.insert(rain,self.rains[index])
        end
    end
    g_currentMission.environment.rains = rain

end
