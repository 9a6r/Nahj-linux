-- Focus: the timer in the desk's Focus tab (the panel out of the right frame). `ft_state` is 0 ready, 1 running, 2 paused, 3 done;
-- `ft_prog` is the fraction left (the ring), `ft_time` the clock. Starting also silences notifications and keeps the machine awake
-- for that long: the scene sends those two (`dnd_for`, `caf_for`) itself when its switches are on. The end is kept as a time, not a
-- count of ticks, so a busy moment does not make it run long.
return function()
    local total, left, state, ends = 30 * 60, 30 * 60, 0, 0
    local function show()
        text.ft_time = string.format("%02d:%02d", math.floor(left / 60), left % 60)
        fact.ft_prog = total > 0 and left / total or 1
        fact.ft_state = state
    end
    on("ft_set", function(m)
        if (state == 0 or state == 3) and type(m) == "number" and m > 0 then
            total, left, state = m * 60, m * 60, 0
            show()
        end
    end)
    on("ft_toggle", function(m)
        if state == 1 then
            left = math.max(0, ends - os.time())
            state = 2
        elseif state == 2 then
            ends = os.time() + left
            state = 1
        elseif type(m) == "number" and m > 0 then
            total, left = m * 60, m * 60
            ends = os.time() + left
            state = 1
        end
        show()
    end)
    on("ft_reset", function(m)
        state = 0
        if type(m) == "number" and m > 0 then total = m * 60 end
        left = total
        show()
    end)
    every(1000, function()
        if state ~= 1 then return end
        left = math.max(0, ends - os.time())
        if left == 0 then
            state = 3
            if tonumber(fact.ft_mode) == 1 then
                pcall(run, "notify-send", { "-a", "Timer", "Timer finished", string.format("%d min", math.floor(total / 60 + 0.5)) }, function() end)
            else
                pcall(run, "notify-send", { "-a", "Focus", "Focus finished", "Time for a break" }, function() end)
            end
        end
        show()
    end)
    show()

    -- The stopwatch (the Focus tab's third mode): `sw_time` is the time it has run (h:mm:ss past an hour), `sw_prog` how far round the current
    -- minute it is (the ring), and the last laps go in `sw_laps`, newest first. Kept as times, not counted ticks, like the countdown.
    local sw = { state = 0, since = 0, acc = 0, laps = {}, last = 0 }
    local function sw_now() return sw.acc + (sw.state == 1 and (os.time() - sw.since) or 0) end
    local function clock(t)
        t = math.max(0, math.floor(t))
        if t >= 3600 then return string.format("%d:%02d:%02d", t // 3600, (t // 60) % 60, t % 60) end
        return string.format("%02d:%02d", t // 60, t % 60)
    end
    local function sw_show()
        local t = sw_now()
        text.sw_time = clock(t)
        fact.sw_prog = (t % 60) / 60
        fact.sw_state = sw.state
        local parts = {}
        for i = #sw.laps, math.max(1, #sw.laps - 3), -1 do
            parts[#parts + 1] = string.format("Lap %d · %s", i, clock(sw.laps[i]))
        end
        text.sw_laps = table.concat(parts, "     ")
        fact.sw_nlaps = #sw.laps
    end
    on("sw_toggle", function()
        if sw.state == 1 then
            sw.acc, sw.state = sw_now(), 2
        else
            sw.since, sw.state = os.time(), 1
        end
        sw_show()
    end)
    on("sw_lap", function()
        if sw.state ~= 1 then return end
        local t = sw_now()
        sw.laps[#sw.laps + 1] = t - sw.last
        sw.last = t
        sw_show()
    end)
    on("sw_reset", function()
        sw.state, sw.acc, sw.since, sw.last, sw.laps = 0, 0, 0, 0, {}
        sw_show()
    end)
    every(1000, function() if sw.state == 1 then sw_show() end end)
    sw_show()
end
