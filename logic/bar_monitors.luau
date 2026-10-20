-- The Bar page of the settings: which monitors the bar shows on. The scene is always one copy per monitor (`screens: each`:
-- what each copy holds of its own is named per copy, `name.$screen`, which only a copy per monitor has), and with the bar on
-- one monitor the other copies are closed: the scene knows the chosen monitor by its size (`bar_sw`, `bar_sh`, 0 for all of
-- them), so choosing takes effect at once. A vitreus.plm from before, whose `screens:` names one monitor, is moved over
-- once: that line is rewritten and the bar started again, from a command left running on its own (`setsid`) that asks
-- this one to quit and then opens the scene afresh. What was chosen is kept in bar.json; a chosen monitor that is not
-- plugged in puts the bar on all of them until it is back. With `others: "frame"` in bar.json (Settings > Bar, "Frame on the
-- other monitors") the other copies stay open with the frame and its notches (launcher, Settings, desk) and no bar.
return function(with_dirs)
    local B = { pref = nil, file = nil, mons = {}, busy = false, awake = false, others = false }
    local RESTART = [[
P="$1"; L="$2"
export PATH="$HOME/.local/bin:$PATH"
pleamar --say vitreus quit >/dev/null 2>&1
i=0
while pgrep -f "^pleamar --scene $P" >/dev/null && [ $i -lt 15 ]; do sleep 0.2; i=$((i+1)); done
pkill -f "^pleamar --scene $P"
pkill -f "^pleamar --scene .*/vitreus/desktop"  # the desktop widgets restart with the shell (their keepers start them again)
sleep 0.3
[ "$(stat -c %s "$L" 2>/dev/null || echo 0)" -gt 1048576 ] && mv -f "$L" "$L.1"
# under its keeper when there is one (bin/vitreus-keep): a keeper already looking after it starts it again itself
command -v vitreus-keep >/dev/null 2>&1 && exec vitreus-keep "$P" "$L"
exec pleamar --scene "$P" --no-hud >>"$L" 2>&1
]]

    local function connected(name)
        for i, m in ipairs(B.mons) do if m.name == name then return i end end
        return nil
    end
    -- Where the bar should be now: the choice, or all of them while the chosen one is away.
    local function target()
        local pref = B.pref or "all"
        if pref ~= "all" and not connected(pref) then return "all" end
        return pref
    end
    -- What `screens:` has to say for the bar to be on `to`: always every monitor (a file from before says one name, and is moved over).
    local function file_for(to)
        return "all"
    end
    -- Where the bar is now: where the scene was started, or, the scene being on every monitor, the choice.
    local function bar_on()
        if B.file ~= "all" then return connected(B.file) and B.file or "all" end
        return target()
    end

    -- Tell the window gaps where the bar is (it is where the scene was started, not where it is about to go) and what is plugged in.
    local told = nil
    local function publish()
        if B.file == nil or #B.mons == 0 then return end
        local names = {}
        for _, m in ipairs(B.mons) do names[#names + 1] = m.name end
        local on = bar_on()
        -- the scene closes the copies that are not the chosen monitor's: it is told that monitor's size
        local one = B.file == "all" and on ~= "all"
        local thin = one and B.others              -- the other monitors have the frame: their windows get its room
        local m = one and B.mons[connected(on)] or nil
        local sw, sh = m and m.w or 0, m and m.h or 0
        if fact.bar_sw ~= sw then fact.bar_sw = sw end
        if fact.bar_sh ~= sh then fact.bar_sh = sh end
        if fact.bar_others ~= B.others then fact.bar_others = B.others end
        if B.file == "all" then bar_mon.name = on end
        local sig = on .. "|" .. tostring(thin) .. "|" .. table.concat(names, ",")
        if sig == told then return end
        told = sig
        bar_fx.on, bar_fx.mons, bar_fx.thin = on, names, thin
        iris_fx.apply_hypr()
    end

    local function show()
        local pref = B.pref or "all"
        local at = pref ~= "all" and connected(pref) or nil
        fact.bar_scr = at and (at - 1) or -1
        for i = 0, 3 do
            local m = B.mons[i + 1]
            fact["bar_m." .. i .. ".on"] = m ~= nil
            if m then
                text["bar_m." .. i .. ".name"] = m.name
                text["bar_m." .. i .. ".sub"] = m.sub
            end
        end
        if B.busy then
            text.bar_msg = "Moving the bar…"
        elseif pref ~= "all" and not at and #B.mons > 0 then
            text.bar_msg = pref .. " isn't plugged in, so the bar is on every monitor until it's back."
        else
            text.bar_msg = ""
        end
    end

    local function restart(to)
        if B.busy then return end
        if to ~= "all" and not to:match("^[%w%._%-]+$") then return end
        B.busy = true
        show()
        with_dirs(function(d)
            local plm = d.conf .. "/vitreus.plm"
            local value = file_for(to) == "all" and "each max 2" or ('"' .. to .. '"')
            run("sed", { "-i", "-E", "/^    surface \\{/s/screens: [^;]*;/screens: " .. value .. ";/", plm }, function(_, code)
                if code ~= 0 then
                    B.busy = false
                    show()
                    text.bar_msg = "Couldn't change where the bar shows."
                    return
                end
                B.file = file_for(to)
                bar_mon.name = to
                run("setsid", { "-f", "sh", "-c", RESTART, "sh", plm, d.data .. "/vitreus.log" }, function() end)
            end)
        end)
    end

    -- Put the bar where it should be, once what the file says and what is plugged in are both known. Not in the
    -- first seconds after starting, so a monitor that is still waking up does not send it back and forth.
    local function settle()
        if B.busy or B.file == nil or #B.mons == 0 then return end
        if not B.awake then return end
        local to = target()
        if file_for(to) ~= B.file then restart(to) else publish() end
    end

    local function read_mons()
        hypr_monitors(4, function(out, code)
            if code ~= 0 or not out then return end
            local ok, list = pcall(json.decode, out)
            local mons = {}
            if ok and type(list) == "table" then
                for _, j in ipairs(list) do
                    local t = j.transform or 0
                    local tall = t == 1 or t == 3 or t == 5 or t == 7
                    local sc = (j.scale and j.scale > 0) and j.scale or 1
                    local w, h = math.floor((j.width or 0) / sc + 0.5), math.floor((j.height or 0) / sc + 0.5)
                    if tall then w, h = h, w end
                    mons[#mons + 1] = { name = j.name, x = j.x or 0, y = j.y or 0, tall = tall, w = w, h = h }
                end
            else
                -- pleamar-wm's `hyprctl monitors` is text, even with -j: "Monitor <name> (ID 1):", "2560x1440@164.83 at 1440x733" (its sizes already turned by the rotation).
                for name, body in (out .. "\n\n"):gmatch("Monitor (%S+) %(ID %d+%):\n(.-)\n\n") do
                    local w, h, x, y = body:match("(%d+)x(%d+)@[%d%.]+ at (%-?%d+)x(%-?%d+)")
                    if w then mons[#mons + 1] = { name = name, x = tonumber(x), y = tonumber(y), tall = tonumber(h) > tonumber(w), w = tonumber(w), h = tonumber(h) } end
                end
            end
            if #mons == 0 then return end
            table.sort(mons, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
            for i, m in ipairs(mons) do
                local where = #mons == 1 and "" or (i == 1 and "left" or (i == #mons and "right" or "middle"))
                if m.tall then where = where == "" and "portrait" or (where .. ", portrait") end
                m.sub = where
            end
            B.mons = mons
            show()
            publish()
            settle()
        end)
    end

    on("bar_pick_scr", function(i)
        if B.busy then return end
        local pref = "all"
        if i >= 0 then
            local m = B.mons[math.floor(i + 0.5) + 1]
            if not m then return end
            pref = m.name
        end
        B.pref = pref
        pcall(sys.call, "files.write", "bar.json", { screens = pref, others = B.others and "frame" or nil })
        show()
        local to = target()
        if B.file ~= nil and file_for(to) ~= B.file then restart(to) else publish() end
    end)

    -- Settings > Bar's switch: the frame on the other monitors, or nothing there. The scene is on every monitor already, so it is at once.
    on("bar_others_toggle", function()
        B.others = not B.others
        pcall(sys.call, "files.write", "bar.json", { screens = B.pref or "all", others = B.others and "frame" or nil })
        publish()
    end)

    local ok, saved = pcall(sys.ask, "files.read", "bar.json", "json")
    if ok and type(saved) == "table" and type(saved.screens) == "string" then B.pref = saved.screens end
    if ok and type(saved) == "table" and saved.others == "frame" then B.others = true end
    -- What this bar was started with: the `screens:` of the scene's surface.
    with_dirs(function(d)
        run("grep", { "-o", "-m1", "-E", "screens: [^;]*;", d.conf .. "/vitreus.plm" }, function(out)
            local v = (out or ""):match("screens:%s*(.-)%s*;")
            if v == nil then return end
            B.file = v:match('^"([^"]+)"') or "all"
            bar_mon.name = B.file
            if B.pref == nil then B.pref = B.file end
            show()
            publish()
            settle()
        end)
    end)
    read_mons()
    every(5000, read_mons)
    after(8000, function() B.awake = true; settle() end)
end
