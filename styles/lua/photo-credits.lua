-- Adds the photo credit (from photo_credits.csv) to every image on the site.
local photos = dofile(quarto.utils.resolve_path("photos.lua"))

-- Pass 1: a photo on its own line becomes a "figure" with a visible caption.
-- On this site the description is alt text, not a caption, so unwrap it.
local function only_image(content)
  local imgs = {}
  pandoc.Div(content):walk({ Image = function(i) imgs[#imgs + 1] = i end })
  if #imgs == 1 then return pandoc.Plain({ imgs[1] }) end
end

-- Pass 2: add the credit. The first photo on a page (the hero) loads right away.
local count = 0

return {
  {
    FloatRefTarget = function(f) return only_image(f.content) end,
    Figure = function(f) return only_image(f.content) end,
  },
  {
    Image = function(img)
      count = count + 1
      img.identifier = img.identifier:match("^fig%-") and "" or img.identifier
      img.classes = img.classes:filter(function(c) return c ~= "figure-img" and c ~= "img-fluid" end)
      return photos.wrap(img, count == 1 and "eager" or nil)
    end,
  },
}
