--
-- Some common shorthands and abbreviations
-- 2021, Didier Willis
-- License: MIT
--

SILE.require("packages/styles") -- for style:superscript

SILE.registerCommand("abbr:nbsp", function (options, _)
  local fixed = SU.boolean(options.fixed, false)
  local enlargement = SILE.settings.get("shaper.spaceenlargementfactor")
  if fixed then
    local widthsp = enlargement.."spc"
    SILE.call("kern", { width = widthsp })
  else
    local stretch = SILE.settings.get("shaper.spacestretchfactor") or 0
    local shrink = SILE.settings.get("shaper.spaceshrinkfactor") or 0
    local widthsp = enlargement.."spc plus "..stretch.."spc minus "..shrink.."spc"
    SILE.call("kern", { width = widthsp })
  end
end, "Inserts a non-breakable space (by default shrinkable and stretchable, unless fixed=true)")

SILE.registerCommand("abbr:no:fr", function (_, content)
  SILE.typesetter:typeset("n")
  SILE.call("style:superscript", {}, { "o" })
  SILE.call("abbr:nbsp")
  SILE.process(content)
end, "Formats an French number as, in n° 5 (but properly typeset)")

SILE.registerCommand("abbr:no:en", function (_, content)
  SILE.typesetter:typeset("no.")
  SILE.call("abbr:nbsp")
  SILE.process(content)
end, "Formats an English number, as in no. 5")


SILE.registerCommand("abbr:no", function (_, content)
  local lang = SILE.settings.get("document.language")
  if SILE.Commands["abbr:no:"..lang] then
    SILE.call("abbr:no:"..lang)
  else
    SU.warn("Language not supported for abbr:no, fallback to English")
    SILE.call("abbr:no:en")
  end
end, "Formats an number, as in no. 5, but depending on language")

SILE.registerCommand("abbr:vol", function (_, content)
  SILE.typesetter:typeset("vol.")
  SILE.call("abbr:nbsp")
  SILE.process(content)
end, "Formats a volume reference, as in vol. 3")

SILE.registerCommand("abbr:page", function (options, content)
  SILE.typesetter:typeset("p.")
  SILE.call("abbr:nbsp", {}, {})
  SILE.process(content)
  if SU.boolean(options.sq) then
    -- Latin sequiturque ("and next page")
    SILE.call("font", { style = "italic", language = "und" }, function ()
      SILE.typesetter:typeset(" sq.")
    end)
  elseif SU.boolean(options.sqq) then
     -- Latin sequiturque, plural ("and following pages")
    SILE.call("font", { style = "italic", language = "und" }, function ()
      SILE.typesetter:typeset(" sqq.")
    end)
  elseif SU.boolean(options.suiv) then
    -- French ("et suivant") for those finding the latin sequiturque pedantic
    -- as Lacroux in his Orthotypographie book..
     SILE.typesetter:typeset(" et suiv.")
  end
end, "Formats a page reference, as in p. 153, possibly followed by an option-dependent flag for subsequent pages")

SILE.registerCommand("abbr:siecle", function (_, content)
  local century = (type(content[1]) == "string") and content[1]
    or SU.error("Expected a string for abbr:siecle")
  -- experimental because here we expect the user to input a lowercase roman
  -- number. But shouldn't we detect the input (uppercase roman, bare number, etc.)
  -- and fix it appropriately, e.g. \abbr:siecle{iv}, \abbr:siecle{IV} or
  -- \abbr:siecle{4} would have the same output?
  SILE.call("font", { features = "+smcp" }, function ()
    SILE.typesetter:typeset(century)
  end)
  if century == "i" then
    SILE.call("style:superscript", {}, { "er" })
  else
    SILE.call("style:superscript", {}, { "e" })
  end
end, "Formats an French century (siècle) as in IVe (but properly typeset) - experimental")

return {
  documentation = [[\begin{document}
    \script[src=packages/abbr]
    This package defines a few shorthands and abbreviations that its author often
    uses in articles or book chapters.

    The \code{\\abbr:nbsp} command inserts a non-breakable inter-word space.
    It is stretchable and shrinkable as a normal inter-word space by default,
    unless setting the \code{fixed} option to true.

    The \code{\\abbr:no:fr} and \code{\\abbr:no:en} commands prepend a
    correctly typeset issue number, for French and English respectively,
    that is \abbr:no:fr{5} and \abbr:no:en{5}.

    The \code{\\abbr:vol} acts similarly for volume references, that
    is \abbr:vol{4}, just ensuring the space in between is unbreakable.

    The \code{\\abbr:page} does the same for page references, as in
    \abbr:page{159}, but also supports one of the following boolean
    options: \code{sq}, \code{sqq} and \code{suiv}, to indicate
    subsequent page(s) in the usual manner in English or French, as
    in \abbr:page[sq=true]{159}, \abbr:page[sqq=true]{159} or
    \abbr:page[suiv=true]{159}
    Note that in these cases, a period is automatically added.

    The \code{\\abbr:siecle} command formats a century according to
    the French typographical rules, as in \abbr:siecle{i} or
    \abbr:siecle{iv}.
  \end{document}]]
}