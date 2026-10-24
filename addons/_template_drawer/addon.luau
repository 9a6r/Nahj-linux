-- The logic of the drawer template: it keeps the number of presses in this add-on's own data folder (~/.local/share/pleamar/<the scene's name>/, which the `files` services
-- read and write by file name), so the dots are still lit after a restart. Delete it if your add-on needs no logic.
--
-- What else a logic can do:
--   local ok, folder = pcall(sys.ask, "files.folder")                 -- the data folder's path, for a program that needs it
--   run("wl-paste", { "--no-newline" }, function(out, code) ... end)   -- a program (it has to be in `permissions { run: ... }`); `out` is what it printed
--   on("some_event", function(arg) ... end)                            -- an `event some_event ->` of the scene, emitted from a rule with `emit some_event`
--   every(60000, function() ... end), after(500, function() ... end)  -- timers, in milliseconds
local ok, saved = pcall(sys.ask, "files.read", "state.json", "json")
if ok and type(saved) == "table" and type(saved.clicks) == "number" then fact.clicks = saved.clicks end
on("fact:clicks", function(v)
    pcall(sys.call, "files.write", "state.json", { clicks = tonumber(v) or 0 })
end)
