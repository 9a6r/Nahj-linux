-- Add-ons (Settings > Add-ons): scenes people write and keep in ~/.config/pleamar/vitreus-addons/<id>/ (the model is addons/_template/). Each has an
-- addon.toml and a scene; bin/vitreus-addons reads them and leaves `addons.json` in the data folder, and this is that list. The folder is outside the shell's own, so
-- updating Vitreus never touches it. A switch starts the scene under `vitreus-keep` (started again if it stops) or stops it; which are on is kept in addons-state.json,
-- and the ones that are on start with the shell. An add-on is not sandboxed: its scene declares what it runs and reads in its own `permissions`.
return function()
    local MAX = 12
    local list, errors, folder = {}, {}, ""
    local enabled = {}
    local ready = false

    local function save()
        pcall(sys.call, "files.write", "addons-state.json", { enabled = enabled })
    end
    do
        local ok, saved = pcall(sys.ask, "files.read", "addons-state.json", "json")
        if ok and type(saved) == "table" and type(saved.enabled) == "table" then
            for id, v in pairs(saved.enabled) do if v == true then enabled[id] = true end end
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
    end

    local function start(a)
        run("pgrep", { "-f", "pleamar --scene " .. a.scene .. "( |$)" }, function(_, code)
            if code ~= 0 then
                exec_on_desktop('vitreus-keep "' .. a.scene .. '"')
            end
        end)
    end
    local function stop(a)
        -- The keeper first, or it starts the scene again.
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
                out[#out + 1] = a
            end
        end
        list = out
        errors = type(f.errors) == "table" and f.errors or {}
        folder = type(f.folder) == "string" and f.folder or ""
        return true
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
