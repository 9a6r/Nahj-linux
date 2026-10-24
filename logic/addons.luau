-- Add-ons (Settings > Add-ons): scenes people write and keep in ~/.config/pleamar/vitreus-addons/<id>/ (the model is addons/_template/). Each has an
-- addon.toml and a scene; bin/vitreus-addons reads them and leaves `addons.json` in the data folder, and this is that list. The folder is outside the shell's own, so
-- updating Vitreus never touches it. A switch starts the scene under `vitreus-keep` (started again if it stops) or stops it; which are on is kept in addons-state.json,
-- and the ones that are on start with the shell. An add-on is not sandboxed: its scene declares what it runs and reads in its own `permissions`.
return function()
    local MAX = 12
    local list, errors, folder, template = {}, {}, "", ""
    local enabled = {}
    local ready = false
    addon_scenes = addon_scenes or {}           -- the running add-ons' sockets: the palette, the bar's room and the weather are told to them (vitreus.luau)

    -- What the shell tells an add-on, as facts and texts of its scene (`pleamar --say <scene> "fact x 1"`): the palette (`pal_*`, the same facts the desktop clock gets), the
    -- room the bar takes (`room_t/r/b/l`), the theme's look (`look`) and the forecast (`wx_*`, and `wx_d0_*` .. `wx_d6_*` for the days). A scene that does not declare one of
    -- them ignores it. The template (addons/_template) declares them all.
    local function say_all(cmds)
        for _, sock in ipairs(addon_scenes) do
            local args = { "--say", sock }
            for _, c in ipairs(cmds) do args[#args + 1] = c end
            run("pleamar", args, function() end)
        end
    end
    -- The add-on pill (the corner dock's twin): an icon for each add-on that is on and gave one (`icon` in addon.toml). A click on an icon (`adk_go`) opens the add-on's
    -- panel out of the pill if it asked for one (`[drawer]`: the shell draws the glass, the add-on its content, told where by `slot_x`, `slot_y` the middle, `slot_w`,
    -- `slot_h` and whether it is out by `slot_open`), or, for an add-on that is only a window, flips its `slot_open`. One drawer is out at a time (`ax_cur`, the pill's place).
    local pins = {}
    local sizes = {}            -- the size each add-on's panel was left at (by id): used when it opens again
    local winopen = {}
    local function say_one(sock, cmds)
        local args = { "--say", sock }
        for _, c in ipairs(cmds) do args[#args + 1] = c end
        run("pleamar", args, function() end)
    end
    local function cur_pin() return pins[(tonumber(fact.ax_cur) or -1) + 1] end
    local told_open = false
    local function push_slot()
        local cur = cur_pin()
        local open = fact.ax_open == true and fact.ax_hold ~= true and fact.ax_rsz ~= true       -- (the content waits while the panel is pulled or resized, and goes to where it lands)
        told_open = fact.ax_open == true
        for _, a in ipairs(pins) do
            if a.drawer then
                local mine = open and cur == a
                say_one(a.sock, { "fact slot_open " .. tostring(mine), "fact slot_sw " .. tostring(tonumber(fact.ax_sw) or 0), "fact slot_sh " .. tostring(tonumber(fact.ax_sh) or 0), "fact slot_x " .. string.format("%.1f", fact.ax_rx or 0), "fact slot_y " .. string.format("%.1f", fact.ax_ry or 0),
                    "fact slot_w " .. string.format("%.1f", fact.ax_rw or 0), "fact slot_h " .. string.format("%.1f", fact.ax_rh or 0) })
            else
                say_one(a.sock, { "fact slot_open " .. tostring(winopen[a.id] == true) })
            end
        end
    end
    local pill_out = false            -- whether the add-on pill was out at the last `show_slot`, for the room the windows keep clear of it (`dock_fx`, vitreus.luau)
    local function show_slot()
        pins = {}
        local rows, any = {}, false
        for _, a in ipairs(list) do
            if enabled[a.id] and a.icon and #rows < 12 then
                pins[#pins + 1] = a
                rows[#rows + 1] = { icon = a.icon, name = a.name }
                if a.drawer then any = true end
            end
        end
        model.adk_pins = rows
        fact.ax_on = any
        if (#rows > 0) ~= pill_out then pill_out = #rows > 0; dock_fx.a = pill_out; dock_fx.changed() end
        local cur = cur_pin()
        if (tonumber(fact.ax_cur) or -1) >= 0 and not (cur and cur.drawer) then
            fact.ax_cur = -1
            fact.ax_open = false
            after(150, push_slot)         -- (a fact the logic sets itself does not fire `on("fact:…")`: the add-on is told here)
        end
    end
    local function pin_go(i)
        local a = pins[i + 1]
        if not a then return end
        if a.drawer then
            if fact.ax_open == true and tonumber(fact.ax_cur) == i then fact.ax_open = false; after(150, push_slot); return end
            local sz = sizes[a.id]
            fact.ax_w, fact.ax_h = (sz and sz.w or a.drawer.width), (sz and sz.h or a.drawer.height)       -- (before `ax_cur`: the content's place is worked out when that changes)
            text.ax_title = a.name
            fact.ax_cur = i
            fact.ax_open = true
            after(150, push_slot)         -- (as above: it is the logic that set them)
        else
            winopen[a.id] = not winopen[a.id]
            say_one(a.sock, { "fact slot_open " .. tostring(winopen[a.id] == true) })
        end
    end
    on("adk_go", pin_go)
    -- The shell's scene can be read again (a saved edit) and start with its panel shut without anyone telling the add-on, which would keep its content on the screen: while the
    -- panel was last told to be out, it is told again every two seconds, and once a few seconds after this starts.
    every(2000, function() if told_open then push_slot() end end)
    after(8000, push_slot)
    on("ax_toggle", function()       -- from a key: the first add-on in the pill that has a drawer
        for i, a in ipairs(pins) do if a.drawer then pin_go(i - 1) return end end
    end)
    -- (the rules that work out the content's place have run by then)
    on("fact:ax_open", function(v) after(150, push_slot) end)
    on("fact:ax_hold", function(v) after(150, push_slot) end)
    on("fact:ax_cur", function(v) after(150, push_slot) end)
    on("fact:ax_sw", function(v) after(150, push_slot) end)
    on("fact:ax_rsz", function(v) after(150, push_slot) end)

    local function push_wx()
        if #addon_scenes == 0 then return end
        local c = { "fact wx_ok " .. tostring(fact.wx_ok == true), "fact wx_kind " .. tostring(fact.wx_kind or 2), "fact wx_c " .. tostring(fact.wx_c == true),
            "text wx_temp " .. (text.wx_temp or ""), "text wx_desc " .. (text.wx_desc or ""), "text wx_feels " .. (text.wx_feels or ""),
            "text wx_hum " .. (text.wx_hum or ""), "text wx_wind " .. (text.wx_wind or ""), "text wx_rain " .. (text.wx_rain or ""), "text wx_name " .. (text.wx_name or "") }
        for i = 0, 6 do
            local d = model.wx_days and model.wx_days[i + 1]
            if d then
                c[#c + 1] = "text wx_d" .. i .. "_label " .. d.label
                c[#c + 1] = "text wx_d" .. i .. "_hi " .. d.hi
                c[#c + 1] = "text wx_d" .. i .. "_lo " .. d.lo
                c[#c + 1] = "fact wx_d" .. i .. "_kind " .. tostring(d.kind)
            end
        end
        say_all(c)
    end
    function addon_push_wx() pcall(push_wx) end          -- (a mistake here must never cost the shell its forecast)
    function addon_push_all()
        if #addon_scenes == 0 then return end
        iris_fx.push_pal()
        iris_fx.push_room()
        local look = addon_look or 0                 -- (set by vitreus.luau whenever the theme changes)
        say_all({ "fact look " .. look })
        addon_push_wx()
        push_slot()
    end

    local function save()
        pcall(sys.call, "files.write", "addons-state.json", { enabled = enabled, sizes = sizes })
    end
    on("ax_resized", function()       -- a panel was resized: kept for the next time it opens
        local a = cur_pin()
        if not a then return end
        sizes[a.id] = { w = math.floor((tonumber(fact.ax_w) or 0) + 0.5), h = math.floor((tonumber(fact.ax_h) or 0) + 0.5) }
        save()
    end)
    do
        local ok, saved = pcall(sys.ask, "files.read", "addons-state.json", "json")
        if ok and type(saved) == "table" and type(saved.enabled) == "table" then
            for id, v in pairs(saved.enabled) do if v == true then enabled[id] = true end end
        end
        if ok and type(saved) == "table" and type(saved.sizes) == "table" then
            for id, z in pairs(saved.sizes) do if type(z) == "table" and type(z.w) == "number" and type(z.h) == "number" then sizes[id] = { w = z.w, h = z.h } end end
        end
    end

    local function show()
        local rows = {}
        for k, a in ipairs(list) do
            if k > MAX then break end
            local by = a.author ~= "" and ("by " .. a.author) or ""
            if a.version ~= "" then by = (by ~= "" and (by .. "  ·  ") or "") .. "version " .. a.version end
            rows[#rows + 1] = { name = a.name, desc = a.description ~= "" and a.description or "No description", by = by, on = enabled[a.id] == true }
        end
        model.addons = rows
        if #errors > 0 then
            text.ad_note = errors[1] .. (#errors > 1 and ("  (+" .. (#errors - 1) .. " more)") or "")
        elseif #list > MAX then
            text.ad_note = "Only the first " .. MAX .. " add-ons are shown"
        else
            text.ad_note = "Yours go in ~/.config/pleamar/vitreus-addons"
        end
        fact.ad_err = #errors > 0
        show_slot()
        local shown = template:gsub("^/home/[^/]+", "~")
        text.ad_tpl = template ~= "" and ("Templates: " .. shown .. " (a window), " .. shown .. "_drawer") or ""
    end

    local function start(a)
        run("pgrep", { "-f", "pleamar --scene " .. a.scene .. "( |$)" }, function(_, code)
            if code ~= 0 then
                exec_on_desktop('vitreus-keep "' .. a.scene .. '"')
            end
            local known = false
            for _, sk in ipairs(addon_scenes) do if sk == a.sock then known = true end end
            if not known then addon_scenes[#addon_scenes + 1] = a.sock end
            after(2500, addon_push_all)         -- once its scene is up and listening
            after(7000, addon_push_all)
        end)
    end
    local function stop(a)
        -- The keeper first, or it starts the scene again.
        for k, sk in ipairs(addon_scenes) do if sk == a.sock then table.remove(addon_scenes, k) break end end
        run("pkill", { "-f", "vitreus-keep " .. a.scene }, function()
            run("pkill", { "-f", "pleamar --scene " .. a.scene .. "( |$)" }, function() end)
        end)
    end

    local function load_list()
        local ok, f = pcall(sys.ask, "files.read", "addons.json", "json")
        if not ok or type(f) ~= "table" or type(f.addons) ~= "table" then return false end
        local out = {}
        for _, a in ipairs(f.addons) do
            if type(a) == "table" and type(a.id) == "string" and type(a.name) == "string" and type(a.scene) == "string" then
                a.description = type(a.description) == "string" and a.description or ""
                a.author = type(a.author) == "string" and a.author or ""
                a.version = type(a.version) == "string" and a.version or ""
                a.drawer = type(a.drawer) == "table" and a.drawer or nil
                a.icon = type(a.icon) == "string" and a.icon or nil
                a.wallpaper = type(a.wallpaper) == "table" and a.wallpaper or nil
                out[#out + 1] = a
            end
        end
        list = out
        errors = type(f.errors) == "table" and f.errors or {}
        folder = type(f.folder) == "string" and f.folder or ""
        template = type(f.template) == "string" and f.template or ""
        return true
    end

    -- The add-on that frames wallpapers (`[wallpaper] frames = true` in its addon.toml): the first that is on and running, by its socket; nil when there is none
    -- (logic/wallpaper_hook.luau asks this before every wallpaper it sets).
    function addon_framer()
        for _, a in ipairs(list) do
            if enabled[a.id] and a.wallpaper and a.wallpaper.frames == true then
                for _, sk in ipairs(addon_scenes) do if sk == a.sock then return a.sock end end
            end
        end
        return nil
    end

    local function refresh(first)
        local data = sys.ask("files.folder")
        if type(data) ~= "string" then return end
        run("vitreus-addons", { data }, function(_, code)
            if code ~= 0 or not load_list() then return end
            show()
            if first then
                ready = true
                for k, a in ipairs(list) do if enabled[a.id] then start(a) end end
            end
        end)
    end

    on("addons_refresh", function() refresh(false) end)
    on("addon_toggle", function(k)
        local a = list[(tonumber(k) or -1) + 1]
        if not a or not ready then return end
        if enabled[a.id] then enabled[a.id] = nil; stop(a) else enabled[a.id] = true; start(a) end
        save()
        show()
    end)
    show()
    after(5000, function() refresh(true) end)       -- with the desktop's own scenes, once the shell is up
end
