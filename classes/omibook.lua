--
-- A new book class for SILE
-- 2021, Didier Willis
-- License: MIT
--
local plain = SILE.require("plain", "classes")
local omibook = plain { id = "omibook" }

local styles = SILE.require("packages/styles").exports
SILE.require("packages/sectioning")

-- STYLES

-- Sectioning styles
styles.defineStyle("sectioning:base", {}, {
  paragraph = { indentbefore = false, indentafter = false }
})
styles.defineStyle("sectioning:part", { inherit = "sectioning:base" }, {
  font = { weight = 800, size = "+6" },
  paragraph = { skipbefore = "15%fh", align = "center", skipafter = "bigskip" },
  sectioning = { counter = "parts", level = 1, display = "ROMAN",
                 toclevel = 0,
                 open = "odd", numberstyle="sectioning:part:number",
                 hook = "sectioning:part:hook" },
})
styles.defineStyle("sectioning:chapter", { inherit = "sectioning:base" }, {
  font = { weight = 800, size = "+4" },
  paragraph = { skipafter = "bigskip", align = "left" },
  sectioning = { counter = "sections", level = 1, display = "arabic",
                 toclevel = 1,
                 open = "odd", numberstyle="sectioning:chapter:number",
                 hook = "sectioning:chapter:hook" },
})
styles.defineStyle("sectioning:section", { inherit = "sectioning:base" }, {
  font = { weight = 800, size = "+2" },
  paragraph = { skipbefore = "bigskip", skipafter = "medskip", breakafter = false },
  sectioning = { counter = "sections", level = 2, display = "arabic",
                 toclevel = 2,
                 numberstyle="sectioning:other:number",
                 hook = "sectioning:section:hook" },
})
styles.defineStyle("sectioning:subsection", { inherit = "sectioning:base"}, {
  font = { weight = 800, size = "+1" },
  paragraph = { skipbefore = "medskip", skipafter = "smallskip", breakafter = false },
  sectioning = { counter = "sections", level = 3, display = "arabic",
                 toclevel = 3,
                 numberstyle="sectioning:other:number" },
})
styles.defineStyle("sectioning:subsubsection", { inherit = "sectioning:base" }, {
  font = { weight = 800 },
  paragraph = { skipbefore = "smallskip", skipbefore = "smallskip"; breakafter = false },
  sectioning = { counter = "sections", level = 4, display = "arabic",
                 toclevel = 4,
                 numberstyle="sectioning:other:number" },
})

styles.defineStyle("sectioning:part:number", {}, {
  font = { features = "+smcp" },
  numbering = { before = "Part ", standalone = true },
})
styles.defineStyle("sectioning:chapter:number", {}, {
  font = { size = "-1" },
  numbering = { before = "Chapter ", after = ".", standalone = true },
})
styles.defineStyle("sectioning:other:number", {}, {
  numbering = { after = "." }
})

-- folio styles
styles.defineStyle("folio:base", {}, {
  font = { size = "-0.5" }
})
styles.defineStyle("folio:even", { inherit = "folio:base" }, {
})
styles.defineStyle("folio:odd", { inherit = "folio:base" }, {
  paragraph = { align = "right" }
})

-- header styles
styles.defineStyle("header:base", {}, {
  font = { size = "-1" },
  paragraph = { indentbefore = false, indentafter = false }
})
styles.defineStyle("header:even", { inherit = "header:base" }, {
})
styles.defineStyle("header:odd", { inherit = "header:base" }, {
  font = { style = "italic" },
  paragraph = { align = "right" }
})

-- Additional styles are defined further below for specific commands
-- i.e. convenience commands provided by the class, but which are not (necessarily)
-- book-related, such as blockquotes, figures, tables.

-- PAGE MASTERS

omibook.defaultFrameset = {
  content = {
    left = "10%pw", -- was 8.3%pw
    right = "87.7%pw", -- was 86%pw
    top = "11.6%ph",
    bottom = "top(footnotes)"
  },
  folio = {
    left = "left(content)",
    right = "right(content)",
    top = "bottom(footnotes)+3%ph",
    bottom = "bottom(footnotes)+5%ph"
  },
  header = {
    left = "left(content)",
    right = "right(content)",
    top = "top(content)-5%ph", -- was -8%ph
    bottom = "top(content)-2%ph" -- was -3%ph
  },
  footnotes = {
    left = "left(content)",
    right = "right(content)",
    height = "0",
    bottom = "86.3%ph" -- was 83.3%ph
  }
}

-- CLASS DEFINITION

