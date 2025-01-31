--
-- Re-implementation of the tableofcontents package.
-- Hooks are removed and replaced by styles, allowing for a fully customizable TOC
--
SILE.scratch.tableofcontents = {}
local _tableofcontents = {}

-- Styles
local styles = SILE.require("packages/styles").exports

-- The interpretation after the ~ below are just indicative, one could
-- customize everything differently. It corresponds to their use in
-- the omibook class, and their default (proposed) styling specifications
-- are based on the latter.
local tocStyles = {
  -- level0 ~ part
  { font = { weight = 800, size = "+1.5" },
    toc = { numbering = false, pageno = false },
    paragraph = { skipbefore = "medskip", indentbefore = false,
                  skipafter = "medskip", breakafter = false } },
  -- level1 ~ chapter
  { font = { weight = 800, size = "+1" },
    toc = { numbering = false, pageno = true, dotfill = false},
    paragraph = { indentbefore = false, skipafter = "smallskip" } },
  -- level2 ~ section
  { font = { size = "+1" },
    toc = { numbering = false, pageno = true, dotfill = true },
    paragraph = { indentbefore = false, skipafter = "smallskip" } },
  -- level3 ~ subsection
  { toc = { numbering = true, pageno = true, dotfill = false },
    paragraph = { indentbefore = true, skipafter = "smallskip" } },
  -- level4 ~ subsubsection
  { toc = { pageno = false },
    paragraph = { indentbefore = true, skipafter = "smallskip" } },
  -- level5 ~ figure
  { toc = { numbering = true, pageno = true, dotfill = true },
    numbering = { before = "Fig. ", after = ".", kern = "2spc" },
    paragraph = { indentbefore = false } },
  -- level6 ~ table
  { toc = { numbering = true, pageno = true, dotfill = true },
    numbering = { before = "Table ", after = ".", kern = "2spc" },
    paragraph = { indentbefore = false } },
  -- extra loosely defined levels, so we have them at hand if need be
  { toc = { pageno = false },
    paragraph = { indentbefore = true } },
  { toc = { pageno = false },
    paragraph = { indentbefore = true } },
  { toc = { pageno = false },
    paragraph = { indentbefore = true } },
}
for i = 1, #tocStyles do
  styles.defineStyle("toc:level"..(i-1), {}, tocStyles[i])
end

