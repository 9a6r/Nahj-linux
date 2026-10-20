-- Files: the logic of the small file manager. It lists a folder with `find`, hands the scene only the rows that are on screen (a folder of thousands costs what a folder of ten does), and does the
-- basics with ordinary commands: `xdg-open` to open, `mkdir` for a new folder, `mv` to rename, cut and paste, `cp -r` to copy, `gio trash` to put away.
-- It starts in the folder named by $FILES_START when there is one, else in the home folder.
-- What is kept, in this scene's own folder (~/.local/share/pleamar/files): files.json, the view, whether hidden files show and the sort order.

local GRID_ROWS = 14        -- rows of tiles sent to the scene at once (it declares 14)
local LINES_PER_ROW = 12    -- in the lines view a row of the scene is a block of this many lines, one under the other: a window full of them is a few blocks, and the scene stays small
local LINES_ROWS = 5        -- ... and this many blocks are sent at once
local MAX_COLS = 12
local GRID_H, LINES_H = 132, 38

local s = {
    home = "", data = "", path = "", items = {}, back = {}, fwd = {}, picked = {}, anchor = nil,
    cols = 6, first = 0, scroll = 0, view = "grid", hidden = false, sort = "name",
    qtext = "", mode = nil, results = nil,      -- the search: what is typed; `filter` (this folder, as you type) or `deep` (the folders under it too, `results`)
    clip = nil, places = {}, pins = {}, crumbw = 300, crumbs = {}, ask = nil, tick = 0, last_i = nil, last_tick = -100, menu = nil, free = "",
}

