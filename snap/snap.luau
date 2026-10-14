-- Snap's logic: it takes the picture of the screen before the scene draws anything, keeps the marks drawn on it (and their history, for undo), and when the
-- picture is copied or saved, cuts the picked part out and draws the marks into it with ImageMagick.
-- Nothing here is drawn. The pictures are kept in the runtime folder (vitreus-snap/shot.png, out.png) and are gone with the session.

local shot_w = 0       -- the picture's width in pixels: with a scaled monitor it is more than the scene's width
local dir = nil        -- the runtime folder the picture is in

local function trim(s) return (s or ""):gsub("%s+$", "") end

local function say_quit()
    run("pleamar", { "--say", "snap", "quit" }, function() end)
end

local function fail(msg)
    run("notify-send", { "-a", "Snap", "Screenshot failed", msg }, function() say_quit() end)
end

-- Only the monitor Snap is on: grim on its own takes every monitor in one picture, which the scene then squeezed onto this one. A surface that names no
-- monitor opens on the focused one, so that is the one taken: Hyprland says which (`hyprctl monitors`); SNAP_OUTPUT names it instead (with
-- `pleamar --screen` to open Snap there too); with neither, every monitor is taken, as before.
-- SNAP_NO_CAPTURE=1 keeps a picture that is already there, and SNAP_DIR is another folder for it (a test of the scene without a screen to take it
-- from, which then never touches the pictures of a real Snap).
-- And the look Vitreus has (Settings > Theme), from its iris.json, so Snap is drawn like it (`fact look`: 0 Glass, 1 Retro, 2 UwU, 3 Cyber). The colours
-- come with ../palette.plm, which Vitreus rewrites; the typeface with the font setup the Controls drawer starts Snap with. SNAP_LOOK (8, 9, 10, or
-- anything else for Glass) names one instead, to see them all.
local LOOKS = { ["8"] = 1, ["9"] = 2, ["10"] = 3 }
local function capture()
    local script = 'd="${SNAP_DIR:-${XDG_RUNTIME_DIR:-/tmp}/vitreus-snap}"; mkdir -p "$d"; '
        .. 'o="$SNAP_OUTPUT"; [ -n "$o" ] || o=$(hyprctl -j monitors 2>/dev/null | jq -r \'.[] | select(.focused) | .name\' 2>/dev/null | head -n 1); '
        .. 'if [ -z "$SNAP_NO_CAPTURE" ]; then grim ${o:+-o "$o"} "$d/shot.png" || exit 1; fi; '
        .. 'echo "$d"; magick identify -format "%w\n" "$d/shot.png"; '
        .. [[l="${SNAP_LOOK-}"; [ -n "$l" ] || l=$(sed -n 's/.*"look": *\([0-9]*\).*/\1/p' "${XDG_DATA_HOME:-$HOME/.local/share}/pleamar/vitreus/iris.json" 2> /dev/null | head -n 1); echo "$l"]]
    run("sh", { "-c", script }, function(out, code)
        local d, w, look = (out or ""):match("^(.-)\n(%d+)\n(%d*)")
        if code ~= 0 or not d then fail("The screen could not be captured.") return end
        fact.look = LOOKS[look] or 0
        dir = d
        shot_w = tonumber(w) or 0
        text.shot_path = d .. "/shot.png?1"
        fact.phase = 1
    end)
end

-- ── The marks ─────────────────────────────────────────────────────────────────────────────────────────────────
-- Each one is { k = tool, c = colour, w = width, x0, y0, x1, y1 } in the scene's coordinates; a pen or highlighter stroke has `pts` (x, y, x, y, …)
-- instead, a marker a number `n` at (x0, y0), a text its words `s` at (x0, y0). Tools: 2 pen, 3 arrow, 4 rectangle, 5 ellipse, 6 text, 7 marker,
-- 8 blur, 9 highlighter (10, the eraser, makes none). The widths, by the size picked (0, 1, 2), are what the scene uses for what is being dragged out.
local PEN = 2
local ARROW, RECT, ELLIPSE, TEXT, MARKER, BLUR, HIGHLIGHT = 3, 4, 5, 6, 7, 8, 9
local WIDTH = { [PEN] = { 3, 5, 9 }, [ARROW] = { 3, 5, 9 }, [RECT] = { 3, 5, 9 }, [ELLIPSE] = { 3, 5, 9 },
                [HIGHLIGHT] = { 14, 22, 32 }, [TEXT] = { 18, 26, 38 }, [MARKER] = { 12, 16, 22 }, [BLUR] = { 0, 0, 0 } }
