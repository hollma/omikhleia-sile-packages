--
-- A minimalist SILE class for a "resumé" (CV)
-- 2021, Didier Willis
-- License: MIT
--
-- This is indeed very minimalist :)
--
local plain = SILE.require("plain", "classes")
local omicv = plain { id = "omicv" }

-- Load all the support package we need so that the user
-- can directly work on their content. N.B. Other packages
-- that require class support are also loaded in the
-- class initialization method below.
local styles = SILE.require("packages/styles").exports
SILE.require("packages/rules") -- for section rules
SILE.require("packages/image") -- for the user picture
SILE.require("packages/ptable") -- for tables, all the CV is one
SILE.require("packages/enumitem") -- for bullet lists
SILE.require("packages/textsubsuper") -- for ranks, etc.

SILE.scratch.omicv = {}

-- PAGE MASTERS AND FRAMES

-- 1. We want two page masters:
--    one for the first page, slightly higher as it doesn't need a header
--    one for subsequent pages, which will have a header repeating the user name.
-- 2. The spacing at top and bottom should be close to that on sides, so
--    vertical dimensions are based on the same pw specification.
-- 3. The footer and folio are place side-by-side to gain a bit of space.
--
omicv.defaultFrameset = {
  content = {
    left = "10%pw",
    right = "90%pw",
    top = "10%pw",
    bottom = "bottom(page)-22%pw"
  },
  folio = {
    left = "right(footer)",
    right = "right(content)",
    top = "bottom(content)+3%ph",
    bottom = "bottom(page)-10%pw"
  },
  header = { -- We don't need it, but let's define it somewhere harmless
             -- just in case.
    left = "left(content)",
    right = "right(content)",
    top = "top(content)-5%ph",
    bottom = "top(content)-2%ph"
  },
  footer = {
    left = "left(content)",
    right = "right(content)-10%pw",
    top = "bottom(content)+3%ph",
    bottom = "bottom(page)-10%pw"
  },
}

omicv.nextFrameset = {
  content = {
    left = "10%pw",
    right = "90%pw",
    top = "bottom(header)",
    bottom = "bottom(page)-22%pw"
  },
  folio = {
    left = "right(footer)",
    right = "right(content)",
    top = "bottom(content)+3%ph",
    bottom = "bottom(page)-10%pw"
  },
  header = {
    left = "left(content)",
    right = "right(content)",
    top = "10%pw",
    bottom = "10%pw + 3%ph"
  },
  footer = {
    left = "left(content)",
    right = "right(content)-10%pw",
    top = "bottom(content)+3%ph",
    bottom = "bottom(page) - 10%pw"
  },
}

local firstPage = true

function omicv:init ()
  self:loadPackage("masters")
  self:defineMaster({
      id = "first",
      firstContentFrame = self.firstContentFrame,
      frames = self.defaultFrameset
    })
  self:defineMaster({
      id = "next",
      firstContentFrame = self.firstContentFrame,
      frames = self.nextFrameset
    })
  if not SILE.scratch.headers then SILE.scratch.headers = {} end
  self:loadPackage("omirefs") -- cross-reference, used to get the n/N page numbering
  self:loadPackage("omiheaders") -- header facility

  -- override foliostyle
  self:loadPackage("folio")
  SILE.registerCommand("foliostyle", function (_, content)
    SILE.call("hbox", {}, {}) -- for vfill to be effective
    SILE.call("vfill")
    SILE.call("rightalign", {}, function()
        SILE.process(content)
        SILE.typesetter:typeset("/")
        SILE.call("pageref", { marker = "omicv:end" })
      end)
      SILE.call("eject") -- for vfill to be effective
  end)

  -- override default document.parindent, we do not want it.
  SILE.settings.set("document.parindent", SILE.nodefactory.glue())

  return plain.init(self)
end

omicv.newPage = function (self)
  self:newPageInfo()
  if SILE.scratch.counters.folio.value > 1 then
    self.switchMaster("next")
  end
  return plain.newPage(self)
end

omicv.finish = function (self)
  local ret = plain.finish(self)
  self:writeRefs()
  return ret