function omibook:init ()
  self:loadPackage("masters")
  self:defineMaster({
      id = "right",
      firstContentFrame = self.firstContentFrame,
      frames = self.defaultFrameset
    })
  self:loadPackage("twoside", { oddPageMaster = "right", evenPageMaster = "left" })
  self:mirrorMaster("right", "left")
  self:loadPackage("omitableofcontents")
  if not SILE.scratch.headers then SILE.scratch.headers = {} end
  self:loadPackage("omifootnotes", {
    insertInto = "footnotes",
    stealFrom = { "content" }
  })

  self:loadPackage("omirefs")
  self:loadPackage("omiheaders")

  -- override the standard foliostyle to rely on styles
  self:loadPackage("folio")
  SILE.registerCommand("foliostyle", function (_, content)
    SILE.call("noindent")
    if SILE.documentState.documentClass:oddPage() then
      SILE.call("style:apply:paragraph", { name = "folio:odd"}, content)
    else
      SILE.call("style:apply:paragraph", { name = "folio:even"}, content)
    end
  end)

  -- override document.parindent default
  SILE.settings.set("document.parindent", "1.25em")

  return plain.init(self)
end

omibook.newPage = function (self)
  self:switchPage()
  self:newPageInfo()
  return plain.newPage(self)
end

omibook.finish = function (self)
  local ret = plain.finish(self)
  self:writeToc()
  self:writeRefs()
  return ret
end

omibook.endPage = function (self)
  self:moveToc()
  self:moveRefs()
  local headerContent = (self:oddPage() and SILE.scratch.headers.odd)
        or (not(self:oddPage()) and SILE.scratch.headers.even)
  if headerContent then
    self:outputHeader(headerContent)
  end
  return plain.endPage(self)
end

omibook.registerCommands = function (_)
  plain.registerCommands()
end

-- COMMANDS

-- Running headers

SILE.registerCommand("even-running-header", function (_, content)
  local closure = SILE.settings.wrap()
  SILE.scratch.headers.even = function ()
    closure(function ()
      SILE.call("style:apply:paragraph", { name = "header:even" }, content)
    end)
  end
end, "Text to appear on the top of the even page(s).")

SILE.registerCommand("odd-running-header", function (_, content)
  local closure = SILE.settings.wrap()
  SILE.scratch.headers.odd = function ()
    closure(function ()
      SILE.call("style:apply:paragraph", { name = "header:odd" }, content)
    end)
  end
end, "Text to appear on the top of the odd page(s).")

-- Sectionning hooks and commands

SILE.registerCommand("sectioning:part:hook", function (options, content)
  -- Parts cancel headers and folios
  SILE.call("noheaderthispage")
  SILE.call("nofoliosthispage")
  SILE.scratch.headers.odd = nil
  SILE.scratch.headers.even = nil

  -- Parts reset footnotes and chapters
  SILE.call("set-counter", { id = "footnote", value = 1 })
  SILE.call("set-multilevel-counter", { id = "sections", level = 1, value = 0 })
end, "Apply part hooks (counter resets, footers and headers, etc.)")

SILE.registerCommand("sectioning:chapter:hook", function (options, content)
  -- Chapters re-enable folios, have no header, and reset the footnote counter.
  SILE.call("noheaderthispage")
  SILE.call("folios")
  SILE.call("set-counter", { id = "footnote", value = 1 })

  -- Chapters, here, go in the even header.
  SILE.call("even-running-header", {}, content)
end, "Apply chapter hooks (counter resets, footers and headers, etc.)")

SILE.registerCommand("sectioning:section:hook", function (options, content)
  -- Sections, here, go in the odd header.
  SILE.call("odd-running-header", {}, function ()
    if SU.boolean(options.numbering, true) then
      SILE.call("show-multilevel-counter", {
        id = options.counter,
        level = options.level,
        noleadingzero = true
      })
      SILE.typesetter:typeset(" ")
    end
    SILE.process(content)
  end)
end, "Applies section hooks (footers and headers, etc.)")

SILE.registerCommand("part", function (options, content)
  options.style = "sectioning:part"
  SILE.call("sectioning", options, content)
end, "Begin a new part.")

SILE.registerCommand("chapter", function (options, content)
  options.style = "sectioning:chapter"
  SILE.call("sectioning", options, content)
end, "Begin a new chapter.")

SILE.registerCommand("section", function (options, content)
  options.style = "sectioning:section"
  SILE.call("sectioning", options, content)
end, "Begin a new section.")

SILE.registerCommand("subsection", function (options, content)
  options.style = "sectioning:subsection"
  SILE.call("sectioning", options, content)
end, "Begin a new subsection.")

SILE.registerCommand("subsubsection", function (options, content)
  options.style = "sectioning:subsubsection"
  SILE.call("sectioning", options, content)
end, "Begin a new subsubsection.")

