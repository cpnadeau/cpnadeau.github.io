-- Shortcodes that build the Publications and News lists from the data files.
--   {{< publication-list >}}  reads data/publications.yml
--   {{< news-list >}}         reads data/news.yml
--   {{< photo-credits-table >}} reads photo_credits.csv (rows with status "selected")
-- The filter buttons are made to work by styles/filters.html.
-- To change an entry, edit the .yml file, not this file.

local photos = dofile(quarto.utils.resolve_path("photos.lua"))
local esc = photos.esc

local PUB_TYPES = {
  { "peer", "Peer-reviewed" },
  { "review", "In review" },
  { "other", "Reports and articles" },
}
local PUB_TOPICS = {
  { "climate", "Climate change" },
  { "restoration", "Restoration" },
  { "birds", "Birds" },
  { "quant", "Quantitative methods" },
}
local NEWS_KINDS = {
  { "media", "In the news" },
  { "update", "Update" },
}

local function label_of(list, key)
  for _, pair in ipairs(list) do
    if pair[1] == key then return pair[2] end
  end
  return key
end

-- A row of filter buttons. Hidden until the page script switches them on,
-- so nothing looks clickable if JavaScript is off.
local function chips(key, heading, all_label, options)
  local out = { '<div class="chip-row" role="group" aria-label="' .. esc(heading or "Filter") .. '" data-filter-key="' .. key .. '" hidden>' }
  if heading then out[#out + 1] = '<span class="chip-heading">' .. esc(heading) .. "</span>" end
  out[#out + 1] = '<button type="button" class="chip" data-value="all" aria-pressed="true">' .. esc(all_label) .. "</button>"
  for _, pair in ipairs(options) do
    out[#out + 1] = '<button type="button" class="chip" data-value="' .. pair[1] .. '" aria-pressed="false">' .. esc(pair[2]) .. "</button>"
  end
  out[#out + 1] = "</div>"
  return table.concat(out)
end

local function is_link(url)
  return url ~= nil and url ~= "" and url ~= "#"
end

-- Newest first; "In review" (or any year that isn't a number) goes on top.
local function by_year(items)
  for i, it in ipairs(items) do it._order = i end
  table.sort(items, function(a, b)
    local ya, yb = tonumber(a.year) or 9999, tonumber(b.year) or 9999
    if ya ~= yb then return ya > yb end
    return a._order < b._order
  end)
  return items
end

local function year_cell(year)
  local cls = tonumber(year) and "row-year" or "row-year row-year-text"
  return '<p class="' .. cls .. '">' .. esc(year) .. "</p>"
end

return {
  ["publication-list"] = function()
    local items = by_year(photos.read_yaml_list("data/publications.yml"))
    local html = { '<div class="filters" data-filter-list="publications">' }
    html[#html + 1] = chips("type", "Type", "All", PUB_TYPES)
    html[#html + 1] = chips("topic", "Topic", "All topics", PUB_TOPICS)
    html[#html + 1] = '<p class="filter-count" aria-live="polite">Showing ' .. #items .. " of " .. #items .. "</p></div>"
    html[#html + 1] = '<div class="row-list" id="publications">'
    for _, p in ipairs(items) do
      local tags = type(p.tags) == "table" and p.tags or {}
      local title = esc(p.title)
      if is_link(p.url) then title = '<a href="' .. esc(p.url) .. '">' .. title .. "</a>" end
      local venue = "<em>" .. esc(p.venue) .. "</em>"
      if p.note and p.note ~= "" then venue = venue .. " · " .. esc(p.note) end
      local tag_html = { '<span class="tag tag-' .. esc(p.type) .. '">' .. esc(label_of(PUB_TYPES, p.type)) .. "</span>" }
      for _, t in ipairs(tags) do
        tag_html[#tag_html + 1] = '<span class="topic">' .. esc(label_of(PUB_TOPICS, t)) .. "</span>"
      end
      html[#html + 1] = '<article class="row-item" data-type="' .. esc(p.type) .. '" data-topic="' .. esc(table.concat(tags, " ")) .. '">'
        .. year_cell(p.year)
        .. '<div class="row-body">'
        .. '<h2 class="pub-title">' .. title .. "</h2>"
        .. '<p class="pub-authors">' .. esc(p.authors) .. "</p>"
        .. '<p class="pub-venue">' .. venue .. "</p>"
        .. '<p class="pub-tags">' .. table.concat(tag_html) .. "</p>"
        .. "</div></article>"
    end
    html[#html + 1] = "</div>"
    return pandoc.RawBlock("html", table.concat(html, "\n"))
  end,

  ["news-list"] = function()
    local items = by_year(photos.read_yaml_list("data/news.yml"))
    local html = { '<div class="filters" data-filter-list="news">' }
    html[#html + 1] = chips("kind", nil, "All", NEWS_KINDS)
    html[#html + 1] = '<p class="filter-count" aria-live="polite">Showing ' .. #items .. " of " .. #items .. "</p></div>"
    html[#html + 1] = '<div class="row-list" id="news">'
    for _, n in ipairs(items) do
      local kind = n.kind == "media" and "media" or "update"
      local title = esc(n.title)
      if is_link(n.url) then title = '<a href="' .. esc(n.url) .. '">' .. title .. "</a>" end
      html[#html + 1] = '<article class="row-item" data-kind="' .. kind .. '">'
        .. year_cell(n.year)
        .. '<div class="row-body">'
        .. '<p class="news-meta"><span class="tag tag-' .. kind .. '">' .. esc(label_of(NEWS_KINDS, kind)) .. "</span>"
        .. '<span class="news-source">' .. esc(n.source) .. "</span></p>"
        .. '<h2 class="news-headline">' .. title .. "</h2>"
        .. "</div></article>"
    end
    html[#html + 1] = "</div>"
    return pandoc.RawBlock("html", table.concat(html, "\n"))
  end,

  ["photo-credits-table"] = function()
    local rows = {}
    for file, row in pairs(photos.credits()) do
      if row.status == "selected" then
        row._file = file
        rows[#rows + 1] = row
      end
    end
    table.sort(rows, function(a, b) return a._file:lower() < b._file:lower() end)

    local function cell(text) return (text and text ~= "") and esc(text) or "—" end
    local function link(url, text)
      if url and url:match("^https?://") then
        return '<a href="' .. esc(url) .. '">' .. esc(text) .. "</a>"
      end
      return "—"
    end

    local html = { '<div class="credits-table"><table>',
      "<thead><tr><th scope=\"col\">Photo</th><th scope=\"col\">Subject</th><th scope=\"col\">Credit</th>"
      .. "<th scope=\"col\">Source</th><th scope=\"col\">License</th><th scope=\"col\">Changes</th>"
      .. "<th scope=\"col\">Used on</th></tr></thead><tbody>" }
    for _, r in ipairs(rows) do
      local subject = r.subject ~= "" and r.subject or r.species
      if r.subject ~= "" and r.species ~= "" then subject = r.subject .. " (" .. r.species .. ")" end
      local license = r.license_url ~= "" and link(r.license_url, r.license) or cell(r.license)
      local src = photos.resolve_src("/images/" .. r._file)
      html[#html + 1] = "<tr>"
        .. '<td><img class="credit-thumb" src="' .. esc(src) .. '" alt="' .. esc(subject) .. '" loading="lazy"></td>'
        .. "<td>" .. cell(subject) .. "</td>"
        .. "<td>" .. cell(r.credit) .. "</td>"
        .. "<td>" .. link(r.download_link, "Original") .. "</td>"
        .. "<td>" .. license .. "</td>"
        .. "<td>" .. cell(r.changes) .. "</td>"
        .. "<td>" .. cell(r.used_on) .. "</td>"
        .. "</tr>"
    end
    html[#html + 1] = "</tbody></table></div>"
    return pandoc.RawBlock("html", table.concat(html, "\n"))
  end,
}