end

omicv.endPage = function (self)
  self:moveRefs()
  if SILE.scratch.counters.folio.value > 1 then
    self:outputHeader(SILE.scratch.headers.content)
  end
  SILE.typesetNaturally(SILE.getFrame("footer"), function ()
    SILE.settings.pushState()
    SILE.settings.toplevelState()
    SILE.settings.set("document.parindent", SILE.nodefactory.glue())
    SILE.settings.set("current.parindent", SILE.nodefactory.glue())
    SILE.settings.set("document.lskip", SILE.nodefactory.glue())
    SILE.settings.set("document.rskip", SILE.nodefactory.glue())

    SILE.call("hbox", {}, {}) -- for vfill to be applied
    SILE.call("vfill")
    SILE.process(SILE.scratch.omicv.address)
    SILE.call("eject") -- for vfill to be effective
    SILE.settings.popState()
  end)
  return plain.endPage(self)
end

SILE.registerCommand("cv-header", function (_, content)
  local closure = SILE.settings.wrap()
  SILE.scratch.headers.content = function () closure(content) end
end, "Text to appear at the top of the page")

SILE.registerCommand("cv-footer", function (_, content)
  local closure = SILE.settings.wrap()
  SILE.scratch.omicv.address = function () closure(content) end
end, "Text to appear at the bottom of the page")

-- STYLES

styles.defineStyle("cv:firstname", {}, { font = { style = "light" }, color = { color = "#a6a6a6" } })
styles.defineStyle("cv:lastname", {}, { color = { color = "#737373" } })

styles.defineStyle("cv:fullname", {}, { font = { size = "30pt" }, paragraph = { align = "right" } })

styles.defineStyle("cv:color", {}, { color = { color = "#4080bf" } }) -- a nice tint of blue

styles.defineStyle("cv:dingbats", { inherit = "cv:color" }, { font = { family = "Symbola", size = "-1" } })

styles.defineStyle("cv:jobrole", {}, { font = { weight = 600 } })

styles.defineStyle("cv:headline", {}, { font = { weight = "300", style = "italic", size = "-1" },
  color = { color = "#373737" },
  paragraph = { align = "center" } })

styles.defineStyle("cv:section", { inherit = "cv:color" }, { font = { size = "+2" } })

styles.defineStyle("cv:topic", {}, { font = { style="light", size = "-1" },
  paragraph = { align = "right" } })
styles.defineStyle("cv:description", {}, {})

styles.defineStyle("cv:contact", {}, { font = { style = "thin", size = "-0.5" },
  paragraph = { align = "center" } })

styles.defineStyle("cv:jobtitle", {}, { font = { size = "20pt" },
  color = { color = "#373737" }, paragraph = { align = "center", skipbefore = "0.5cm" } })

styles.defineStyle("cv:header", {}, { font = { size = "20pt" },
  paragraph = { align = "right" } })

-- Redefine the 6 default itemize style to apply our cv:color
for i = 1, 6 do
  local itemizeSty = styles.resolveStyle("list:itemize:"..i)
  styles.defineStyle("list:itemize:"..i, { inherit = "cv:color" }, itemizeSty)
end
-- Same for the alternate variant
for i = 1, 6 do
  local itemizeSty = styles.resolveStyle("list:itemize-alternate:"..i)
  styles.defineStyle("list:itemize-alternate:"..i, { inherit = "cv:color" }, itemizeSty)
end

-- RESUME PROCESSING

local extractFromTree = function (tree, command)
  for i=1, #tree do
    if type(tree[i]) == "table" and tree[i].command == command then
      return table.remove(tree, i)
    end
  end
end

-- Hacky-whacky way to create a ptable tree programmatically
-- loosely inspired by what inputfilter.createCommand() does.
local function C(command, options, content)
  local result = content
  result.options = options
  result.command = command
  result.id = "command"
  return result
end

