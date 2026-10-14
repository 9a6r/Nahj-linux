-- Snap's logic: it takes the picture of the screen before the scene draws anything, and cuts the picked part out of that picture when it is copied or saved.
-- Nothing here is drawn. The picture is kept in the runtime folder (vitreus-snap/shot.png) and is gone with the session.

local shot_w = 0       -- the picture's width in pixels: with a scaled monitor it is more than the scene's width

local function trim(s) return (s or ""):gsub("%s+$", "") end

local function say_quit()
    run("pleamar", { "--say", "snap", "quit" }, function() end)
end

local function fail(msg)
    run("notify-send", { "-a", "Snap", "Screenshot failed", msg }, function() say_quit() end)
end

-- SNAP_NO_CAPTURE=1 keeps a picture that is already there (a test of the scene without a screen to take it from).
local function capture()
    local script = 'd="${XDG_RUNTIME_DIR:-/tmp}/vitreus-snap"; mkdir -p "$d"; '
        .. 'if [ -z "$SNAP_NO_CAPTURE" ]; then grim "$d/shot.png" || exit 1; fi; '
        .. 'echo "$d/shot.png"; magick identify -format "%w" "$d/shot.png"'
    run("sh", { "-c", script }, function(out, code)
        local path, w = (out or ""):match("^(.-)\n(%d+)")
        if code ~= 0 or not path then fail("The screen could not be captured.") return end
        shot_w = tonumber(w) or 0
        text.shot_path = path .. "?1"
        fact.phase = 1
    end)
end

-- The picked part, in the picture's pixels. `fact.scrw` is the scene's width, which the scene sets when it asks.
local function crop_args()
    local k = (shot_w > 0 and fact.scrw > 0) and shot_w / fact.scrw or 1
    local x, y = math.floor(fact.sx * k + 0.5), math.floor(fact.sy * k + 0.5)
    local w, h = math.max(1, math.floor(fact.sw * k + 0.5)), math.max(1, math.floor(fact.sh * k + 0.5))
    return string.format("%dx%d+%d+%d", w, h, x, y)
end

local function finish(script, message)
    run("sh", { "-c", script }, function(_, code)
        if code ~= 0 then fail("The picture could not be cut out.") return end
        run("notify-send", { "-a", "Snap", message }, function() say_quit() end)
    end, { output = false })
end

local CUT = 'd="${XDG_RUNTIME_DIR:-/tmp}/vitreus-snap"; magick "$d/shot.png" -crop %s +repage '

on("do_copy", function()
    finish(string.format(CUT, crop_args()) .. 'png:- | wl-copy --type image/png', "Screenshot copied")
end)

-- Saved in ~/Pictures/Screenshots, as the Controls drawer's capture does, and copied as well.
on("do_save", function()
    finish('f="$HOME/Pictures/Screenshots/screenshot_$(date +%F_%H-%M-%S).png"; mkdir -p "${f%/*}"; '
        .. string.format(CUT, crop_args()) .. '"$f" && { wl-copy --type image/png < "$f"; true; }',
        "Screenshot saved and copied")
end)

on("do_quit", say_quit)

capture()
