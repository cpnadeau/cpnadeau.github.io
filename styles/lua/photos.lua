-- Shared helpers: read photo_credits.csv and build the credit strip for a photo.
-- Web copies in images/ are named after photo_name in the CSV: the extension
-- becomes .jpg and spaces/brackets/apostrophes become "_"
-- (e.g. "Boreal Chickadee (7452330700).jpg" -> "Boreal_Chickadee_7452330700.jpg").

local M = {}

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

-- The project folder (the one holding _quarto.yml). Quarto usually reports it,
-- but not always when RStudio previews a single page, so fall back to walking
-- up from the page being rendered until _quarto.yml is found.
local proj_cache = nil
local function project_dir()
  if proj_cache then return proj_cache end
  if quarto and quarto.project and quarto.project.directory
     and quarto.project.directory ~= "" then
    proj_cache = quarto.project.directory
    return proj_cache
  end
  local input = (quarto and quarto.doc and quarto.doc.input_file) or ""
  local dir = input:match("^(.*)[/\\][^/\\]*$")
  while dir and dir ~= "" do
    if file_exists(dir .. "/_quarto.yml") then
      proj_cache = dir
      return proj_cache
    end
    local parent = dir:match("^(.*)[/\\][^/\\]*$")
    if parent == dir then break end
    dir = parent
  end
  proj_cache = "."
  return proj_cache
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  return text
end

-- Small CSV parser (handles quoted fields with commas, quotes, and newlines)
local function parse_csv(text)
  local rows, row, field = {}, {}, {}
  local inq, i, n = false, 1, #text
  while i <= n do
    local c = text:sub(i, i)
    if inq then
      if c == '"' then
        if text:sub(i + 1, i + 1) == '"' then
          field[#field + 1] = '"'; i = i + 1
        else
          inq = false
        end
      else
        field[#field + 1] = c
      end
    elseif c == '"' then
      inq = true
    elseif c == "," then
      row[#row + 1] = table.concat(field); field = {}
    elseif c == "\n" or c == "\r" then
      if c == "\r" and text:sub(i + 1, i + 1) == "\n" then i = i + 1 end
      row[#row + 1] = table.concat(field); field = {}
      rows[#rows + 1] = row; row = {}
    else
      field[#field + 1] = c
    end
    i = i + 1
  end
  if #field > 0 or #row > 0 then
    row[#row + 1] = table.concat(field)
    rows[#rows + 1] = row
  end
  local header, out = rows[1] or {}, {}
  for r = 2, #rows do
    local d = {}
    for k, h in ipairs(header) do d[h] = rows[r][k] or "" end
    if d.photo_name and d.photo_name ~= "" then out[#out + 1] = d end
  end
  return out
end

function M.web_name(photo_name)
  local stem = photo_name:gsub("%.[^.]+$", "")
  stem = stem:gsub("[^%w%._%-]+", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
  return stem .. ".jpg"
end

local credits = nil
function M.credits()
  if credits then return credits end
  credits = {}
  local text = read_file(project_dir() .. "/photo_credits.csv")
  if not text then
    quarto.log.warning("photo_credits.csv not found")
    return credits
  end
  for _, row in ipairs(parse_csv(text)) do
    credits[M.web_name(row.photo_name)] = row
  end
  return credits
end

function M.esc(s)
  return (s or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end
local esc = M.esc

function M.credit_html(row)
  local credit = esc(row.credit)
  if row.download_link:match("^https?://") then
    credit = '<a href="' .. esc(row.download_link) .. '">' .. credit .. "</a>"
  end
  local parts = { credit }
  if row.license_url ~= nil and row.license_url ~= "" then
    parts[#parts + 1] = '<a href="' .. esc(row.license_url) .. '">' .. esc(row.license) .. "</a>"
  end
  if row.changes ~= nil and row.changes ~= "" then
    parts[#parts + 1] = esc(row.changes)
  end
  return table.concat(parts, ", ")
end

-- Turn a site path like "/images/x.jpg" into a path relative to the current page
-- (e.g. "../images/x.jpg" from a page inside research/).
function M.resolve_src(src)
  if not src:match("^/") then return src end
  local depth = 0
  local input = quarto.doc.input_file or ""
  local proj = project_dir()
  if input:sub(1, #proj) == proj then
    local rel = input:sub(#proj + 2)
    local _, n = rel:gsub("/", "")
    depth = n
  end
  local prefix = depth == 0 and "./" or string.rep("../", depth)
  return prefix .. src:sub(2)
end

-- Turn an Image into a photo with its credit in the bottom-right corner.
-- Written as plain HTML so the description stays as the image's alt text
-- (Quarto would otherwise turn it into a visible figure caption).
function M.wrap(img, loading)
  local file = img.src:match("([^/]+)$") or img.src
  local row = M.credits()[file]
  local strip
  if row and row.credit == "" and row.status == "selected" then
    strip = "" -- credit left blank on purpose (e.g. team headshots): show none
  elseif row then
    strip = '<span class="photo-credit">' .. M.credit_html(row) .. "</span>"
  else
    quarto.log.warning("No row in photo_credits.csv for " .. img.src)
    strip = '<span class="photo-credit photo-credit-missing">[credit missing from photo_credits.csv]</span>'
  end
  local alt = pandoc.utils.stringify(img.caption)
  if alt == "" then quarto.log.warning("Photo without a description (alt text): " .. img.src) end
  local attrs = {
    'src="' .. esc(M.resolve_src(img.src)) .. '"',
    'alt="' .. esc(alt) .. '"',
    'loading="' .. (loading or img.attributes.loading or "lazy") .. '"',
  }
  if img.identifier ~= "" then attrs[#attrs + 1] = 'id="' .. esc(img.identifier) .. '"' end
  if #img.classes > 0 then attrs[#attrs + 1] = 'class="' .. esc(table.concat(img.classes, " ")) .. '"' end
  for k, v in pairs(img.attributes) do
    if k ~= "loading" then attrs[#attrs + 1] = esc(k) .. '="' .. esc(v) .. '"' end
  end
  return pandoc.RawInline("html",
    '<span class="photo"><img ' .. table.concat(attrs, " ") .. ">" .. strip .. "</span>")
end

-- Read a YAML file whose top level is a list (like data/news.yml)
function M.read_yaml_list(rel_path)
  local text = read_file(project_dir() .. "/" .. rel_path)
  if not text then
    quarto.log.warning(rel_path .. " not found")
    return {}
  end
  local indented = ("\n" .. text):gsub("\n", "\n  ")
  local doc = pandoc.read("---\nitems:" .. indented .. "\n---\n", "markdown")
  local items = {}
  for _, it in ipairs(doc.meta.items or {}) do
    local t = {}
    for k, v in pairs(it) do
      if pandoc.utils.type(v) == "List" then
        t[k] = {}
        for _, x in ipairs(v) do t[k][#t[k] + 1] = pandoc.utils.stringify(x) end
      else
        t[k] = pandoc.utils.stringify(v)
      end
    end
    items[#items + 1] = t
  end
  return items
end

return M