-- Quotes

SILE.settings.declare({
  parameter = "book.blockquote.margin",
  type = "measurement",
  default = SILE.measurement("2em"),
  help = "Left margin (indentation) for enumerations"
})

SILE.registerCommand("blockindent", function (options, content)
  SILE.settings.temporarily(function ()
    local indent = SILE.settings.get("book.blockquote.margin"):absolute()
    local lskip = SILE.settings.get("document.lskip") or SILE.nodefactory.glue()
    local rskip = SILE.settings.get("document.rskip") or SILE.nodefactory.glue()
    SILE.settings.set("document.lskip", SILE.nodefactory.glue(lskip.width + indent))
    SILE.settings.set("document.rskip", SILE.nodefactory.glue(rskip.width + indent))
    SILE.process(content)
    SILE.call("par")
  end)
end, "Typeset its contents in a right and left indented block.")

SILE.scratch.styles.alignments["block"] = "blockindent"

styles.defineStyle("blockquote", {}, {
  font = { size = "-0.5" },
  paragraph = { skipbefore = "smallskip", skipafter = "smallskip",
                align = "block" }
})

SILE.registerCommand("blockquote", function (options, content)
  SILE.call("style:apply:paragraph", { name = "blockquote" }, content)
end, "Typeset its contents in a styled blockquote.")

-- Captioned elements
-- N.B. Despite the similar naming to LaTeX, these are not "floats"

local extractFromTree = function (tree, command)
  for i=1, #tree do
    if type(tree[i]) == "table" and tree[i].command == command then
      return table.remove(tree, i)
    end
  end
end

styles.defineStyle("figure", {}, {
  paragraph = { skipbefore = "smallskip",
                align = "center", breakafter = false },
})
styles.defineStyle("figure:caption", { inherit = "sectioning:base" }, {
  font = { style = "italic", size = "-0.5" },
  paragraph = { indentbefore = false, skipbefore = "medskip", breakbefore = false,
                align = "center",
                skipafter = "medskip" },
  sectioning = { counter = "figures", level = 1, display = "arabic",
                 toclevel = 5,
                 goodbreak = false, numberstyle="figure:caption:number" },
})
styles.defineStyle("figure:caption:number", {}, {
  numbering = { before = "Figure ", after = "." },
})
styles.defineStyle("table", {}, {
  paragraph = { align = "center", breakafter = false },
})
styles.defineStyle("table:caption", {}, {
  font = { size = "-0.5" },
  paragraph = { indentbefore = false, breakbefore = false,
                align = "center",
                skipafter = "medskip" },
  sectioning = { counter = "table", level = 1, display = "arabic",
                 toclevel = 6,
                 goodbreak = false, numberstyle="table:caption:number" },
})
styles.defineStyle("table:caption:number", {}, {
  numbering = { before = "Table ", after = "." },
  font = { features = "+smcp" },
})

SILE.registerCommand("figure", function (options, content)
  if type(content) ~= "table" then SU.error("Expected a table content in figure environment") end
  local caption = extractFromTree(content, "caption")

  options.style = "figure:caption"
  SILE.call("style:apply:paragraph", { name = "figure" }, content)
  if caption then
    SILE.call("sectioning", options, caption)
  else
    -- It's bad to use the figure environment without caption, it's here for that.
    -- So I am not even going to use styles here.
    SILE.call("smallskip")
  end
end, "Insert a captioned figure.")

SILE.registerCommand("table", function (options, content)
  if type(content) ~= "table" then SU.error("Expected a table content in table environment") end
  local caption = extractFromTree(content, "caption")

  options.style = "table:caption"
  SILE.call("style:apply:paragraph", { name = "table" }, content)
  if caption then
    SILE.call("sectioning", options, caption)
  else
    -- It's bad to use the table environment without caption, it's here for that.
    -- So I am not even going to use styles here.
    SILE.call("smallskip")
  end
end, "Insert a captioned table.")

SILE.registerCommand("listoffigures", function (_, content)
  local figSty = styles.resolveStyle("figure:caption")
  local start = figSty.sectioning and figSty.sectioning.toclevel
    or SU.error("Figure style does not specify a TOC level sectioning")

  SILE.call("tableofcontents", { start = start, depth = 0 })
end, "Output the list of figures.")

SILE.registerCommand("listoftables", function (_, content)
  local figSty = styles.resolveStyle("table:caption")
  local start = figSty.sectioning and figSty.sectioning.toclevel
    or SU.error("Figure style does not specify a TOC level sectioning")

  SILE.call("tableofcontents", { start = start, depth = 0 })
end, "Output the list of tables.")

return omibook