local doEntry = function (rows, _, content)
  local topic = extractFromTree(content, "topic")
  local description = extractFromTree(content, "description")
  local titleRow = C("row", { }, {
    C("cell", { valign = "top", padding = "4pt 4pt 0 4pt" }, { function ()
        SILE.call("style:apply:paragraph", { name = "cv:topic" }, function ()
          -- We are typesetting in a different style but want proper alignment
          -- With the other style, so strut tweaking:
          SILE.call("style:apply", { name = "cv:description" }, function ()
            SILE.call("strut")
          end)
          -- The go ahead.
          SILE.process(topic)
        end)
      end
    }),
    C("cell", { valign = "top", span = 2, padding = "4pt 4pt 0.33cm 0" }, { function ()
        SILE.call("style:apply", { name = "cv:description" }, description)
      end
    })
  })
  for i = 0, #content do
    if type(content[i]) == "table" and content[i].command == "entry" then
      doEntry(rows, content[i].options, content[i])
    end
  end
  table.insert(rows, titleRow)
end

local doSection = function (rows, _, content)
  local title = extractFromTree(content, "title")
  local titleRow = C("row", { }, {
    C("cell", { valign = "bottom", padding = "4pt 4pt 0 4pt" }, { function ()
        SILE.call("style:apply", { name = "cv:section" }, function ()
          SILE.call("hrule", { width = "100%fw", height= "1ex" })
        end)
      end
    }),
    C("cell", { span = 2, padding = "4pt 4pt 0.33cm 0" }, { function ()
        SILE.call("style:apply", { name = "cv:section" }, title)
      end
    })
  })
  table.insert(rows, titleRow)
  for i = 0, #content do
    if type(content[i]) == "table" and content[i].command == "entry" then
      doEntry(rows, content[i].options, content[i])
    end
  end
end

SILE.registerCommand("resume", function (options, content)
  local firstname = extractFromTree(content, "firstname") or SU.error("firstname is mandatory")
  local lastname = extractFromTree(content, "lastname") or SU.error("lastname is mandatory")
  local picture = extractFromTree(content, "picture") or SU.error("picture is mandatory")
  local contact = extractFromTree(content, "contact") or SU.error("contact is mandatory")
  local jobtitle = extractFromTree(content, "jobtitle") or SU.error("jobtitle is mandatory")
  local headline = extractFromTree(content, "headline") -- can be omitted

  SILE.call("cv-footer", {}, function()
    SILE.process({ contact })
  end)
  SILE.call("cv-header", {}, function ()
    SILE.call("style:apply:paragraph", { name = "cv:header" }, function ()
        SILE.call("style:apply", { name = "cv:firstname" }, firstname)
        SILE.typesetter:typeset(" ")
        SILE.call("style:apply", { name = "cv:lastname" }, lastname)
      end)
  end)

  local rows = {}

  local fullnameAndPictureRow = C("row", {}, {
    C("cell", { border = "0 1pt 0 0", padding = "4pt 4pt 0 4pt", valign = "bottom" }, { function ()
        local w = SILE.measurement("100%fw"):absolute() - 7.2 -- padding and border
        SILE.call("parbox", { width = w, border = "0.6pt", padding = "3pt" }, function ()
          SILE.call("img", { width = "100%fw", src = picture.options.src })
        end)
      end
    }),
    C("cell", { span = 2, border = "0 1pt 0 0", padding = "4pt 2pt 4pt 0",  valign = "bottom" }, { function ()
      SILE.call("style:apply:paragraph", { name = "cv:fullname" }, function ()
          SILE.call("style:apply", { name = "cv:firstname" }, firstname)
          SILE.typesetter:typeset(" ")
          SILE.call("style:apply", { name = "cv:lastname" }, lastname)
        end)
      end
    })
  })
  table.insert(rows, fullnameAndPictureRow)

  local jobtitleRow = C("row", { }, {
    C("cell", { span = 3 }, { function ()
        SILE.call("style:apply:paragraph", { name = "cv:jobtitle" }, jobtitle)
      end
    })
  })
  table.insert(rows, jobtitleRow)

  -- NOTE: if headline is absent, no problem. We still insert a row, just for
  -- vertical spacing.
  local headlineRow = C("row", { }, {
    C("cell", { span = 3 }, { function ()
        SILE.call("center", {}, function ()
          SILE.call("parbox", { width = "80%fw" }, function()
            SILE.call("style:apply:paragraph", { name = "cv:headline" }, headline)
          end)
        end)
      end
    })
  })
  table.insert(rows, headlineRow)

  for i = 0, #content do
    if type(content[i]) == "table" and content[i].command == "section" then
      doSection(rows, content[i].options, content[i])
    end
    -- We should error/warn upon other commands or non-space text content.
  end

  -- NOTE: All the above was made with 4 columns in mind, I ended up using only
  -- three, with appropriate spanning. I had a more complex layout in mind. To refactor or extend...
  SILE.call("ptable", { cols = "17%fw 43%fw 40%fw", cellborder = 0, cellpadding = "4pt 4pt 4pt 4pt" },
    rows
  )

  -- An overkill? To get the number of pages, we insert a cross-reference label
  -- at the end of the resume table. Might not even be right if the user
  -- adds free text after it. Oh well, it will do for now.
  SILE.call("label", { marker = "omicv:end" })
  SILE.call("hbox", {}, {}) -- For some reason if the label is the last thing on the page,
                            -- the info node is not there.
end)

