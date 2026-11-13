-- {{< news-cards >}}: the homepage news cards, built from data/news.yml.
-- Shows items that have `featured: 1`, `featured: 2`, ... in that order
-- (or the first three items if none are featured).
local photos = dofile(quarto.utils.resolve_path("photos.lua"))
local esc = photos.esc

local function tag_for(item)
  local label = item.tag or (item.kind == "media" and "In the news" or "Update")
  local class = item.kind == "media" and "tag-media" or "tag-update"
  return label, class
end

return {
  ["news-cards"] = function(args, kwargs)
    local n = tonumber(pandoc.utils.stringify(kwargs["n"] or "")) or 3
    local items = photos.read_yaml_list("data/news.yml")

    local chosen = {}
    for _, it in ipairs(items) do
      if tonumber(it.featured or "") then chosen[#chosen + 1] = it end
    end
    table.sort(chosen, function(a, b) return tonumber(a.featured) < tonumber(b.featured) end)
    if #chosen == 0 then chosen = items end

    local grid = pandoc.Div({}, pandoc.Attr("", { "news-grid" }))
    for i = 1, math.min(n, #chosen) do
      local it = chosen[i]
      local card = pandoc.Div({}, pandoc.Attr("", { "news-card" }))
      if it.photo and it.photo ~= "" then
        local img = pandoc.Image(it.alt or "", "/" .. it.photo:gsub("^/", ""))
        card.content:insert(pandoc.Plain({ photos.wrap(img) }))
      end
      local label, class = tag_for(it)
      local title = esc(it.title)
      if it.url and it.url ~= "" and it.url ~= "#" then
        title = '<a class="stretched-link" href="' .. esc(it.url) .. '">' .. title .. "</a>"
      end
      card.content:insert(pandoc.RawBlock("html",
        '<p class="news-meta"><span class="tag ' .. class .. '">' .. esc(label) .. "</span>"
        .. '<span class="news-year">' .. esc(it.year) .. "</span></p>"
        .. '<h3 class="news-title">' .. title .. "</h3>"
        .. '<p class="news-source">' .. esc(it.source) .. "</p>"))
      grid.content:insert(card)
    end
    return grid
  end,
}