local MAX_MARKS, MAX_SEGS = 128, 1024

local marks = {}
local undo, redo = {}, {}
local stroke = nil      -- the pen or highlighter stroke being drawn
local text_at = nil     -- where the text being written goes: { x, y, c, w }

local function width_for(k) return WIDTH[k][math.floor(tonumber(fact.sz) or 1) + 1] or WIDTH[k][2] end

local function copy_mark(m)
    local c = {}
    for key, v in pairs(m) do c[key] = v end
    if m.pts then c.pts = table.move(m.pts, 1, #m.pts, 1, {}) end
    return c
end
local function copy_all(list)
    local out = {}
    for i, m in ipairs(list) do out[i] = copy_mark(m) end
    return out
end

-- What a mark covers, for Select and for its outline.
local function bounds(m)
    if m.pts then
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for i = 1, #m.pts, 2 do
            x0, x1 = math.min(x0, m.pts[i]), math.max(x1, m.pts[i])
            y0, y1 = math.min(y0, m.pts[i + 1]), math.max(y1, m.pts[i + 1])
        end
        local h = m.w / 2
        return x0 - h, y0 - h, x1 + h, y1 + h
    elseif m.k == MARKER then
        return m.x0 - m.w, m.y0 - m.w, m.x0 + m.w, m.y0 + m.w
    elseif m.k == TEXT then
        -- Space Grotesk Bold is a little over half an em wide on average
        return m.x0, m.y0 - m.w * 0.6, m.x0 + #m.s * m.w * 0.58, m.y0 + m.w * 0.6
    end
    local h = m.w / 2
    return math.min(m.x0, m.x1) - h, math.min(m.y0, m.y1) - h, math.max(m.x0, m.x1) + h, math.max(m.y0, m.y1) + h
end

-- The list, as the scene's two models: the marks, and the pen's and highlighter's strokes cut into segments.
local function show()
    local rows, segs = {}, {}
    for i, m in ipairs(marks) do
        local bx0, by0, bx1, by1 = bounds(m)
        rows[i] = { k = m.k, x0 = m.x0 or 0, y0 = m.y0 or 0, x1 = m.x1 or 0, y1 = m.y1 or 0, c = m.c, w = m.w, n = m.n or 0, s = m.s or "",
                    bx0 = bx0, by0 = by0, bx1 = bx1, by1 = by1 }
        if m.pts then
            local p = m.pts
            if #p == 2 then        -- a click: a dot
                if #segs < MAX_SEGS then segs[#segs + 1] = { x0 = p[1], y0 = p[2], x1 = p[1] + 0.01, y1 = p[2], c = m.c, w = m.w, hl = m.k == HIGHLIGHT and 1 or 0, m = i - 1 } end
            end
            for j = 3, #p, 2 do
                if #segs >= MAX_SEGS then break end
                segs[#segs + 1] = { x0 = p[j - 2], y0 = p[j - 1], x1 = p[j], y1 = p[j + 1], c = m.c, w = m.w, hl = m.k == HIGHLIGHT and 1 or 0, m = i - 1 }
            end
        end
    end
    model.marks = rows
    model.segs = segs
    fact.can_undo = #undo > 0
    fact.can_redo = #redo > 0
end

-- Every change keeps what was there before, for undo, and forgets what undo had taken back.
local function change(fn)
    undo[#undo + 1] = copy_all(marks)
    if #undo > 100 then table.remove(undo, 1) end
    redo = {}
    fn()
    show()
end

local function add(m)
    if #marks >= MAX_MARKS then return end
    change(function() marks[#marks + 1] = m end)
end

on("do_undo", function()
    if #undo == 0 then return end
    redo[#redo + 1] = copy_all(marks)
    marks = table.remove(undo)
    fact.selm = -1
    show()
end)
on("do_redo", function()
    if #redo == 0 then return end
    undo[#undo + 1] = copy_all(marks)
    marks = table.remove(redo)
    fact.selm = -1
    show()
end)

-- The pen and the highlighter: a point is kept only once the pointer has moved 3 px from the last one, so a slow hand does not fill the list.
on("pen_down", function()
    if #marks >= MAX_MARKS then return end
    local k = fact.tool == HIGHLIGHT and HIGHLIGHT or PEN
    stroke = { k = k, c = fact.col, w = width_for(k), pts = { fact.px, fact.py } }
    undo[#undo + 1] = copy_all(marks)
    redo = {}
    marks[#marks + 1] = stroke
    show()
end)
on("pen_pt", function()
    if not stroke then return end
    local p = stroke.pts
    local dx, dy = fact.px - p[#p - 1], fact.py - p[#p]
    if dx * dx + dy * dy < 9 then return end
    p[#p + 1] = fact.px
    p[#p + 1] = fact.py
    show()
end)
on("pen_up", function() stroke = nil end)

-- An arrow, a rectangle, an ellipse or a blurred area, dragged out in the scene. Too small to see is a slip, not a mark.
on("shape_add", function()
    local k = fact.tool
    local x0, y0, x1, y1 = fact.ax, fact.ay, fact.qx, fact.qy
    if math.abs(x1 - x0) >= 4 or math.abs(y1 - y0) >= 4 then
        if k == BLUR then x0, x1, y0, y1 = math.min(x0, x1), math.max(x0, x1), math.min(y0, y1), math.max(y0, y1) end
        add({ k = k, c = fact.col, w = width_for(k), x0 = x0, y0 = y0, x1 = x1, y1 = y1 })
    end
    fact.dragging = 0
end)

-- Markers count up from 1; one that is undone frees its number.
on("marker_add", function()
    local n = 0
    for _, m in ipairs(marks) do if m.k == MARKER then n = math.max(n, m.n) end end
    add({ k = MARKER, c = fact.col, w = width_for(MARKER), x0 = fact.px, y0 = fact.py, n = n + 1 })
end)

-- Text: a click opens a field there (and keeps what was being written somewhere else); Enter keeps it, Esc drops it (the scene sets `typing` to 0).
local function commit_text()
    if text_at and fact.typing == 1 then
        local s = trim(text.tq or "")
        if s ~= "" then add({ k = TEXT, c = text_at.c, w = text_at.w, x0 = text_at.x, y0 = text_at.y, s = s }) end
    end
    text_at = nil
    text.tq = ""
    fact.typing = 0
end
on("txt_at", function()
    commit_text()
    text_at = { x = fact.px, y = fact.py, c = fact.col, w = width_for(TEXT) }
    fact.tx, fact.ty_ = fact.px, fact.py
    fact.typing = 1
end)
on("txt_commit", commit_text)

-- Select and the eraser: what is under the pointer. A stroke is under it only near one of its segments, not anywhere in its box.
local function near_segment(px, py, ax, ay, bx, by, r)
    local dx, dy = bx - ax, by - ay
    local t = 0
    local l = dx * dx + dy * dy
    if l > 0 then t = math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l)) end
    local ex, ey = ax + t * dx - px, ay + t * dy - py
    return ex * ex + ey * ey <= r * r
end
-- The mark under (px, py), the one on top first, `pad` px of grace round it; nil if none.
local function mark_at(px, py, pad)
    for i = #marks, 1, -1 do
        local m = marks[i]
        local x0, y0, x1, y1 = bounds(m)
        if px >= x0 - pad and px <= x1 + pad and py >= y0 - pad and py <= y1 + pad then
            local hit = true
            if m.pts and #m.pts >= 4 then
                hit = false
                for j = 3, #m.pts, 2 do
                    if near_segment(px, py, m.pts[j - 2], m.pts[j - 1], m.pts[j], m.pts[j + 1], m.w / 2 + pad) then hit = true break end
                end
            end
            if hit then return i end
        end
    end
    return nil
end
on("sel_at", function()
    local i = mark_at(fact.px, fact.py, 6)
    fact.selm = i and i - 1 or -1
end)

-- The eraser: what was there when it went down is kept for undo, but only if it took something out.
local before_erase, erased = nil, false
local function erase_here()
    if not before_erase then return end
    local i = mark_at(fact.px, fact.py, 10)
    while i do
        table.remove(marks, i)
        erased = true
        i = mark_at(fact.px, fact.py, 10)
    end
    if erased then fact.selm = -1; show() end
end
on("erase_down", function()
    before_erase, erased = copy_all(marks), false
    erase_here()
end)
on("erase_pt", erase_here)
on("erase_up", function()
    if before_erase and erased then
        undo[#undo + 1] = before_erase
        if #undo > 100 then table.remove(undo, 1) end
        redo = {}
        show()
    end
    before_erase, erased = nil, false
end)
on("sel_move", function()
    local i = (tonumber(fact.selm) or -1) + 1
    local dx, dy = fact.mvx, fact.mvy
    if marks[i] and (dx ~= 0 or dy ~= 0) then
        change(function()
            local m = marks[i]
            if m.pts then
                for j = 1, #m.pts, 2 do m.pts[j], m.pts[j + 1] = m.pts[j] + dx, m.pts[j + 1] + dy end
            else
                m.x0, m.y0 = m.x0 + dx, m.y0 + dy
                if m.x1 then m.x1, m.y1 = m.x1 + dx, m.y1 + dy end
            end
        end)
    end
    fact.mvx, fact.mvy = 0, 0
end)
on("mk_del", function()
    local i = (tonumber(fact.selm) or -1) + 1
    if not marks[i] then return end
    change(function() table.remove(marks, i) end)
    fact.selm = -1
end)

-- ── Copy and Save ──────────────────────────────────────────────────────────────────────────────────────────────
-- The picked part is cut out of the picture and the marks are drawn into it, in the order the scene draws them: blur, highlighter, shapes, pen,
-- markers, text. Everything is scaled from the scene's pixels to the picture's (`k`: more than 1 on a scaled monitor). Mint is the shell's, read
-- from the palette Iris writes, so the picture has the colour that was on screen.
local COLOURS = { "#ff6b6b", "#ffc857", nil, "#5cc8ff", "#ffffff" }
local HL_ALPHA = "6B"   -- the highlighter's 42 %

local function export(mint, then_fn)
    commit_text()
    local k = (shot_w > 0 and fact.scrw > 0) and shot_w / fact.scrw or 1
    local ox, oy = fact.sx, fact.sy
    local cw, ch = math.max(1, math.floor(fact.sw * k + 0.5)), math.max(1, math.floor(fact.sh * k + 0.5))
    local function X(x) return (x - ox) * k end
    local function Y(y) return (y - oy) * k end
    local function colour(c) return (c == 2 and mint) or COLOURS[c + 1] or "#ffffff" end
    local function f(v) return string.format("%.1f", v) end

    local a = { dir .. "/shot.png", "-crop", string.format("%dx%d+%d+%d", cw, ch, math.floor(ox * k + 0.5), math.floor(oy * k + 0.5)), "+repage",
                "-gravity", "NorthWest" }
    local function push(...) for _, v in ipairs({ ... }) do a[#a + 1] = v end end
    local function polyline(m, col)
        local pts = {}
        for j = 1, #m.pts, 2 do pts[#pts + 1] = f(X(m.pts[j])) .. "," .. f(Y(m.pts[j + 1])) end
        if #pts == 1 then pts[2] = pts[1] end
        push("-fill", "none", "-stroke", col, "-strokewidth", f(m.w * k),
             "-draw", "stroke-linecap round stroke-linejoin round polyline " .. table.concat(pts, " "))
    end

    for _, m in ipairs(marks) do
        if m.k == BLUR then
            local w, h = math.floor((m.x1 - m.x0) * k + 0.5), math.floor((m.y1 - m.y0) * k + 0.5)
            if w > 0 and h > 0 then
                push("-region", string.format("%dx%d%+d%+d", w, h, math.floor(X(m.x0) + 0.5), math.floor(Y(m.y0) + 0.5)), "-blur", "0x" .. f(12 * k), "+region")
            end
        end
    end
    for _, m in ipairs(marks) do if m.k == HIGHLIGHT then polyline(m, colour(m.c) .. HL_ALPHA) end end
    for _, m in ipairs(marks) do
        local col, w = colour(m.c), m.w * k
        if m.k == RECT then
            push("-fill", "none", "-stroke", col, "-strokewidth", f(w),
                 "-draw", string.format("roundrectangle %s,%s %s,%s 3,3", f(X(math.min(m.x0, m.x1))), f(Y(math.min(m.y0, m.y1))), f(X(math.max(m.x0, m.x1))), f(Y(math.max(m.y0, m.y1)))))
        elseif m.k == ELLIPSE then
            push("-fill", "none", "-stroke", col, "-strokewidth", f(w),
                 "-draw", string.format("ellipse %s,%s %s,%s 0,360", f(X((m.x0 + m.x1) / 2)), f(Y((m.y0 + m.y1) / 2)), f(math.abs(m.x1 - m.x0) / 2 * k), f(math.abs(m.y1 - m.y0) / 2 * k)))
        elseif m.k == ARROW then
            -- as the scene draws it: the shaft stops inside the head, which is a filled triangle `al` long
            local aa = math.atan2(m.y1 - m.y0, m.x1 - m.x0)
            local al = 8 + 3.2 * m.w
            local c, s = math.cos(aa), math.sin(aa)
            local ex, ey = m.x1 - c * al * 0.7, m.y1 - s * al * 0.7
            local lx, ly = m.x1 - c * al + s * al * 0.55, m.y1 - s * al - c * al * 0.55
            local rx, ry = m.x1 - c * al - s * al * 0.55, m.y1 - s * al + c * al * 0.55
            push("-fill", "none", "-stroke", col, "-strokewidth", f(w),
                 "-draw", string.format("stroke-linecap round line %s,%s %s,%s", f(X(m.x0)), f(Y(m.y0)), f(X(ex)), f(Y(ey))),
                 "-fill", col, "-stroke", "none",
                 "-draw", string.format("polygon %s,%s %s,%s %s,%s", f(X(m.x1)), f(Y(m.y1)), f(X(lx)), f(Y(ly)), f(X(rx)), f(Y(ry))))
        end
    end
    for _, m in ipairs(marks) do if m.k == PEN then polyline(m, colour(m.c)) end end
    for _, m in ipairs(marks) do
        if m.k == MARKER then
            push("-fill", colour(m.c), "-stroke", "none",
                 "-draw", string.format("circle %s,%s %s,%s", f(X(m.x0)), f(Y(m.y0)), f(X(m.x0) + m.w * k), f(Y(m.y0))))
        end
    end
    -- The words: centred on a marker, or starting at a text's point, with its middle on it (the scene's `anchor: left center`). -annotate's offset is from
    -- where the gravity puts the text, so it is taken from the middle of the picture (Center) or of its left edge (West). `%` and a leading `@` are
    -- ImageMagick's own escapes, and are doubled or escaped.
    local function esc(s) return (s:gsub("%%", "%%%%"):gsub("^@", "\\@")) end
    push("-family", "Space Grotesk", "-stroke", "none")
    for _, m in ipairs(marks) do
        if m.k == MARKER then
            push("-gravity", "Center", "-weight", "800", "-fill", "#10161a", "-pointsize", f(m.w / 16 * 18 * k),
                 "-annotate", string.format("%+d%+d", math.floor(X(m.x0) - cw / 2 + 0.5), math.floor(Y(m.y0) - ch / 2 + 0.5)), tostring(m.n))
        elseif m.k == TEXT then
            push("-gravity", "West", "-weight", "700", "-fill", colour(m.c), "-pointsize", f(m.w * k),
                 "-annotate", string.format("%+d%+d", math.floor(X(m.x0) + 0.5), math.floor(Y(m.y0) - ch / 2 + 0.5)), esc(m.s))
        end
    end
    push(dir .. "/out.png")
    run("magick", a, function(_, code)
        if code ~= 0 then fail("The picture could not be cut out.") return end
        then_fn()
    end, { output = false })
end

-- Mint as the shell has it now, or the default if the palette cannot be read.
local function with_mint(fn)
    run("sh", { "-c", [[sed -n 's/^ *let mint *= *\(#[0-9a-fA-F]\{6\}\).*/\1/p' "$HOME/.config/pleamar/shells/vitreus/palette.plm" | head -n 1]] }, function(out)
        local m = trim(out)
        fn(m:match("^#%x%x%x%x%x%x$") and m or "#9ed6bd")
    end)
end

local function finish(script, message)
    if not dir then return end
    with_mint(function(mint)
        export(mint, function()
            run("sh", { "-c", 'd="' .. dir .. '"; ' .. script }, function(_, code)
                if code == 3 then say_quit() return end      -- Vitreus has it, and says so itself (do_save)
                if code ~= 0 then fail("The picture could not be kept.") return end
                run("notify-send", { "-a", "Snap", message }, function() say_quit() end)
            end, { output = false })
        end)
    end)
end

on("do_copy", function()
    finish('wl-copy --type image/png < "$d/out.png"', "Screenshot copied")
end)

-- Saved in ~/Pictures/Screenshots, as the Controls drawer's capture does, and copied as well. Vitreus is told (`shot_done`), and shows it as the card its
-- other captures get: then there is no notification as well (the scene quits either way). Without Vitreus, the notification.
on("do_save", function()
    finish('f="$HOME/Pictures/Screenshots/screenshot_$(date +%F_%H-%M-%S).png"; mkdir -p "${f%/*}"; '
        .. 'cp "$d/out.png" "$f" && { wl-copy --type image/png < "$f"; true; } && '
        .. '{ pleamar --say vitreus "text shot_path $f" "emit shot_done" > /dev/null 2>&1 && exit 3; true; }',
        "Screenshot saved and copied")
end)

on("do_quit", say_quit)

show()
capture()