local charFromUnicode = function (str)
  local hex = (str:match("[Uu]%+(%x+)") or str:match("0[xX](%x+)"))
  if hex then
    return luautf8.char(tonumber("0x"..hex))
  end
  return "*"
end

SILE.registerCommand("ranking", function (options, content)
  local value = SU.cast("integer", options.value or 0)
  local scale = SU.cast("integer", options.scale or 5)
  SILE.call("style:apply", { name = "cv:dingbats" }, function ()
    for i = 1, value do
      SILE.typesetter:typeset(charFromUnicode("U+25CF"))
      SILE.call("kern", { width = "0.1em" })
    end
    for i = value + 1, scale do
      SILE.typesetter:typeset(charFromUnicode("U+25CB"))
      SILE.call("kern", { width = "0.1em" })
    end
  end)
end)

SILE.registerCommand("cv-bullet", function (_, _)
  SILE.call("kern", { width = "0.75em" })
  SILE.call("style:apply", { name = "cv:dingbats" }, { charFromUnicode("U+2022") })
  SILE.call("kern", { width = "0.75em" })
end)

SILE.registerCommand("cv-dingbat", function (options, _)
  local symb = SU.required(options, "symbol", "cv-dingbat")
  SILE.call("style:apply", { name = "cv:dingbats" }, { charFromUnicode(symb) })
end)


SILE.registerCommand("contact", function (_, content)
  local street = SILE.findInTree(content, "street") or SU.error("street is mandatory")
  local city = SILE.findInTree(content, "city") or SU.error("city is mandatory")
  local phone = SILE.findInTree(content, "phone") or SU.error("phone is mandatory")
  local email = SILE.findInTree(content, "email") or SU.error("email is mandatory")

  SILE.call("style:apply:paragraph", { name = "cv:contact" }, function ()
    SILE.call("cv-icon-text", { symbol="U+1F4CD" }, street)
    SILE.call("cv-bullet")
    SILE.process(city)
    SILE.call("par")
    SILE.process({ phone })
    SILE.call("cv-bullet")
    SILE.process({ email })
  end)
end)

SILE.registerCommand("cv-icon-text", function (options, content)
  SILE.call("cv-dingbat", options)
  SILE.call("kern", { width = "1.5spc" })
  SILE.process(content)
end)

SILE.registerCommand("email", function (options, content)
  local symbol = options.symbol or "U+1F4E7"
  SILE.call("cv-icon-text", { symbol = symbol }, content)
end)
SILE.registerCommand("phone", function (options, content)
  local symbol = options.symbol or "U+2706"
  SILE.call("cv-icon-text", { symbol = symbol }, content)
end)

SILE.registerCommand("jobrole", function (_, content)
  SILE.call("style:apply", { name = "cv:jobrole" }, content)
end)

return omicv
