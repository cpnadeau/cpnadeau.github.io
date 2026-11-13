-- Page layouts that would otherwise need HTML in the .qmd files.
--
-- ::: project  (research pages)
--   The first photo goes on one side, everything else on the other side.
--   Projects alternate sides automatically and are numbered "Project 1, 2, ...".
--   No photo yet? Write a line starting with "Photo needed" and it becomes a grey box.
--   A paragraph starting with "Partners:" is set in small grey text.

local function count_images(block)
  local n = 0
  pandoc.walk_block(pandoc.Div({ block }), { Image = function() n = n + 1 end })
  return n
end

local function starts_with(block, prefix)
  if block.t ~= "Para" and block.t ~= "Plain" then return false end
  return pandoc.utils.stringify(block):sub(1, #prefix) == prefix
end

local project_count = 0

local function project(div)
  project_count = project_count + 1
  local photo, text = nil, pandoc.List()

  for _, block in ipairs(div.content) do
    if not photo and count_images(block) == 1 then
      photo = pandoc.Div({ block }, pandoc.Attr("", { "project-photo" }))
    elseif not photo and starts_with(block, "Photo needed") then
      photo = pandoc.Div({ pandoc.Plain({ pandoc.Span(block.content, pandoc.Attr("", { "photo-needed" })) }) },
        pandoc.Attr("", { "project-photo", "no-photo" }))
    elseif starts_with(block, "Partners:") then
      text:insert(pandoc.Div({ block }, pandoc.Attr("", { "partners" })))
    else
      text:insert(block)
    end
  end

  text:insert(1, pandoc.Para({ pandoc.Span({ pandoc.Str("Project " .. project_count) },
    pandoc.Attr("", { "eyebrow" })) }))

  local classes = pandoc.List(div.classes)
  if project_count % 2 == 0 then classes:insert("flip") end
  local out = pandoc.List()
  if photo then out:insert(photo) end
  out:insert(pandoc.Div(text, pandoc.Attr("", { "project-text" })))
  return pandoc.Div(out, pandoc.Attr(div.identifier, classes, div.attributes))
end

return {
  {
    Div = function(div)
      if div.classes:includes("project") then return project(div) end
    end,
  },
}