-- ── small things ──
local function trim(t) return ((t or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function basename(p) return p:match("([^/]+)/*$") or "/" end
local function dirname(p)
    local d = p:gsub("/+$", ""):match("^(.*)/[^/]*$")
    if d == nil then return "/" end
    return d == "" and "/" or d
end
local function join(dir, name) return (dir == "/" and "" or dir) .. "/" .. name end
local function clean(p)
    p = p:gsub("/+", "/")
    if #p > 1 then p = p:gsub("/$", "") end
    return p
end
local function size_text(n)
    n = tonumber(n) or 0
    if n < 1000 then return string.format("%d B", n) end
    local units = { "KB", "MB", "GB", "TB" }
    local v = n
    for i = 1, #units do
        v = v / 1000
        if v < 1000 or i == #units then
            return string.format(v < 10 and "%.1f %s" or "%.0f %s", v, units[i])
        end
    end
end
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local function date_text(t)
    t = math.floor(tonumber(t) or 0)
    local ok, v = pcall(os.date, "%d %b %Y, %H:%M", t)
    if ok and type(v) == "string" and v ~= "" then return v end
    -- (without os.date: the day, in UTC)
    local days = math.floor(t / 86400)
    local z = days + 719468
    local era = math.floor(z / 146097)
    local doe = z - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp = math.floor((5 * doy + 2) / 153)
    local d = doy - math.floor((153 * mp + 2) / 5) + 1
    local m = mp < 10 and mp + 3 or mp - 9
    if m <= 2 then y = y + 1 end
    return string.format("%d %s %d", d, MONTHS[m], y)
end

local EXT = {}
for kind, list in pairs({
    image = "png jpg jpeg gif webp bmp svg tif tiff avif heic ico",
    pdf = "pdf",
    audio = "mp3 flac ogg opus wav m4a aac wma aiff",
    video = "mp4 mkv webm avi mov wmv flv m4v mpg mpeg",
    code = "lua luau py js ts tsx jsx rs c h cpp hpp cc go java kt sh bash zsh fish json toml yaml yml xml html css scss plm md rb php cs swift sql conf cfg ini",
    archive = "zip tar gz xz zst bz2 7z rar tgz iso",
}) do
    for e in list:gmatch("%S+") do EXT[e] = kind end
end
local KIND_NUM = { image = 1, pdf = 2, audio = 3, video = 4, code = 5, archive = 6 }
local function ik_of(name, dir)
    if dir then return 0 end
    local e = name:match("%.([^.]+)$")
    return e and KIND_NUM[EXT[e:lower()] or ""] or 7
end

local function cols() return s.view == "grid" and s.cols or LINES_PER_ROW end       -- things to a row of the scene
local function tile_h() return s.view == "grid" and GRID_H or LINES_H end
local function row_h() return s.view == "grid" and GRID_H or LINES_H * LINES_PER_ROW end
local function row_window() return s.view == "grid" and GRID_ROWS or LINES_ROWS end
local function down_by() return s.view == "grid" and s.cols or 1 end        -- what the Up and Down keys move the choice by
local function item_top(idx)
    if s.view == "grid" then return math.floor((idx - 1) / s.cols) * GRID_H end
    return (idx - 1) * LINES_H
end

local function save()
    pcall(sys.call, "files.write", "files.json", { view = s.view, hidden = s.hidden, sort = s.sort, pins = s.pins })
end
do
    local ok, saved = pcall(sys.ask, "files.read", "files.json", "json")
    if ok and type(saved) == "table" then
        if saved.view == "grid" or saved.view == "lines" then s.view = saved.view end
        if type(saved.hidden) == "boolean" then s.hidden = saved.hidden end
        if saved.sort == "name" or saved.sort == "date" or saved.sort == "size" then s.sort = saved.sort end
        if type(saved.pins) == "table" then
            for _, p in ipairs(saved.pins) do
                if type(p) == "string" and p:sub(1, 1) == "/" then s.pins[#s.pins + 1] = p end
            end
        end
    end
    fact.view = s.view
    fact.hidden = s.hidden
    fact.sort = s.sort
end
local SORT_NAMES = { name = "Name", date = "Date", size = "Size" }
text.sortname = "Sort: " .. SORT_NAMES[s.sort]

-- ── listing a folder ──
local function list_dir(path, cb)
    run("find", { "-L", path, "-maxdepth", "1", "-mindepth", "1", "-printf", "%y\t%s\t%T@\t%f\n" }, function(out, code)
        out = out or ""
        if code ~= 0 and out == "" then cb(nil) return end
        local items = {}
        for line in out:gmatch("[^\n]+") do
            local ty, sz, mt, name = line:match("^(%a)\t(%d+)\t([%d%.]+)\t(.*)$")
            if name and name ~= "" then
                local dir = ty == "d"
                items[#items + 1] = {
                    name = name, path = join(path, name), dir = dir, size = tonumber(sz) or 0, mtime = tonumber(mt) or 0,
                    hidden = name:sub(1, 1) == ".", ik = ik_of(name, dir),
                }
            end
        end
        cb(items)
    end)
end

local function sorted(items)
    local out = {}
    local q = s.mode == "filter" and s.qtext ~= "" and s.qtext:lower() or nil
    for _, e in ipairs(items) do
        if (s.hidden or not e.hidden) and (not q or e.name:lower():find(q, 1, true)) then out[#out + 1] = e end
    end
    table.sort(out, function(a, b)
        if a.dir ~= b.dir then return a.dir end
        if s.sort == "date" and a.mtime ~= b.mtime then return a.mtime > b.mtime end
        if s.sort == "size" and not a.dir and a.size ~= b.size then return a.size > b.size end       -- (a folder's own size is the room its list takes: they go by name)
        local x, y = a.name:lower(), b.name:lower()
        if x ~= y then return x < y end
        return a.name < b.name
    end)
    return out
end

-- what is shown: this folder (narrowed by what is typed in the search), or what a search of the folders under it found
local function visible()
    return sorted((s.mode == "deep" and s.results) or s.all or {})
end

-- ── what the scene shows ──
local function picked_list()
    local list = {}
    for _, e in ipairs(s.items) do
        if s.picked[e.path] then list[#list + 1] = e end
    end
    return list
end

local function set_status()
    local n = #s.items
    local list = picked_list()
    if #list == 0 then
        if s.mode == "deep" then
            text.status = string.format("%d %s for \"%s\"%s", n, n == 1 and "result" or "results", s.qtext, n >= 500 and " (the first 500)" or "")
        elseif s.mode == "filter" and s.qtext ~= "" then
            text.status = string.format("%d of %d", n, #(s.all or {}))
        else
            text.status = n == 1 and "1 item" or string.format("%d items", n)
        end
    elseif #list == 1 then
        local e = list[1]
        text.status = (e.dir and e.name or (e.name .. " · " .. size_text(e.size))) .. (s.mode == "deep" and (" · " .. dirname(e.path)) or "")
    else
        local total = 0
        for _, e in ipairs(list) do if not e.dir then total = total + e.size end end
        text.status = string.format("%d selected · %s", #list, size_text(total))
    end
end

-- ── the pictures' own pictures ──
-- A small copy of each picture that is on screen is made with ImageMagick, once, and kept in this scene's folder (`th-<hash of its path, size and date>.png`), so that a folder of photos
-- shows them and not a row of icons. Several are made at a time (one thread each, so they do not fight over the processor); one that cannot be made (a broken file) is left with its icon.
-- A video's picture is a frame from its first seconds, taken with ffmpeg.
local THUMB_EXT = {}
for e in ("png jpg jpeg gif webp bmp svg tif tiff avif ico"):gmatch("%S+") do THUMB_EXT[e] = true end
local THUMB_MAX_BYTES = 300 * 1000 * 1000
local THUMB_JOBS = 6
s.thumbs, s.pending, s.queue, s.making = {}, {}, {}, 0
local tdir = nil
do
    local ok, folder = pcall(sys.ask, "files.folder")
    if ok and type(folder) == "string" and folder ~= "" then tdir = folder end
end
-- The scene's folder is only there once something has been saved in it, and magick does not make the folder it writes to.
if tdir then run("mkdir", { "-p", "--", tdir }, function() end) end
local function thumb_name(e)
    local key = e.path .. "|" .. e.size .. "|" .. e.mtime
    local h1, h2 = 7, 13
    for i = 1, #key do
        local b = key:byte(i)
        h1 = (h1 * 31 + b) % 2147483647
        h2 = (h2 * 131 + b) % 1000000007
    end
    return string.format("th-%d-%d.png", h1, h2)
end
local function can_thumb(e)
    if e.dir or (e.ik ~= 1 and e.ik ~= 4) then return false end
    if e.ik == 4 then return true end                  -- a video: any size, ffmpeg only reads the start
    if e.size > THUMB_MAX_BYTES then return false end
    local ext = e.name:match("%.([^.]+)$")
    return ext ~= nil and THUMB_EXT[ext:lower()] == true
end
local show_rows
local function flush_later()
    if s.flush then return end
    s.flush = true
    after(150, function()
        s.flush = false
        show_rows()
    end)
end
local function pump()
    while s.making < THUMB_JOBS and #s.queue > 0 do
        local e = table.remove(s.queue, 1)
        local name = thumb_name(e)
        local out = tdir .. "/" .. name
        if dirname(e.path) ~= s.path then
            s.pending[e.path] = nil            -- the folder has changed since: not wanted any more
        else
            s.making = s.making + 1
            local tmp = out .. ".tmp.png"
            local function done(ok)
                s.making = s.making - 1
                s.pending[e.path] = nil
                s.thumbs[e.path .. "|" .. e.size .. "|" .. e.mtime] = ok and out or false
                flush_later()
                pump()
            end
            local function finish(code)
                if code == 0 then
                    run("mv", { "-f", "--", tmp, out }, function(_, c2) done(c2 == 0) end)
                else
                    done(false)
                end
            end
            if e.ik == 4 then
                -- a frame a second in (a shorter video gives none there, so the first frame is asked for then)
                local function frame(at, retry)
                    run("ffmpeg", { "-v", "error", "-y", "-ss", at, "-i", e.path, "-frames:v", "1", "-vf", "scale=288:216:force_original_aspect_ratio=increase,crop=288:216", "-compression_level", "1", tmp }, function(_, code)
                        if code ~= 0 and retry then frame("0", false) else finish(code) end
                    end)
                end
                frame("1", true)
            else
                run("magick", { "-limit", "thread", "1", "-define", "jpeg:size=480x480", e.path .. "[0]", "-auto-orient", "-thumbnail", "288x216^", "-gravity", "center", "-extent", "288x216", "-strip", "-define", "png:compression-level=1", tmp }, function(_, code) finish(code) end)
            end
        end
    end
end
local function tkey(e) return e.path .. "|" .. e.size .. "|" .. e.mtime end
-- what is on screen and has no picture yet: from the cache, or asked for
local function prime_thumbs()
    if not tdir then return end
    local c = cols()
    local from = s.first * c + 1
    local upto = math.min(#s.items, (s.first + row_window()) * c)
    local queued = false
    for i = from, upto do
        local e = s.items[i]
        if e and can_thumb(e) then
            local k = tkey(e)
            if s.thumbs[k] == nil and not s.pending[e.path] then
                local name = thumb_name(e)
                local ok, there = pcall(sys.ask, "files.exists", name)
                if ok and there then
                    s.thumbs[k] = tdir .. "/" .. name
                else
                    s.pending[e.path] = true
                    s.queue[#s.queue + 1] = e
                    queued = true
                end
            end
        end
    end
    if queued then pump() end
end

local carry_all = nil      -- the whole choice as one text, made once for each showing of the rows (a folder's worth of paths, for every tile in it, would be a lot of text)
-- ── the picture in the hand ──
-- While a file is dragged out, a small card goes under the pointer (the zone's `carry_icon:` is this file): a badge for the kind of thing, or its own picture, with the name and a line
-- under it ("3.0 KB", "Folder", "+2 more"). It is made with ImageMagick when a tile is pressed, so that it is there by the time the pointer has moved enough to start the drag; until it is,
-- the drag has none. Each one has a number in its file name, so that one still being made cannot be drawn over the one that was asked for next.
local ICON_W, ICON_H = 232, 64
local ICON_COLOR = { [0] = "#e0a43a", "#a86fdf", "#e0584d", "#4aa3df", "#4fb286", "#8a93a0", "#c9a14a", [7] = "#7f8c99" }
local ICON_LABEL = { [0] = "DIR", "IMG", "PDF", "SND", "VID", "TXT", "ZIP", [7] = "FILE" }
local icon_seq, icon_font = 0, nil
run("fc-match", { "-f", "%{file}", "Space Grotesk:bold" }, function(out, code)
    if code == 0 and type(out) == "string" and out:sub(1, 1) == "/" then icon_font = trim(out) end
end)
local function mtext(t, max)
    -- text for ImageMagick's -annotate: its `%` and `\` mean things, and a leading `@` reads a file
    t = t:gsub("[%c]", " "):gsub("^@", "")
    if #t > max then t = t:sub(1, max - 1) .. "…" end
    return (t:gsub("\\", "\\\\"):gsub("%%", "%%%%"))
end
local function prep_drag_icon()
    text.dragicon = ""
    if not tdir then return end
    local list = picked_list()
    local first = list[1]
    if not first then return end
    icon_seq = icon_seq + 1
    local mine = icon_seq
    local out = string.format("%s/dragicon-%d.png", tdir, mine % 6)
    local sub
    if #list > 1 then sub = string.format("+%d more", #list - 1)
    elseif first.dir then sub = "Folder"
    else sub = size_text(first.size) end
    local args = { "-size", ICON_W .. "x" .. ICON_H, "xc:none", "-fill", "#1b2127ee", "-stroke", "#ffffff70", "-strokewidth", "1", "-draw", string.format("roundrectangle 1,1 %d,%d 14,14", ICON_W - 2, ICON_H - 2) }
    local thumb = (#list == 1 and not first.dir) and s.thumbs[tkey(first)] or nil
    local color = ICON_COLOR[first.ik] or ICON_COLOR[7]
    if thumb then
        -- its own picture, in the same rounded square as the badge
        for _, a in ipairs({ "(", thumb, "-auto-orient", "-resize", "46x46^", "-gravity", "center", "-extent", "46x46", "(", "-size", "46x46", "xc:none", "-fill", "white", "-draw", "roundrectangle 0,0 45,45 9,9", ")", "-alpha", "set", "-compose", "DstIn", "-composite", ")", "-gravity", "northwest", "-geometry", "+9+9", "-compose", "over", "-composite" }) do args[#args + 1] = a end
    else
        for _, a in ipairs({ "-stroke", "none", "-fill", color, "-draw", "roundrectangle 9,9 55,55 10,10" }) do args[#args + 1] = a end
        local label = #list > 1 and tostring(#list) or (ICON_LABEL[first.ik] or "FILE")
        if not first.dir and first.ik == 7 then label = (first.name:match("%.([^.]+)$") or "FILE"):upper():sub(1, 4) end
        if icon_font then args[#args + 1] = "-font"; args[#args + 1] = icon_font end
        for _, a in ipairs({ "-stroke", "none", "-fill", "white", "-pointsize", "15", "-gravity", "northwest", "-annotate", string.format("+%d+24", math.floor(32 - #label * 4.4)), mtext(label, 5) }) do args[#args + 1] = a end
    end
    if icon_font then args[#args + 1] = "-font"; args[#args + 1] = icon_font end
    for _, a in ipairs({ "-stroke", "none", "-gravity", "northwest", "-fill", "white", "-pointsize", "16", "-annotate", "+66+12", mtext(first.name, 18), "-fill", "#b8c2cc", "-pointsize", "13", "-annotate", "+66+36", mtext(sub, 20), "-define", "png:compression-level=1", out }) do args[#args + 1] = a end
    run("magick", args, function(_, code)
        if code == 0 and mine == icon_seq then text.dragicon = out end
    end)
end

local function carry_of(e)
    -- what a drag out of this tile takes: the whole choice when this tile is in it, else just itself
    if s.picked[e.path] then
        if carry_all == nil then
            local paths = {}
            for _, it in ipairs(s.items) do if s.picked[it.path] then paths[#paths + 1] = it.path end end
            carry_all = #paths > 1 and table.concat(paths, "\n") or false
        end
        if carry_all then return carry_all end
    end
    return e.path
end

local function cell(i, e)
    local th = s.thumbs[tkey(e)]
    return {
        carry = carry_of(e),
        at = i - 1, name = e.name, ik = e.ik, thumb = th or "", ["has.thumb"] = th ~= nil and th ~= false, picked = s.picked[e.path] == true, hidden = e.hidden,
        cut = s.clip ~= nil and s.clip.cut and s.clip.set[e.path] == true,
        size = e.dir and "" or size_text(e.size), date = date_text(e.mtime),
    }
end

function show_rows()
    carry_all = nil
    prime_thumbs()
    local c = cols()
    local n = #s.items
    local total = math.ceil(n / c)
    fact.total = total
    fact.itemsn = n
    local rw = row_window()
    local first = math.max(0, math.min(s.first, math.max(total - rw, 0)))
    local rows = {}
    for r = 1, rw do
        local row = first + r - 1
        if row >= total then break end
        local cells = {}
        for k = 1, c do
            local i = row * c + k
            if i > n then break end
            cells[k] = cell(i, s.items[i])
        end
        rows[r] = { cells = cells }
    end
    fact.first = first
    model.rows = rows
    set_status()
end

local function show_crumbs()
    -- the way down to here: "Home" first when it is under the home folder, else the root; at most five, the last ones
    local parts, acc = {}, ""
    local base
    if s.path == s.home or s.path:sub(1, #s.home + 1) == s.home .. "/" then
        base = s.home
        parts[1] = { name = "Home", path = s.home }
        local rest = s.path:sub(#s.home + 2)
        acc = s.home
        for seg in rest:gmatch("[^/]+") do
            acc = acc .. "/" .. seg
            parts[#parts + 1] = { name = seg, path = acc }
        end
    else
        parts[1] = { name = "Computer", path = "/" }
        acc = ""
        for seg in s.path:gmatch("[^/]+") do
            acc = acc .. "/" .. seg
            parts[#parts + 1] = { name = seg, path = acc }
        end
    end
    local function widths()
        local out, total = {}, 0
        for i, p in ipairs(parts) do
            local nm = p.name
            if #nm > 22 then nm = nm:sub(1, 21) .. "…" end
            out[i] = { nm = nm, w = 8 + #nm * 7.6 }
            total = total + out[i].w + 26
        end
        return out, total
    end
    -- the last folders that fit the room (the one you are in always stays), with a "…" for the way up that does not
    local ws, total = widths()
    local dropped_one = false
    while #parts > 1 and total > s.crumbw do
        table.remove(parts, 1)
        dropped_one = true
        ws, total = widths()
    end
    if dropped_one then
        local up = dirname(parts[1].path)
        table.insert(parts, 1, { name = "…", path = up })
        ws = widths()
    end
    local rows, x = {}, 0
    for i, p in ipairs(parts) do
        local w = ws[i].w
        rows[i] = { at = i - 1, name = ws[i].nm, path = p.path, x = x, w = w, last = i == #parts }
        x = x + w + 26
    end
    s.crumbs = rows
    model.crumbs = rows
end

local function show_places()
    local rows = {}
    for i, p in ipairs(s.places) do
        rows[i] = { at = i - 1, name = p.name, path = p.path, pk = p.pk, here = p.path == s.path, pinned = p.pinned == true }
    end
    model.places = rows
end

local function show_free()
    run("df", { "-B1", "--output=avail", s.path }, function(out)
        local n = tonumber((out or ""):match("\n%s*(%d+)"))
        text.free = n and (size_text(n) .. " free") or ""
    end)
end

local function nav_flags()
    fact["can.back"] = #s.back > 0
    fact["can.fwd"] = #s.fwd > 0
end

-- ── going somewhere ──
local go_seq = 0          -- each going has a number: the answer of one that was overtaken (two clicks in a row, the first folder slow) is dropped
local function go(path, how, then_pick, on_fail)
    path = clean(path)
    go_seq = go_seq + 1
    local mine = go_seq
    list_dir(path, function(items)
        if mine ~= go_seq then return end
        if not items then
            text.status = "Can't open " .. basename(path)
            if on_fail then on_fail() end
            return
        end
        if how == nil and s.path ~= "" and s.path ~= path then
            s.back[#s.back + 1] = s.path
            s.fwd = {}
        end
        s.path = path
        fact["in.trash"] = path == s.data .. "/Trash/files"
        if s.mode then s.mode, s.results, s.qtext = nil, nil, ""; text.sq = ""; fact.searching = false end       -- (a search belongs to the folder it was made in)
        s.all = items
        s.items = visible()
        s.picked = {}
        s.anchor = nil
        if then_pick then
            for i, e in ipairs(s.items) do
                if e.name == then_pick then s.picked[e.path] = true; s.anchor = i end
            end
        end
        s.first = 0
        s.scroll = 0
        fact.gen = (tonumber(fact.gen) or 0) + 1
        nav_flags()
        show_crumbs()
        show_places()
        show_rows()
        show_free()
        fact.ready = true
    end)
end

local run_search
local function refresh(then_pick, cb)
    local here = s.path
    list_dir(here, function(items)
        if not items or here ~= s.path then return end       -- (or we have gone somewhere else meanwhile: that listing is of the old folder)
        local old = {}
        for p in pairs(s.picked) do old[p] = true end
        s.all = items
        if s.mode == "deep" then run_search(true) return end       -- what was found is looked for again
        s.items = visible()
        s.picked = {}
        for i, e in ipairs(s.items) do
            if then_pick then
                if e.name == then_pick then s.picked[e.path] = true; s.anchor = i end
            elseif old[e.path] then
                s.picked[e.path] = true
            end
        end
        show_rows()
        show_free()
        if cb then cb() end
    end)
end

local function open_item(e)
    if e.dir then go(e.path) else spawn("xdg-open", { e.path }, function() end, function() end) end
end

-- ── the places on the left ──
local function build_places(found)
    found = found or s.found or {}
    s.found = found
    local list = {
        { name = "Computer", path = "/", pk = 3 },
        { name = "Home", path = s.home, pk = 1 },
        { name = "Documents", path = found.DOCUMENTS, pk = 5 },
        { name = "Downloads", path = found.DOWNLOAD, pk = 4 },
        { name = "Music", path = found.MUSIC, pk = 7 },
        { name = "Pictures", path = found.PICTURES, pk = 6 },
        { name = "Videos", path = found.VIDEOS, pk = 8 },
        { name = "Trash", path = s.data .. "/Trash/files", pk = 2 },
    }
    s.places = {}
    local seen = {}
    for _, p in ipairs(list) do
        if p.path then s.places[#s.places + 1] = p; seen[p.path] = true end
    end
    -- the folders you pinned come after the others
    for _, path in ipairs(s.pins) do
        if not seen[path] then
            s.places[#s.places + 1] = { name = basename(path), path = path, pk = 0, pinned = true }
            seen[path] = true
        end
    end
end

local DEFAULT_DIR = { DESKTOP = "Desktop", DOCUMENTS = "Documents", DOWNLOAD = "Downloads", MUSIC = "Music", PICTURES = "Pictures", VIDEOS = "Videos" }

local function start()
    run("printenv", { "HOME" }, function(h)
        s.home = trim(h)
        run("printenv", { "XDG_DATA_HOME" }, function(d)
            s.data = trim(d) ~= "" and trim(d) or (s.home .. "/.local/share")
            local names = { "DESKTOP", "DOCUMENTS", "DOWNLOAD", "MUSIC", "PICTURES", "VIDEOS" }
            local found = {}
            local function nextdir(k)
                if k > #names then
                    -- (only the ones that are there: the user-dirs file names Desktop and the rest even when the folders were never made)
                    local paths = {}
                    for _, n in ipairs(names) do if found[n] then paths[#paths + 1] = found[n] end end
                    local function finish(there)
                        for _, n in ipairs(names) do if found[n] and not there[found[n]] then found[n] = nil end end
                        build_places(found)
                        run("printenv", { "FILES_START" }, function(o, code)
                            local start_at = trim(o)
                            local want = code == 0 and start_at:sub(1, 1) == "/" and start_at or s.home
                            go(want, nil, nil, function() if want ~= s.home then go(s.home) end end)       -- a start folder that is not there: the home folder, not an empty window
                        end)
                    end
                    if #paths == 0 then finish({}) return end
                    local args = {}
                    for _, p in ipairs(paths) do args[#args + 1] = p end
                    for _, x in ipairs({ "-maxdepth", "0", "-type", "d", "-printf", "%p\n" }) do args[#args + 1] = x end
                    run("find", args, function(out)
                        local there = {}
                        for line in (out or ""):gmatch("[^\n]+") do there[line] = true end
                        finish(there)
                    end)
                    return
                end
                run("xdg-user-dir", { names[k] }, function(o, code)
                    local p = trim(o)
                    -- (xdg-user-dir says the home folder for one that was never set: then the usual name, if that folder is there)
                    if code ~= 0 or p == "" or p == s.home then p = s.home .. "/" .. DEFAULT_DIR[names[k]] end
                    found[names[k]] = p
                    nextdir(k + 1)
                end)
            end
            nextdir(1)
        end)
    end)
end

-- how much room the path has (the scene says): the last folders that fit are shown
on("fact:crumbw", function(v)
    v = tonumber(v)
    if v and math.abs(v - s.crumbw) > 4 then
        s.crumbw = v
        if s.path ~= "" then show_crumbs() end
    end
end)

-- A window that is already open (this logic was reloaded) has its columns already: take them, or rows would be laid out for one count and drawn for another.
do
    local c = math.floor(tonumber(fact.cols) or 0)
    if c >= 1 and c <= MAX_COLS then s.cols = c end
end

-- ── choosing ──
on("tile", function(i)
    s.menu = nil
    fact["menu.on"] = false
    if i < 0 then
        s.picked = {}
        show_rows()
        return
    end
    local e = s.items[i + 1]
    if not e then return end
    local double = s.last_i == i and s.tick - s.last_tick < 9
    s.last_i, s.last_tick = i, s.tick
    if double then
        s.last_i = nil
        open_item(e)
        return
    end
    s.picked = { [e.path] = true }
    s.anchor = i + 1
    show_rows()
    prep_drag_icon()
end)

on("place", function(i)
    local p = s.places[(tonumber(i) or -1) + 1]
    if not p then return end
    if p.pk == 2 then
        -- the Trash folder is only there once something has been put in it
        run("mkdir", { "-p", "--", p.path }, function() go(p.path) end)
    else
        go(p.path)
    end
end)
on("crumb", function(i)
    local c = s.crumbs[(tonumber(i) or -1) + 1]
    if c then go(c.path) end
end)

on("slid", function(scroll)
    s.scroll = tonumber(scroll) or 0
    local back = s.view == "grid" and 2 or 1
    local first = math.max(math.floor(s.scroll / row_h()) - back, 0)
    if math.abs(first - s.first) >= back then
        s.first = first
        show_rows()
    end
end)
on("set_cols", function(n)
    n = math.max(1, math.min(math.floor(tonumber(n) or 1), MAX_COLS))
    if n ~= s.cols then
        s.cols = n
        fact.cols = n
        show_rows()
    end
end)

-- ── a name to give: a new folder, a new name ──
local function ask(kind, title, value, ok)
    s.ask = kind
    fact["ask.input"] = true
    fact["ask.danger"] = false
    text["ask.title"] = title
    text["ask.ok"] = ok
    text.askin = value or ""
    fact["ask.on"] = true
    fact["ask.gen"] = (tonumber(fact["ask.gen"]) or 0) + 1
    after(60, function() focus("askin") end)
end
-- a question with Cancel and one button, in the alert colour: for what cannot be undone
local function confirm(title, msg, ok, fn)
    s.ask = "confirm"
    s.confirm_fn = fn
    fact["ask.input"] = false
    fact["ask.danger"] = true
    text["ask.title"] = title
    text["ask.msg"] = msg
    text["ask.ok"] = ok
    fact["ask.on"] = true
end
local function close_ask()
    s.ask = nil
    s.confirm_fn = nil
    fact["ask.on"] = false
    focus()
end

local function exists(name)
    for _, e in ipairs(s.all or {}) do
        if e.name == name then return true end
    end
    return false
end
-- a name that is free in this folder: "name copy", "name copy 2" … (before the extension)
local function free_name(name, reserved)
    local function taken(n) return exists(n) or (reserved ~= nil and reserved[n] == true) end
    if not taken(name) then return name end
    local stem, ext = name:match("^(.+)(%.[^.]+)$")
    if not stem then stem, ext = name, "" end
    local n = 1
    while true do
        local cand = stem .. (n == 1 and " copy" or (" copy " .. n)) .. ext
        if not taken(cand) then return cand end
        n = n + 1
    end
end

on("ask_ok", function()
    if s.ask == "confirm" then
        local fn = s.confirm_fn
        close_ask()
        if fn then fn() end
        return
    end
    local name = trim(text.askin)
    if name == "" then return end
    if name:find("/", 1, true) or name == "." or name == ".." then
        text.status = "A name cannot have a slash in it"
        return
    end
    local kind = s.ask
    if kind == "new" then
        if exists(name) then text.status = "\"" .. name .. "\" is already here" return end
        close_ask()
        run("mkdir", { "--", join(s.path, name) }, function(_, code)
            if code ~= 0 then text.status = "Could not make the folder" end
            refresh(name)
        end)
    elseif kind == "rename" then
        local e = picked_list()[1]
        if not e then close_ask() return end
        if name == e.name then close_ask() return end
        if exists(name) then text.status = "\"" .. name .. "\" is already here" return end
        close_ask()
        run("mv", { "-n", "--", e.path, join(s.path, name) }, function(_, code)
            if code ~= 0 then text.status = "Could not rename it" end
            refresh(name)
        end)
    end
end)

-- ── the properties card ──
local KIND_LABEL = { [0] = "Folder", "Picture", "PDF document", "Sound", "Video", "Code or text", "Archive", "File" }
local function commas(n)
    local t = tostring(math.floor(tonumber(n) or 0))
    local out = t:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end
local function close_props()
    s.props = nil
    fact["prop.on"] = false
end
local function set_prows(rows)
    model.prows = rows
    fact["prop.h"] = 90 + 14 + #rows * 30 + 14 + 54
end

local show_props
function show_props()
    local list = picked_list()
    local gen = (s.pgen or 0) + 1
    s.pgen = gen
    s.props = gen
    s.menu = nil
    fact["menu.on"] = false
    if #list > 1 then
        local files, dirs, bytes = 0, 0, 0
        for _, e in ipairs(list) do
            if e.dir then dirs = dirs + 1 else files = files + 1; bytes = bytes + e.size end
        end
        model.pinfo = { { name = string.format("%d items", #list), sub = string.format("%d %s, %d %s", files, files == 1 and "file" or "files", dirs, dirs == 1 and "folder" or "folders"), ik = 7, thumb = "", ["has.thumb"] = false } }
        set_prows({
            { label = "Location", value = s.path },
            { label = "Files' size", value = size_text(bytes) .. " (" .. commas(bytes) .. " bytes)" },
            { label = "Folders", value = tostring(dirs) },
        })
        fact["prop.on"] = true
        return
    end
    local e = list[1] or { name = basename(s.path), path = s.path, dir = true, size = 0, mtime = 0, ik = 0 }
    local th = e.dir and nil or s.thumbs[e.path .. "|" .. e.size .. "|" .. e.mtime]
    run("stat", { "-c", "%F\t%s\t%Y\t%X\t%W\t%U\t%G\t%A\t%a\t%N", "--", e.path }, function(out, code)
        if s.props ~= gen then return end
        local f = {}
        for v in (out or ""):gmatch("([^\t\n]*)\t?") do f[#f + 1] = v end
        local kind, size, mtime, atime, btime, user, group, perm_s, perm_o, nm = f[1], tonumber(f[2]) or e.size, tonumber(f[3]) or e.mtime, tonumber(f[4]) or 0, tonumber(f[5]) or 0, f[6], f[7], f[8], f[9], f[10] or ""
        local target = nm:match("%-> '(.*)'$")
        local rows = {}
        local function add(label, value) if value and value ~= "" then rows[#rows + 1] = { label = label, value = value, tog = false, on = false } end end
        local type_idx = rows
        add("Type", KIND_LABEL[e.ik] or "File")
        add("Location", dirname(e.path))
        if e.dir then add("Size", "Calculating…") else add("Size", size_text(size) .. " (" .. commas(size) .. " bytes)") end
        if e.dir then add("Contains", "…") end
        add("Modified", date_text(mtime))
        if atime > 0 then add("Accessed", date_text(atime)) end
        if btime > 0 then add("Created", date_text(btime)) end
        add("Permissions", (perm_s or "") .. "  (" .. (perm_o or "") .. ")")
        add("Owner", (user or "") .. " : " .. (group or ""))
        if target then add("Link to", target) end
        if list[1] then
            s.props_e = e
            rows[#rows + 1] = { label = "Hidden", value = e.hidden and "Yes (the name starts with a dot)" or "No", tog = true, on = e.hidden == true }
        end
        model.pinfo = { { name = e.name, sub = (KIND_LABEL[e.ik] or "File") .. (e.dir and "" or (" · " .. size_text(size))), ik = e.ik, thumb = th or "", ["has.thumb"] = th ~= nil and th ~= false } }
        set_prows(rows)
        fact["prop.on"] = true
        local function update(label, value)
            if s.props ~= gen then return end
            for _, r in ipairs(rows) do if r.label == label then r.value = value end end
            model.prows = rows
        end
        -- what the file is, by its contents
        run("file", { "-b", "--mime-type", "--", e.path }, function(m)
            local mime = trim(m)
            if mime ~= "" then update("Type", (KIND_LABEL[e.ik] or "File") .. "  (" .. mime .. ")") end
        end)
        if e.dir then
            if e.path == "/" then
                update("Size", "—")       -- (adding up the whole computer takes minutes, and is not stopped when the card is closed)
            else
                run("du", { "-sbxD", "--", e.path }, function(d)       -- D: a link to a folder is its folder; x: not into other disks
                    local n = tonumber((d or ""):match("^(%d+)"))
                    if n then update("Size", size_text(n) .. " (" .. commas(n) .. " bytes)") else update("Size", "unknown") end
                end)
            end
            run("find", { "-H", e.path, "-mindepth", "1", "-maxdepth", "1", "-printf", "." }, function(c)
                local n = #(c or "")
                update("Contains", n == 1 and "1 item" or (commas(n) .. " items"))
            end)
        end
    end)
end

-- Hidden or not: a name that starts with a dot is hidden, so the switch adds the dot or takes it away.
local function toggle_hidden_file()
    local e = s.props_e
    if not (e and s.props) then return end
    local new = e.hidden and e.name:gsub("^%.", "") or ("." .. e.name)
    if new == "" or new == "." or new == ".." or new == e.name then return end
    if exists(new) then text.status = "\"" .. new .. "\" is already here" return end
    run("mv", { "-n", "--", e.path, join(s.path, new) }, function(_, code)
        if code ~= 0 then text.status = "Could not change it" return end
        if (not e.hidden) and not s.hidden then
            -- hidden now, and hidden files are not shown: it leaves the list
            close_props()
            refresh()
            text.status = "\"" .. new .. "\" is hidden now (Ctrl+H shows hidden files)"
            return
        end
        refresh(new, function() show_props() end)
    end)
end

-- ── dragging files in and out ──
-- What was carried arrives by the zone's name (`drop:<zone>`, the paths as `file://…` lines) and where it was dropped by the scene's event `dropped(k)`: whichever comes second does the work.
-- k: a tile's number (a folder takes it in; a file means this folder), -1 the empty middle, -100 - n a place, -200 - n a folder of the path, -400 the pin zone.
local function unescape(u) return (u:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end
local function paths_of(data)
    local out = {}
    for line in (data or ""):gmatch("[^\r\n]+") do
        local p = line:match("^file://(/.*)$")
        if p then p = unescape(p) elseif line:sub(1, 1) == "/" then p = line end
        if p and p ~= "/" then out[#out + 1] = (p:gsub("/+$", "")) end
    end
    return out
end

local function pin_folders(paths)
    local dirs = paths
    if #dirs == 0 then return end
    local args = {}
    for _, p in ipairs(dirs) do args[#args + 1] = p end
    for _, x in ipairs({ "-maxdepth", "0", "-type", "d", "-printf", "%p\n" }) do args[#args + 1] = x end
    run("find", args, function(out)
        local added = {}
        local have = {}
        for _, p in ipairs(s.places) do have[p.path] = true end
        for line in (out or ""):gmatch("[^\n]+") do
            if not have[line] then
                s.pins[#s.pins + 1] = line
                have[line] = true
                added[#added + 1] = basename(line)
            end
        end
        if #added == 0 then
            text.status = "Only folders can be pinned, and not twice"
            return
        end
        save()
        build_places()
        show_places()
        text.status = "Pinned " .. table.concat(added, ", ")
    end)
end

-- Into `dest`: moved when it is on the same disk as where it came from, copied when it is not; a name that is taken gets another ("name copy").
local function transfer(paths, dest)
    local jobs = {}
    for _, src in ipairs(paths) do
        if src ~= dest and dirname(src) ~= dest and (dest .. "/"):sub(1, #src + 1) ~= src .. "/" then jobs[#jobs + 1] = src end
    end
    if #jobs == 0 then
        text.status = "Already in " .. basename(dest)      -- (a drop that changes nothing says so, not nothing)
        return
    end
    if dest == s.data .. "/Trash/files" then
        local pending = #jobs
        for _, p in ipairs(jobs) do
            run("gio", { "trash", "--", p }, function()
                pending = pending - 1
                if pending == 0 then refresh() end
            end)
        end
        return
    end
    local args = { "-c", "%d", "--", dest }
    for _, p in ipairs(jobs) do args[#args + 1] = p end
    run("stat", args, function(out)
        local devs = {}
        for line in (out or ""):gmatch("[^\n]+") do devs[#devs + 1] = line end
        run("find", { dest, "-maxdepth", "1", "-mindepth", "1", "-printf", "%f\n" }, function(names)
            local taken = {}
            for n in (names or ""):gmatch("[^\n]+") do taken[n] = true end
            local todo = {}
            for i, src in ipairs(jobs) do
                local name = basename(src)
                if taken[name] then
                    local stem, ext = name:match("^(.+)(%.[^.]+)$")
                    if not stem then stem, ext = name, "" end
                    local n = 1
                    repeat
                        name = stem .. (n == 1 and " copy" or (" copy " .. n)) .. ext
                        n = n + 1
                    until not taken[name]
                end
                taken[name] = true
                todo[#todo + 1] = { src = src, dst = dest .. "/" .. name, same = devs[1] ~= nil and devs[1] == devs[i + 1] }
            end
            local pending = #todo
            for _, j in ipairs(todo) do
                local cmd, a = "cp", { "-r", "--", j.src, j.dst }
                if j.same then cmd, a = "mv", { "-n", "--", j.src, j.dst } end
                run(cmd, a, function(_, code)
                    if code ~= 0 then text.status = "Something could not be moved" end
                    pending = pending - 1
                    if pending == 0 then refresh() end
                end)
            end
        end)
    end)
end

local drop_data, drop_at, drop_rank = nil, nil, 0
local drop_timer = false
local function do_drop(data, k)
    local paths = paths_of(data)
    if #paths == 0 then return end
    if k == -400 then pin_folders(paths) return end
    local dest = s.path
    if k >= 0 then
        local e = s.items[k + 1]
        if e and e.dir then dest = e.path end
    elseif k <= -200 then
        local c = s.crumbs[-200 - k + 1]
        if c then dest = c.path end
    elseif k <= -100 then
        local p = s.places[-100 - k + 1]
        if p then dest = p.path end
    end
    transfer(paths, dest)
end
-- More than one zone says it was dropped on (a folder, and the middle behind it): for a moment they are collected and the most specific one is the one that counts.
local function rank(k)
    if k >= 0 then return 3 end
    if k <= -100 then return 2 end
    return 1
end
local function settle()
    if drop_timer then return end
    drop_timer = true
    after(120, function()
        drop_timer = false
        local data, k = drop_data, drop_at
        drop_data, drop_at, drop_rank = nil, nil, 0
        if data and k then do_drop(data, k) end
    end)
end
for _, zone in ipairs({ "midzone", "grid", "t", "pz", "cz", "pinzone" }) do       -- (the list lies over the middle: a drop on its empty part is the list's)
    on("drop:" .. zone, function(data)
        drop_data = data
        settle()
    end)
end
on("dropped", function(k)
    k = math.floor(tonumber(k) or 0)
    if rank(k) > drop_rank then drop_at, drop_rank = k, rank(k) end
    settle()
end)

-- ── the menu ──
local function open_menu(kind)
    local rows = {}
    local list = picked_list()
    local in_trash = fact["in.trash"] == true
    local function add(label, k, on, ic, key, sep, danger)
        rows[#rows + 1] = { label = label, k = k, on = on, ic = ic, key = key or "", sep = sep == true, danger = danger == true }
    end
    if kind == "item" then
        add("Open", 7, #list >= 1, 8, "Enter")
        add("Rename", 2, #list == 1, 9, "F2")
        add("Copy", 4, #list >= 1, 10, "Ctrl+C", true)
        add("Cut", 5, #list >= 1, 11, "Ctrl+X")
        add("Properties", 16, #list >= 1, 16, "Alt+Enter", true)
        -- (Delete for good is the keys' only: Shift+Delete, and Delete in the trash itself)
        if not in_trash then add("Move to Trash", 3, #list >= 1, 13, "Del", true, true) end
    else
        if in_trash then add("Empty Trash", 18, #s.items > 0, 13, "", false, true) end
        add("New folder", 1, true, 6, "Ctrl+Shift+N", in_trash)
        add("Paste", 6, true, 12, "Ctrl+V")
        add("Select all", 8, #s.items > 0, 14, "Ctrl+A", true)
        add(s.hidden and "Hide hidden files" or "Show hidden files", 14, true, 5, "Ctrl+H")
        add("Refresh", 9, true, 15, "F5")
        add("Properties", 16, true, 16, "Alt+Enter", true)
    end
    local h = 14
    for _, r in ipairs(rows) do h = h + 36 + (r.sep and 9 or 0) end
    s.menu = kind
    model.menuitems = rows
    fact["menu.h"] = h
    fact["menu.on"] = true
end
local function close_menu()
    s.menu = nil
    fact["menu.on"] = false
end
on("menu_close", close_menu)
on("tile_menu", function(i)
    local e = s.items[(tonumber(i) or -1) + 1]
    if e and not s.picked[e.path] then
        s.picked = { [e.path] = true }
        s.anchor = i + 1
        show_rows()
    end
    open_menu("item")
end)
on("bg_menu", function() open_menu("bg") end)
on("place_menu", function(i)
    local p = s.places[(tonumber(i) or -1) + 1]
    if not p then return end
    s.menu_place = p
    local rows = { { label = "Open", k = 42, on = true, ic = 8, key = "", sep = false, danger = false } }
    if p.pk == 2 then
        rows = { { label = "Empty Trash", k = 43, on = true, ic = 13, key = "", sep = false, danger = true } }
    end
    if p.pinned then rows[#rows + 1] = { label = "Unpin from the sidebar", k = 41, on = true, ic = 7, key = "", sep = true, danger = false } end
    s.menu = "place"
    model.menuitems = rows
    fact["menu.h"] = 14 + 36 * #rows + (p.pinned and 9 or 0)
    fact["menu.on"] = true
end)

-- ── doing things to what is chosen ──
local function run_each(cmd, args_for, list, done)
    local pending = #list
    if pending == 0 then done() return end
    for _, item in ipairs(list) do
        run(cmd, args_for(item), function(_, code)
            if code ~= 0 then text.status = "Something could not be done" end
            pending = pending - 1
            if pending == 0 then done() end
        end)
    end
end

-- Copy and cut go on the system clipboard (what the file managers use: `x-special/gnome-copied-files`, a first line `copy` or `cut` and then one `file://` address a line), so that
-- another window of this, or another file manager, can paste what was copied here, and the other way round. `s.clip` only remembers what this window cut, to draw it faint.
local function uri_of(path)
    return "file://" .. path:gsub("[^%w%-%._~/]", function(c) return string.format("%%%02X", c:byte()) end)
end
local function set_clip(cut)
    local list = picked_list()
    if #list == 0 then return end
    local set, uris = {}, { cut and "cut" or "copy" }
    for _, e in ipairs(list) do set[e.path] = true; uris[#uris + 1] = uri_of(e.path) end
    s.clip = { cut = cut, set = set }
    run("wl-copy", { "-t", "x-special/gnome-copied-files", "--", table.concat(uris, "\n") }, function(_, code)
        if code ~= 0 then text.status = "The clipboard could not be written" end
    end)
    fact["clip.on"] = true
    text.status = string.format("%d %s", #list, cut and "cut" or "copied")
    show_rows()
end
local function clear_clip()
    s.clip = nil
    fact["clip.on"] = false
    run("wl-copy", { "--clear" }, function() end)
end

-- What is on the clipboard, from this window or any other program: the paths and whether they were cut. The file managers' own kind first, then a plain list of addresses.
local function read_clip(cb)
    run("wl-paste", { "--no-newline", "-t", "x-special/gnome-copied-files" }, function(out, code)
        if code == 0 and out and out ~= "" then
            local paths = paths_of(out)
            if #paths > 0 then cb(paths, out:match("^[^\r\n]*") == "cut") return end
        end
        run("wl-paste", { "--no-newline", "-t", "text/uri-list" }, function(out2, code2)
            local paths = code2 == 0 and paths_of(out2) or {}
            if #paths > 0 then cb(paths, false) else cb(nil) end
        end)
    end)
end

local function paste()
    read_clip(function(paths, cut)
        if not paths then text.status = "Nothing to paste" return end
        local jobs = {}
        local reserved = {}      -- the names this paste has given already, so that the next one of the same name gets another
        for _, src in ipairs(paths) do
            local name = free_name(basename(src), reserved)
            if s.path == src or (s.path .. "/"):sub(1, #src + 1) == src .. "/" then
                text.status = "A folder cannot go into itself"
            elseif not (cut and dirname(src) == s.path) then
                jobs[#jobs + 1] = { src = src, dst = join(s.path, name) }
                reserved[name] = true
            end
        end
        if cut then clear_clip() end
        run_each(cut and "mv" or "cp", function(j)
            if cut then return { "-n", "--", j.src, j.dst } end
            return { "-r", "--", j.src, j.dst }
        end, jobs, function() refresh() end)
    end)
end

local function trash()
    local list = picked_list()
    if #list == 0 then return end
    run_each("gio", function(e) return { "trash", "--", e.path } end, list, function() refresh() end)
end

-- a path that must never be deleted, however it is asked for: the root, the home folder, and the places in the sidebar
local function protected(path)
    if path == "/" or path == s.home or path == s.data .. "/Trash" or path == s.data .. "/Trash/files" then return true end
    for _, p in ipairs(s.places) do if p.path == path then return true end end
    local _, depth = path:gsub("/", "")
    return depth < 2
end
local function delete_for_good()
    local list = picked_list()
    if #list == 0 then return end
    for _, e in ipairs(list) do
        if protected(e.path) then text.status = "That one is not to be deleted" return end
    end
    local what = #list == 1 and ("\"" .. list[1].name .. "\"") or (#list .. " items")
    confirm("Delete for good?", what .. " will be deleted permanently. This cannot be undone.", "Delete", function()
        run_each("rm", function(e) return { "-rf", "--", e.path } end, list, function() refresh() end)
    end)
end
local function empty_trash(from_place)
    if #s.items == 0 and not from_place then return end
    confirm("Empty the Trash?", "Everything in the Trash will be deleted permanently. This cannot be undone.", "Empty", function()
        run("gio", { "trash", "--empty" }, function(_, code)
            if code ~= 0 then text.status = "The Trash could not be emptied" end
            refresh()
        end)
    end)
end

local function select_all()
    s.picked = {}
    for _, e in ipairs(s.items) do s.picked[e.path] = true end
    show_rows()
end

local function ensure_visible(idx)
    local top = item_top(idx)
    local vh = tonumber(fact.vh) or 400
    local target
    if top < s.scroll then target = top
    elseif top + tile_h() > s.scroll + vh then target = top + tile_h() - vh end
    if target then
        fact.scroll_to = math.max(0, target)
        after(250, function() fact.scroll_to = -1 end)
    end
end

local function move_choice(d)
    local n = #s.items
    if n == 0 then return end
    local cur = s.anchor
    if not cur then
        local first = picked_list()[1]
        for i, e in ipairs(s.items) do if first and e.path == first.path then cur = i end end
    end
    local idx = cur and math.max(1, math.min(n, cur + d)) or 1
    s.anchor = idx
    s.picked = { [s.items[idx].path] = true }
    show_rows()
    ensure_visible(idx)
end

-- ── search ──
-- The magnifier (or Ctrl+F) opens a field where the path was. What is typed narrows this folder as it is typed (`filter`); Enter looks in the folders under it as well (`deep`: up to 500
-- finds, eight folders down, leaving out version control, caches and, unless hidden files are shown, the hidden folders) and shows them as the folder's own list, so they open,
-- copy, cut and go to the Trash like anything else. Escape, the magnifier again or going to another folder puts the folder back.
local search_seq = 0
function run_search(again)
    local q = trim(s.qtext)
    if q == "" then return end
    local here = s.path
    local glob = q:gsub("[%*%?%[%]\\]", "\\%0")
    local args = { here, "-mindepth", "1", "-maxdepth", "8", "(", "-name", ".git", "-o", "-name", "node_modules", "-o", "-name", ".cache" }
    if not s.hidden then for _, a in ipairs({ "-o", "-name", ".*" }) do args[#args + 1] = a end end
    for _, a in ipairs({ ")", "-prune", "-o", "-iname", "*" .. glob .. "*", "-printf", "%y\t%s\t%T@\t%p\n" }) do args[#args + 1] = a end
    search_seq = search_seq + 1
    local mine = search_seq
    text.status = "Searching…"
    run("find", args, function(out)
        if mine ~= search_seq or here ~= s.path or not s.mode then return end
        local items = {}
        for line in (out or ""):gmatch("[^\n]+") do
            local ty, sz, mt, path = line:match("^(%a)\t(%d+)\t([%d%.]+)\t(.*)$")
            if path then
                local name = basename(path)
                local dir = ty == "d"
                items[#items + 1] = { name = name, path = path, dir = dir, size = tonumber(sz) or 0, mtime = tonumber(mt) or 0, hidden = name:sub(1, 1) == ".", ik = ik_of(name, dir) }
                if #items >= 500 then break end
            end
        end
        s.mode, s.results = "deep", items
        s.items = visible()
        s.picked = {}
        if not again then
            s.first = 0
            fact.gen = (tonumber(fact.gen) or 0) + 1
        end
        show_rows()
    end)
end
local function open_search()
    s.menu = nil
    fact["menu.on"] = false
    if not s.mode then
        s.mode, s.qtext = "filter", ""
        text.sq = ""
        fact.searching = true
    end
    after(60, function() focus("sq") end)
end
local function close_search()
    if not s.mode then return end
    search_seq = search_seq + 1
    s.mode, s.results, s.qtext = nil, nil, ""
    text.sq = ""
    fact.searching = false
    focus()
    s.items = visible()
    s.picked = {}
    s.first = 0
    fact.gen = (tonumber(fact.gen) or 0) + 1
    show_rows()
end
on("text:sq", function(v)
    s.qtext = v or ""
    if not s.mode then return end
    search_seq = search_seq + 1
    s.mode, s.results = "filter", nil
    s.items = visible()
    s.picked = {}
    s.first = 0
    fact.gen = (tonumber(fact.gen) or 0) + 1
    show_rows()
end)
on("search_go", function() run_search() end)

on("act", function(k)
    k = math.floor(tonumber(k) or 0)
    if k ~= 6 and k ~= 10 then close_menu() end
    if (k == 1 or k == 6) and fact["in.trash"] == true then
        close_menu()
        text.status = k == 1 and "A folder cannot be made in the Trash" or "Use Move to Trash to put things in the Trash"
        return
    end
    if k == 1 then
        ask("new", "New folder", "", "Create")
    elseif k == 2 then
        local list = picked_list()
        if #list == 1 then ask("rename", "Rename", list[1].name, "Rename") end
    elseif k == 3 then
        if fact["in.trash"] == true then delete_for_good() else trash() end
    elseif k == 17 then
        delete_for_good()
    elseif k == 18 then
        empty_trash()
    elseif k == 4 then
        set_clip(false)
    elseif k == 5 then
        set_clip(true)
    elseif k == 6 then
        close_menu()
        paste()
    elseif k == 7 then
        local list = picked_list()
        if #list == 1 then open_item(list[1])
        else for _, e in ipairs(list) do if not e.dir then open_item(e) end end end
    elseif k == 8 then
        select_all()
    elseif k == 9 then
        refresh()
    elseif k == 10 then
        if s.props then close_props()
        elseif s.ask then close_ask()
        elseif s.menu then close_menu()
        elseif s.mode then close_search()
        elseif next(s.picked) then s.picked = {}; show_rows() end
    elseif k == 11 then
        if s.path ~= "/" then go(dirname(s.path), nil, basename(s.path)) end
    elseif k == 12 then
        local p = table.remove(s.back)
        if p then
            s.fwd[#s.fwd + 1] = s.path
            go(p, "nav", nil, function() table.remove(s.fwd); s.back[#s.back + 1] = p end)       -- (a folder that has gone: the history stays as it was)
        end
    elseif k == 13 then
        local p = table.remove(s.fwd)
        if p then
            s.back[#s.back + 1] = s.path
            go(p, "nav", nil, function() table.remove(s.back); s.fwd[#s.fwd + 1] = p end)
        end
    elseif k == 14 then
        s.hidden = not s.hidden
        fact.hidden = s.hidden
        save()
        s.items = visible()
        s.picked = {}
        show_rows()
    elseif k == 15 then
        local order = { name = "date", date = "size", size = "name" }
        s.sort = order[s.sort]
        fact.sort = s.sort
        text.sortname = "Sort: " .. SORT_NAMES[s.sort]
        save()
        s.items = visible()
        show_rows()
    elseif k == 20 then
        if s.view == "grid" then move_choice(-1) end
    elseif k == 21 then
        if s.view == "grid" then move_choice(1) end
    elseif k == 22 then
        move_choice(-down_by())
    elseif k == 23 then
        move_choice(down_by())
    elseif k == 30 then
        open_search()
    elseif k == 33 then
        if s.mode then close_search() else open_search() end       -- (the magnifier: open, or shut)
    elseif k == 16 then
        show_props()
    elseif k == 19 then
        toggle_hidden_file()
    elseif k == 50 then
        -- close this window: Hyprland closes the one that has the pointer (the one just clicked); elsewhere the window has its own cross, and this asks the scene to quit (by its own name)
        run("hyprctl", { "dispatch", "hl.dsp.window.close()" }, function(_, code)
            if code ~= 0 then
                -- bin/vitreus-files --close: the window that runs it asks for the name that is its own (a second window is not "files")
                run("vitreus-files", { "--close" }, function() end)
            end
        end)
    elseif k == 41 then
        local p = s.menu_place
        if p and p.pinned then
            for i, path in ipairs(s.pins) do if path == p.path then table.remove(s.pins, i) break end end
            save()
            build_places()
            show_places()
        end
    elseif k == 42 then
        if s.menu_place then go(s.menu_place.path) end
    elseif k == 43 then
        empty_trash(true)
    elseif k == 31 or k == 32 then
        s.view = k == 31 and "grid" or "lines"
        fact.view = s.view
        s.first = 0
        save()
        show_rows()
    end
end)

-- coming back to this window: what was dragged out or in from another one shows
on("focused", function()
    if s.path ~= "" then refresh() end
    -- a cut that was pasted from another window (which clears the clipboard) is not a cut here any more
    if s.clip then
        read_clip(function(paths) if not paths and s.clip then s.clip = nil; fact["clip.on"] = false; show_rows() end end)
    end
end)

-- the clock for telling a double click from two clicks
every(50, function() s.tick = s.tick + 1 end)

-- ── the theme: asked of Vitreus when this starts (it says so itself when it changes), and again a few seconds in ──
local function ask_obs()
    run("pleamar", { "--say", "vitreus", "get glass_obs" }, function(out, code)
        if code == 0 and out then fact.obs = out:match("true") ~= nil end
    end)
end
local function ask_look()
    run("pleamar", { "--say", "vitreus", "get cas" }, function(cas, code)
        if code ~= 0 or not cas then return end
        run("pleamar", { "--say", "vitreus", "get uwu" }, function(uwu, code2)
            if code2 ~= 0 or not uwu then return end
            run("pleamar", { "--say", "vitreus", "get cyber_on" }, function(cy, code3)
                if code3 ~= 0 or not cy then return end
                fact.look = cas:match("true") and 1 or (uwu:match("true") and 2 or (cy:match("true") and 3 or 0))
            end)
        end)
    end)
end
ask_obs()
ask_look()
after(4000, function() ask_obs(); ask_look() end)

start()
