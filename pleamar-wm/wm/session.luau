-- The window manager scene's logic: Caps Lock and Num Lock, as pleamar-wm says them (`keys.caps`, `keys.num`, which the scene turns into
-- `lk_change`), passed on to Vitreus, which shows them in its volume drawer (logic/lockkeys.luau). Under Hyprland the shell hears of them
-- through hypr_vitreus.lua's binds instead.
on("lk_change", function(n)
    if type(n) ~= "number" then return end
    run("pleamar", { "--say", "vitreus", "emit lockkeys_set " .. math.floor(n + 0.5) }, function() end)
end)