local moveToc = function (_)
  local node = SILE.scratch.info.thispage.toc
  if node then
    for i = 1, #node do
      node[i].pageno = SILE.formatCounter(SILE.scratch.counters.folio)
      SILE.scratch.tableofcontents[#(SILE.scratch.tableofcontents)+1] = node[i]
    end
  end
end

local writeToc = function ()
  local tocdata = pl.pretty.write(SILE.scratch.tableofcontents)
  local tocfile, err = io.open(SILE.masterFilename .. '.toc', "w")
  if not tocfile then return SU.error(err) end
  tocfile:write("return " .. tocdata)
  tocfile:close()

  if not pl.tablex.deepcompare(SILE.scratch.tableofcontents, _tableofcontents) then
    io.stderr:write("\n! Warning: table of contents has changed, please rerun SILE to update it.")
  end
end

local loadToc = function()
  if _tableofcontents and #_tableofcontents > 0 then
    -- already loaded
    return true
  end
  local tocfile, _ = io.open(SILE.masterFilename .. '.toc')
  if not tocfile then
    -- No TOC yet
    return false
  end
  local doc = tocfile:read("*all")
  local toc = assert(load(doc))()
  _tableofcontents = toc
  return true
end

-- Warning for users of the legacy tableofcontents
SILE.registerCommand("tableofcontents:title", function (_, _)
  SU.error("The omitableofcontents package does not use the tableofcontents:title command.")
end)

SILE.registerCommand("tableofcontents", function (options, _)
  local depth = SU.cast("integer", options.depth or 3)
  local start = SU.cast("integer", options.start or 0)
  local linking = SU.boolean(options.linking, true)

  if loadToc() == false then
    SILE.call("tableofcontents:notocmessage")
    return
  end

  -- Temporarilly kill footnotes (fragile)
  local oldFt = SILE.Commands["footnote"]
  SILE.Commands["footnote"] = function () end

  local toc = _tableofcontents
  for i = 1, #toc do
    local item = toc[i]
    if item.level >= start and item.level <= start + depth then
      SILE.call("tableofcontents:item", {
        level = item.level,
        pageno = item.pageno,
        number = item.number,
        link = linking and item.link
      }, item.label)
    end
  end

  SILE.Commands["footnote"] = oldFt
end, "Output the table of contents.")

local dc = 1
SILE.registerCommand("tocentry", function (options, content)
  local dest
  if SILE.Commands["pdf:destination"] then
    dest = "dest" .. dc
    SILE.call("pdf:destination", { name = dest })
    local title = SU.contentToString(content)
    SILE.call("pdf:bookmark", { title = title, dest = dest, level = options.level })
    dc = dc + 1
  end
  SILE.call("info", {
    category = "toc",
    value = {
      label = content,
      level = (options.level or 1),
      number = options.number,
      link = dest
    }
  })
end, "Register an entry in the current TOC - low-level command.")

local linkWrapper = function (dest, func)
  if dest and SILE.Commands["pdf:link"] then
    return function()
      SILE.call("pdf:link", { dest = dest }, func)
    end
  else
    return func
  end
end

SILE.registerCommand("tableofcontents:item", function (options, content)
  local level = SU.cast("integer", SU.required(options, "level", "tableofcontents:levelitem"))
  if level < 0 or level > #tocStyles - 1 then SU.error("Invalid TOC level "..level) end

  local hasFiller = true
  local hasPageno = true
  local tocSty = styles.resolveStyle("toc:level"..level)
  if tocSty.toc then
    hasPageno = SU.boolean(tocSty.toc.pageno, true)
    hasFiller = hasPageno and SU.boolean(tocSty.toc.dotfill, true)
  end

  SILE.settings.temporarily(function ()
    SILE.settings.set("typesetter.parfillskip", SILE.nodefactory.glue())
    SILE.call("style:apply:paragraph", { name = "toc:level"..level },
      linkWrapper(options.link, function ()
        if options.number then
          SILE.call("tableofcontents:levelnumber", { level = level }, function ()
            SILE.typesetter:typeset(options.number)
          end)
        end

        SILE.process(content)

        SILE.call(hasFiller and "dotfill" or "hfill")
        if hasPageno then
          SILE.typesetter:typeset(options.pageno)
        end
      end)
    )
  end)
end, "Typeset a TOC entry - internal.")

SILE.registerCommand("tableofcontents:levelnumber", function (options, content)
  local level = SU.cast("integer", SU.required(options, "level", "tableofcontents:levelnumber"))
  if level < 0 or level > #tocStyles - 1 then SU.error("Invalid TOC level "..level) end

  local tocSty = styles.resolveStyle("toc:level"..level)

  if tocSty.toc and SU.boolean(tocSty.toc.numbering, false) then
    local pre = tocSty.numbering and tocSty.numbering.before
    local post = tocSty.numbering and tocSty.numbering.after
    local kern = tocSty.numbering and tocSty.numbering.kern or "1spc"
    if pre and pre ~= "false" then SILE.typesetter:typeset(pre) end
    SILE.process(content)
    if post and post ~= "false" then
      SILE.typesetter:typeset(post)
    end
    SILE.call("kern", { width = kern })
  end
end, "Typeset the (section) number in a TOC entry - internal.")

return {
  exports = { writeToc = writeToc, moveToc = moveToc,
    moveTocNodes = moveToc -- for compatibility
  },
  init = function (self)
    self:loadPackage("infonode")
    self:loadPackage("leaders")
    SILE.doTexlike([[%
\define[command=tableofcontents:notocmessage]{\tableofcontents:headerfont{Rerun SILE to process table of contents!}}%
]])
  end,
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]
\script[src=packages/enumitem]

The \doc:code{omitableofcontents} package is a re-implementation of the
default \doc:keyword{tableofcontents} package from SILE. As its original ancestor,
it provides tools for classes to create tables of contents.

It exports two Lua functions, \doc:code{moveToc()} and \doc:code{writeToc()}.
The former should be called at the end of each page to collate the table of
contents.
The latter should be called at the end of the document, to save the table of
contents to a file which is read when the package is initialized. This is because
a table of contents (written out with the \doc:code{\\tableofcontents} command)
is usually found at the start of a document, before the entries have been processed.
Because of this, documents with a table of contents need to be processed at least
twice—once to collect the entries and work out which pages they are on,
then to write the table of contents.
At a low-level, when you are implementing sectioning commands such
as \doc:code{\\chapter} or \doc:code{\\section}, your
class should call the \doc:code{\\tocentry[level=\doc:args{integer},
number=\doc:args{string}]\{\doc:args{section title}\}} command to register
a table of contents entry. Or you can alleviate your work by using a package
that does it all for you, such as \doc:keyword{sectioning}.

From a document author perspective, this package just provides the above-mentioned
\doc:code{\\tableofcontents} command.

It accepts a \doc:code{depth} option to control the depth of the content added to the table
(defaults to 3) and a \doc:code{start} option to control at which level the table
starts (defaults to 0)

If the \doc:code{pdf} package is loaded before using sectioning commands,
then a PDF document outline will be generated.
Moreover, entries in the table of contents will be active links to the
relevant sections. To disable the latter behavior, pass \doc:code{linking=false} to
the \doc:code{\\tableofcontents} command.

As opposed to the original implementation, this package clears the table header
and cancels the language-dependent title that the default implementation provides.
This author thinks that such a package should only do one thing well: typesetting the table
of contents, period. Any title (if one is even desired) should be left to the sole decision
of the user, e.g. explicitely defined with a \doc:code{\\chapter[numbering=false]\{…\}}
command or any other appropriate sectioning command, and with whatever additional content
one may want in between. Even if LaTeX has a default title for the table of contents,
there is no strong reason to do the same. It cannot be general: One could
want “Table of Contents”, “Contents”, “Summary”, “Topics”, etc. depending of the type of
book. It feels wrong and cumbersome to always get a default title and have to override
it, while it is so simple to just add a consistently-styled section above the table…

Moreover, this package does not support all the “hooks” that its ancestor had.
Rather, the entry level formatting logic entirely relies on styles (using the
\doc:keyword{styles} package), the styles used being
\doc:code{toc:level0} to \doc:code{toc:level9}. They provides several
specific options that the original package did not have, allowing you to customize
nearly all aspects of your tables of contents.

\end{document}]]
}
