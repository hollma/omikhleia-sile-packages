--
-- A (XML) TEI dictionary package for SILE
-- 2021, The Sindarin Dictionary Project, Omikhleia, Didier Willis
-- License: MIT
--
-- This package supports a subset of the TEI "Print Dictionary" standard,
-- as suitable for the HSD project, and assumes a similar structure to the
-- latter, see https://omikhleia.github.io/sindict/manual/DATA_MODEL.html
--
-- Loaded packages: styles, inputfilter, teiabbr, xmltricks
-- Required packages: pdf, color, infonodes, raiselower, rules, url, svg
-- Required class support: teibook
--

-- SETTINGS

SILE.require("packages/xmltricks")

local teiabbr = SILE.require("packages/teiabbr").exports

SILE.settings.declare({
  -- The source dictionary may contain notes etc. in several languages, we do not
  -- want them all. On the other hand, it may contain several sense information
  -- in several language too, but this setting does apply to them.
  parameter = "teidict.mainLanguage",
  type = "string or nil",
  default = nil,
  help = "Main definition language (to filter out some notes etc.)"
})

SILE.settings.declare({
  -- So for sense information, for now, use them all (if setting is nil)
  -- or use only the specified one.
  -- FIXME works for bilingual dictionaries, but not general...
  parameter = "teidict.transLanguage",
  type = "string or nil",
  default = nil,
  help = "Sense language (to filter out some sense information etc.)"
})

-- STYLES

local styles = SILE.require("packages/styles").exports
styles.defineStyle("tei:orth:base", {}, { font = { family = "Libertinus Sans" } })
styles.defineStyle("tei:milestone", {}, { font = { family= "Gingerbread Initials", size = 30 } })
styles.defineStyle("tei:orth", { inherit = "tei:orth:base"}, { font = { weight = 700 } })
styles.defineStyle("tei:bibl", {}, { font = { language = "und", size = -2 } })
styles.defineStyle("tei:note", {}, { font = { size = -1.5 } })
styles.defineStyle("tei:mentioned", {}, { font = { style = "italic" } })
styles.defineStyle("tei:pos", {}, { font = { style = "italic", size = -1 } })
styles.defineStyle("tei:hint", {}, { font = { style = "italic" } })
styles.defineStyle("tei:entry:main", {}, {})
styles.defineStyle("tei:entry:xref", { inherit = "tei:entry:main" }, { color = { color = "dimgray" } })
styles.defineStyle("tei:entry:numbering", { inherit = "tei:orth:base" }, { font = { size = -2 } })
styles.defineStyle("tei:sense:numbering", {}, { font = { weight = 700 } })
styles.defineStyle("tei:corr", {}, { color = { color = "dimgray" } })
styles.defineStyle("tei:header:legalese", {}, { font = { size = -1 } })
styles.defineStyle("tei:q", {}, { font = { style = "italic" } })

-- UTILITIES

local italicCorr = function (stylename)
  local spec = SILE.scratch.styles.specs[stylename]
  if spec == nil then SU.error("Unknown style "..stylename) end
  if spec.style and spec.style.font and spec.style.font.style == "italic" then
    SILE.call("kern", { width = "0.1em" }) -- Hand-made italic correction
  end
end

local trimLeft = function (str)
  return (str:gsub("^%s*", ""))
end
local trimRight = function (str)
  return (str:gsub("%s*$", ""))
end
local trim = function (str)
  return trimRight(trimLeft(str))
end

-- UTILITIES APPLYTHING TO THE AST

local trimContent = function (content)
  -- Remove leading and trailing spaces
  if #content == 0 then return end
  if type(content[1]) == "string" then
    content[1] = trimLeft(content[1])
  end
  if type(content[#content]) == "string" then
    content[#content] = trimRight(content[#content])
  end
  return content
end

local countElements = function (content)
  local count = 0
  for i = 1, #content do
    if type(content[i]) == "table" then
      count = count + 1
    end
  end
  return count
end

local countElementByTag = function (tag, content)
  local count = 0
  for i = 1, #content do
    if type(content[i]) == "table" and content[i].command == tag then
      count = count + 1
    end
  end
  return count
end

local function getFirstEntryOrth (content)
  -- Recurse into first forms until last level.
  local form = SILE.findInTree(content, "form")
  if form then
    return getFirstEntryOrth(form)
  end
  -- The headword is the first orth in the lowest level form...
  local orth = SILE.findInTree(content, "orth")
  if orth then
    -- Yay, we got the main "headword".
    -- Enrich the orth with its (form) parent type as it will be in charge of
    -- the formatting (i.e. it will need to know whether the form is deduced, etc.)
    orth.options._parentType = content.options.type
    return orth
  end
  -- All entries should have an orth eventually, or I don't know what a
  -- dictionary is...
  SU.error("Sructure error, TEI.orth not found in nested TEI.form")
end

local function findInTreeWithLang (content, element)
  -- Find the first occurrence without language or with same language
  -- as our main language.
  local mainLang = SILE.settings.get("teidict.mainLanguage")
  for i=1, #content do
    if type(content[i]) == "table" and content[i].command == element
        and (content[i].options.lang == nil or content[i].options.lang == mainLang) then
      return content[i]
    end
  end
end

local function shallowcopy (orig)
  local orig_type = type(orig)
  local copy
  if orig_type == "table" then
    copy = {}
    for orig_key, orig_value in pairs(orig) do
        copy[orig_key] = orig_value
    end
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

local refs = {}

local buildPtrReferences = function (content)
  io.stderr:write("<...building references...>")
  local count = 0
  for i = 1, #content do
    if type(content[i]) == "table" and content[i].command == "entry" then
      local ent = content[i]
      if ent.options.id then
        local headword = getFirstEntryOrth(ent)
        headword.options.n = ent.options.n
        -- No need for a deepcopy, just down to the options,
        -- so that we can mark the headword afterwards.
        local refent = shallowcopy(headword)
        refent.options = shallowcopy(headword.options)
        refs[ent.options.id] = refent
        -- Now mark it, so when processed, it knows it is a headword
        -- and will register an infonode.
        headword.options._isHeadword = true
        count = count + 1
      end
    end
  end
  io.stderr:write("<..."..count.." references collected...>\n")
end

local function doSpacing(options)
  if options._pos == nil then
    -- orth, bibl can notably be in this case when used notes, pointers, etc.
    return
  end
  if options._pos > 1 then
    SILE.typesetter:typeset(" ")
  end
end

-- These nodes are just structure nodes.
-- The filter boolean option will skip them if not in the proper main language.
-- Ortherwise, they should not have any text children (or just spaces, due to XML
-- indentation), so we ignore these.
-- The spacing boolean indicates whether we have to check for spaces before the
-- structure.
local function walkAsStructure(walkOptions, options, content)
  local mainLang = SILE.settings.get("teidict.mainLanguage")
  if walkOptions.filter and mainLang and options.lang and options.lang ~= mainLang then
    return -- Ignore
  end

  if walkOptions.spacing then
    doSpacing(options)
  end

  local iElem = 0
  for i = 1, #content do
    if type(content[i]) == "table" then
      iElem = iElem + 1
      content[i].options._pos = iElem
      SILE.process({ content[i] })
    end
    -- All text nodes in ignored in structure tags.
  end
  if SU.boolean(walkOptions.skipafter, false) then
    SILE.typesetter:leaveHmode()
    SILE.call("medskip")
  end
end

-- These nodes are just paragraph containers.
-- The filter boolean option will skip them if not in the proper main language.
-- Otherwise, process them and end the paragraph.
local function walkAsParagraph(walkOptions, options, content)
  local mainLang = SILE.settings.get("teidict.mainLanguage")
  if walkOptions.filter and mainLang and options.lang and options.lang ~= mainLang then
    return -- Ignore
  end
  SILE.process(content)
  SILE.typesetter:leaveHmode()
end

-- HELPER COMMANDS
-- Leverage xmltricks:passthru with more specialized commands.

SILE.registerCommand("tei:passthru:asParagraph", function (options, content)
  for token in SU.gtoke(content[1]) do
    if token.string then
      SILE.registerCommand(token.string, function(cOptions, cContent)
        walkAsParagraph(options, cOptions, cContent)
      end)
    end
  end
end)

SILE.registerCommand("tei:passthru:asStructure", function (options, content)
  for token in SU.gtoke(content[1]) do
    if token.string then
      SILE.registerCommand(token.string, function(cOptions, cContent)
        walkAsStructure(options, cOptions, cContent)
      end)
    end
  end
end)

SILE.registerCommand("tei:ornament", function (options, _)
  local alt = SU.boolean(options.alt, false)
  local ornament = alt and "cul-de-lampe-2" or "cul-de-lampe-1"
  SILE.typesetter:leaveHmode()
  SILE.call("center", {}, function()
    SILE.call("svg", { src = "packages/culs-de-lampe/"..ornament..".svg", height = "8pt" })
  end)
end)

-- HEADER LEVEL TAGS

SILE.registerCommand("teiHeader", function (_, content)
  local fileDesc = SILE.findInTree(content, "fileDesc") or SU.error("Structure error, no TEI.fileDesc")
  local titleStmt = SILE.findInTree(fileDesc, "titleStmt") or SU.error("Structure error, no TEI.titleStmt")
  local title = findInTreeWithLang(titleStmt, "title") or SU.error("Structure error, no TEI.title")

  -- Some hack so that the top title page appears in the PDF outline.
  -- (My reader automatically jumps to the first topic, and I don't want that.)
  SILE.call("pdf:destination", { name = "tei_cover" })
  SILE.call("pdf:bookmark", { title = "-", dest = "tei_cover", level = 1 })

  SILE.call("teibook:titlepage", {}, title)

  walkAsStructure({}, {}, content)
end)

SILE.call("xmltricks:ignore", {}, { "encodingDesc profileDesc" })
SILE.call("tei:passthru:asStructure", {}, { "fileDesc titleStmt sourceDesc" })
SILE.call("tei:passthru:asStructure", { skipafter = true }, { "editionStmt respStmt notesStmt" })

SILE.call("tei:passthru:asParagraph", { filter = true }, { "resp" })
SILE.call("tei:passthru:asStructure", {}, { "availability" })

SILE.registerCommand("title", function(options, content)
  local mainLang = SILE.settings.get("teidict.mainLanguage")
  if mainLang and options.lang and options.lang ~= mainLang then
    return -- Ignore comment note.
  end
  SILE.call("noindent")
  SILE.call("em", {}, content)
  SILE.typesetter:leaveHmode()
end)

SILE.registerCommand("edition", function (options, content)
  SILE.call("noindent")
  SILE.process(content)
  SILE.typesetter:typeset("[Edition "..options.n.."]")
end)

SILE.call("tei:passthru:asParagraph", {}, { "p" })
SILE.call("xmltricks:passthru", {}, { "name" })

SILE.registerCommand("publicationStmt", function (options, content)
  local publisher = SILE.findInTree(content, "publisher")
  if publisher == nil then SU.error("Structure error, no publisher in TEI.publicationStmt") end
  local date = SILE.findInTree(content, "date")
  if date == nil then SU.error("Structure error, no date in TEI.publicationStmt") end

  SILE.call("vfill")
  SILE.typesetter:leaveHmode()
  SILE.call("style:apply", { name = "tei:header:legalese" }, function ()
    SILE.settings.temporarily(function ()
      SILE.call("noindent")
      SILE.typesetter:typeset("© ")
      SILE.process(date)
      SILE.typesetter:typeset(", ")
      SILE.process(publisher)
      SILE.typesetter:leaveHmode()
    end)
    SILE.call("medskip")

    -- Loop over availability elements until find one in our language
    local availability = findInTreeWithLang(content, "availability")
    if availability == nil then SU.error("Stucture eror: no availability found in TEI.publicationStmt") end
    SILE.call("availability", availability.options, availability)
  end)
  SILE.call("break")
end)

local bibliography
SILE.registerCommand("listBibl", function(options, content)
  -- Store for processing in the backmatter
  bibliography = content
end)

-- DOCUMENT LEVEL TAGS

SILE.call("tei:passthru:asStructure", {}, { "text body" })

SILE.registerCommand("div0", function (options, content)
  local t = SU.required(options, "type", "TEI.div0")
  if t ~= "dictionary" then
    SU.error("Unsupported TEI division type: "..t)
  end

  buildPtrReferences(content)

  SILE.call("tei:ornament")
  SILE.call("teibook:entries")
  SILE.settings.temporarily(function()
    SILE.settings.set("document.lskip", "1em")
    SILE.settings.set("document.parindent", "-1em")
    walkAsStructure({}, {}, content)
  end)
  SILE.typesetter:leaveHmode()
  SILE.call("medskip")
  SILE.call("tei:ornament", { alt = true })

  SILE.call("teibook:backmatter")
  teiabbr.writeAbbr()
  if bibliography then
    teiabbr.writeBibl(bibliography)
  end
  SILE.call("medskip")
  SILE.call("tei:ornament")

  teiabbr.writeImpressum()
end)

SILE.registerCommand("milestone", function (options, content)
  local title = SU.required(options, "n", "TEI.milestone")
  local dest = "tei_milestone_"..options.n
  SILE.typesetter:leaveHmode()
  SILE.call("goodbreak")
  SILE.call("teibook:bigskip")
  SILE.call("pdf:destination", { name = dest })
  SILE.call("pdf:bookmark", { title = title, dest = dest, level = 1 })
  SILE.call("style:apply", { name = "tei:milestone" }, { options.n })
  SILE.call("novbreak")
  SILE.call("teibook:medskip")
  SILE.call("novbreak")
  SILE.typesetter:inhibitLeading()
end)

-- ENTRY LEVEL TAGS

SILE.registerCommand("entry", function (options, content)
  local nSense = countElementByTag("sense", content)
  local iSense = 0
  local nRe = countElementByTag("re", content)
  local iRe = 0

  SILE.typesetter:leaveHmode()
  SILE.call("teibook:smallskip")

  if options.id then
    SILE.call("pdf:destination", { name = options.id })
  end

  local style = (options.type == "xref") and "tei:entry:xref" or "tei:entry:main"
  SILE.call("style:apply", { name = style }, function()
    local iElem = 0
    for i=1, #content do
      if type(content[i]) == "table" then
        iElem = iElem + 1
        content[i].options._pos = iElem
        if content[i].command == "sense" and nSense > 1 then
          iSense = iSense + 1
          content[i].options.n = iSense
        elseif content[i].command == "re" then
          -- FIXME HACK trying to address a spacing issue later, but this is not a clean way
          -- to do it. I am lacking faith here, should be done another way.
          iRe = iRe + 1
          content[i].options.n = iRe
        end
        SILE.process({ content[i] })
      end
      -- All text nodes in <entry> (normally only spaces) are ignored
    end
  end)
  SILE.typesetter:leaveHmode()
end)

SILE.registerCommand("re", function (options, content)
  -- FIXME HACK: Trying to cope with an inconsistency in the HSD, where related entries
  -- can have nested forms (as regular entries), or direct forms (direct list of alternatives),
  -- and we want to apply correct parentheses/commas around the alternatives...
  -- On the other hand, this is a perfectly legit TEI construct, so it should not be handled
  -- this way, and here... and it could even occur theotically at other entry levels so would
  -- need some generalization
  local firstForm = SILE.findInTree(content, "form")
  local hasNestedForms = (SILE.findInTree(firstForm, "form") ~= nil)
  local nForms = countElementByTag("form", content)
  local iForms = 0

  doSpacing(options)
  SILE.typesetter:typeset("◇ ") -- U+25C7 white diamond https://unicode-table.com/fr/25C7/
  -- SILE.typesetter:typeset("◈" ) -- 25C8 white diamond containing black small diamond
                                   -- Absent from Libertinus :(
  local iElem = 0
  for i=1, #content do
    if type(content[i]) == "table" then
      iElem = iElem + 1
      content[i].options._pos = iElem
      if (not hasNestedForms) and content[i].command == "form" then
          iForms = iForms + 1
          if nForms > 1 then
            content[i].options.alt = (iForms > 1) and (iForms - 1)
            content[i].options.altLast = (i > 1 and iForms == nForms)
          end
          content[i].options.last = (iForms == nForms)
      end
      SILE.process({ content[i] })
    end
    -- All text nodes in <re> (normally only spaces) are ignored
  end
end)

-- FORM LEVEL TAGS

SILE.registerCommand("form", function (options, content)
  local nForms = countElementByTag("form", content)

  if nForms > 0 then
    doSpacing(options)

    -- Case: toplevel form (containing other forms)
    local iForms = 0
    local iElem = 0
    for i=1, #content do
      if type(content[i]) == "table" then
        iElem = iElem + 1
        content[i].options._pos = iElem
        if content[i].command == "form" then
          iForms = iForms + 1
          if nForms > 1 then
            content[i].options.alt = (iForms > 1) and (iForms - 1)
            content[i].options.altLast = (i > 1 and iForms == nForms)
          end
          content[i].options.last = (iForms == nForms)
        end
        SILE.process({ content[i] })
      end
      -- All text nodes in <form> (normally only spaces) are ignored
    end
  else
    -- Case: final form (inner, containing actual word forms)
    if options.alt then
      if options.alt == 1 then
        doSpacing(options)
        SILE.typesetter:typeset("(")
      else
        SILE.typesetter:typeset(", ")
      end
    else
      doSpacing(options)
    end
    local nElem = countElements(content)
    local iElem = 0
    options.last = (options.last == nil and true or options.last)
    for i=1, #content do
      if type(content[i]) == "table" then
        iElem = iElem + 1.
        content[i].options._pos = iElem
        content[i].options._parentType = options.type
        SILE.process({ content[i] })
        if iElem < nElem then
     --     SILE.typesetter:typeset(" ")
        end
      end
      -- All text nodes in <form> (normally only spaces) are ignored
    end
    if options.altLast then SILE.typesetter:typeset(")") end
    -- if options.last then SILE.typesetter:typeset(" ") end
  end
end)

-- ORTH/PRON LEVEL TAGS

SILE.registerCommand("orth", function (options, content)
  doSpacing(options)
  if options._isHeadword then
    SILE.call("info", { category = "teientry", value = content }, {})
  end
  local t = options._parentType and teiabbr.orthPrefix(options._parentType)
  if t then
    SILE.typesetter:typeset(t)
  end
  SILE.call("style:apply", { name = "tei:orth" }, content)
  if options.n then
    SILE.call("style:apply", { name = "tei:entry:numbering" }, function()
      SILE.typesetter:typeset(" "..SILE.formatCounter({
        value = options.n,
        display = "ROMAN" })
      )
    end)
  end
end)

SILE.registerCommand("corr", function (options, content)
  local sic = SU.required(options, "sic", "TEI.corr")
  SILE.process(content)
  SILE.typesetter:typeset(" ")
  SILE.call("style:apply", { name = "tei:corr" }, function()
    -- Struck out the "sic" correction:
    -- Disabled - this does not behave well with line breaks
      -- local hbox = SILE.call("hbox", {}, { sic })
      -- local gl = SILE.length() - hbox.width
      -- SILE.call("raise", { height = "0.475ex" }, function()
      --   SILE.call("hrule", { width = gl.length, height = "0.4pt" })
      -- end)
      -- SILE.typesetter:pushGlue({ width = hbox.width })
    SILE.typesetter:typeset("{"..sic.."}")
  end)
end)

-- This only supports a subset of X-SAMPA latin representation of IPA.
local xSampaSubset = {
  ["A"]= 	"ɑ", -- 0251 open back unrounded, Cardinal 5, Eng. start
  ["{"]= 	"æ", -- 00E6 near-open front unrounded, Eng. trap
  ["6"]= 	"ɐ", -- 0250 open schwa, Ger. besser
  ["Q"]= 	"ɒ", -- 0252 open back rounded, Eng. lot
  ["E"]= 	"ɛ", -- 025B open-mid front unrounded, C3, Fr. même
  ["@"]= 	"ə", -- 0259 schwa, Eng. banana
  ["3"]= 	"ɜ", -- 025C long mid central, Eng. nurse
  ["I"]= 	"ɪ", -- 026A lax close front unrounded, Eng. kit
  ["O"]= 	"ɔ", -- 0254 open-mid back rounded, Eng. thought
  ["2"]= 	"ø", -- 00F8 close-mid front rounded, Fr. deux
  ["9"]= 	"œ", -- 0153 open-mid front rounded, Fr. neuf
  ["&"]= 	"ɶ", -- 0276 open front rounded
  ["U"]= 	"ʊ", -- 028A lax close back rounded, Eng. foot
  ["}"]= 	"ʉ", -- 0289 close central rounded, Swedish sju
  ["V"]= 	"ʌ", -- 028C open-mid back unrounded, Eng. strut
  ["Y"]= 	"ʏ", -- 028F lax [y], Ger. hübsch
 -- Consonants
  ["B"]=	"β", -- 03B2 voiced bilabial fricative, Sp. cabo
  ["C"]= 	"ç", -- 00E7 voiceless palatal fricative, Ger. ich
  ["D"]= 	"ð", -- 00F0 voiced dental fricative, Eng. then
  ["G"]= 	"ɣ", -- 0263 voiced velar fricative, Sp. fuego
  ["L"]= 	"ʎ", -- 028E palatal lateral, It. famiglia
  ["J"]= 	"ɲ", -- 0272 palatal nasal, Sp. año
  ["N"]= 	"ŋ", -- 014B velar nasal, Eng. thing
  ["R"]= 	"ʁ", -- 0281 vd. uvular fric. or trill, Fr. roi
  ["S"]= 	"ʃ", -- 0283 voiceless palatoalveolar fricative, Eng. ship
  ["T"]= 	"θ", -- 03B8 voiceless dental fricative, Eng. thin
  ["H"]= 	"ɥ", -- 0265 labial-palatal semivowel, Fr. huit
  ["Z"]= 	"ʒ", -- 0292 vd. palatoalveolar fric., Eng. measure
  ["?"]= 	"ʔ", -- 0294 glottal stop, Ger. Verein, also Danish stød
  ["W"]=  "ʍ", -- 028D voiceless labial–velar fricative
  ["K"]=  "ɬ", -- 026C voiceless alveolar lateral fricative	
 -- Length, stress and tone marks
  [":"]= 	"ː", -- 02D0 length mark
  ["\""]=  	"ˈ", -- 02C8 primary stress *
  ["%"]=    "ˌ", -- 02CC secondary stress
 -- Diacritics
  ["="]= 	"̩", -- 0329 syllabic consonant, Eng. garden (see note 2)
  ["~"]= 	"̃ ", -- 0303 nasalization, Fr. bon
  [","]= 	"̡" -- 0321 palatal subscript
}

local toIpa = function (str)
  -- The special case is a bit "ad hoc" for the HSD, but that's the only
  -- multi-character X-SAMPA sequence we needed so far.
  local special = string.gsub(str, "r\\_0", "ɹ̥") -- 0279 0325 reverser r, vl.
  local ipa = string.gsub(special, ".", xSampaSubset)
  return ipa
end

SILE.registerCommand("pron", function (options, content)
  -- Convert to IPA, then typeset in an hbox to avoid line breaks
  local pron = SU.contentToString(content)
  doSpacing(options)
  -- Put in an hbox, to avoid breaks in the pronunciation
  SILE.call("hbox", {}, { "["..toIpa(pron).."]" })
end)

local inputfilter = SILE.require("packages/inputfilter").exports

-- Helper to insert breakpoints in unwieldy bibliographic references
local biblFilter = function (node, content)
  if type(node) == "table" then return SU.error("Structure error: TEI.bibl expected to containt text") end
  local result = {}
  for token in SU.gtoke(node, "[:/,%-]") do
    if token.string then
      result[#result+1] = token.string
    else
        result[#result+1] = token.separator
        result[#result+1] = inputfilter.createCommand(
          content.pos, content.col, content.line,
          "penalty", { penalty = 200 }, nil
        )
    end
  end
  return result
end

SILE.registerCommand("bibl", function (options, content)
  local transformed = inputfilter.transformContent(content, biblFilter)
  doSpacing(options)
  SILE.call("style:apply", { name = "tei:bibl" }, transformed)
end)

-- SENSE LEVEL TAGS

SILE.registerCommand("sense", function (options, content)
  local transLang = SILE.settings.get("teidict.transLanguage")
  local nTrans = countElementByTag("trans", content)
  local iTrans = 0

  doSpacing(options)
  if options.n then
    if options.n == 1 then
      SILE.call("style:apply", { name = "tei:sense:numbering"}, function()
        SILE.typesetter:typeset(""..options.n)
      end)
      SILE.typesetter:typeset(". ")
    else
      SILE.typesetter:typeset("○ ") -- Note: U+25CB ○ white circle
      SILE.call("style:apply", { name = "tei:sense:numbering"}, function()
        SILE.typesetter:typeset(""..options.n)
      end)
      SILE.typesetter:typeset(". ")
    end
  end
  local iElem = 0
  for i=1, #content do
    if type(content[i]) == "table" then
      iElem = iElem + 1
      content[i].options._pos = iElem
      if content[i].command == "trans" and nTrans > 1 then
        if not(transLang and content[i].options.lang and content[i].options.lang ~= transLang) then
          iTrans = iTrans + 1
          content[i].options.n = iTrans
          SILE.process({ content[i] })
        end
      else
        SILE.process({ content[i] })
      end
    end
    -- All text nodes in <sense> (normally only spaces) are ignored
  end
end)

SILE.registerCommand("trans", function (options, content)
  local lang = SU.required(options, "lang", "TEI.trans")

  doSpacing(options)
  if options.n and options.n > 1 then
    SILE.typesetter:typeset("— ") -- Note: U+2014 — em dash
  end
  SILE.settings.temporarily(function()
    SILE.settings.set("document.language", lang)
    SILE.process(trimContent(content))
  end)
end)

SILE.registerCommand("gloss", function (options, content)
  SILE.process(trimContent(content))
end)

SILE.registerCommand("def", function (options, content)
  SILE.process(trimContent(content))
end)

SILE.registerCommand("tr", function (options, content)
  -- The HSD uses <def> (definition) everywhere, but for multilingual
  -- dictionaries, <tr> (translation) is rather expected.
  SILE.process(trimContent(content))
end)

-- GRAMMATICAL AND USAGE LEVEL TAGS

SILE.call("tei:passthru:asStructure", { spacing = true }, { "gramGrp" })

for _, pos in ipairs({ "pos", "mood", "per", "tns", "number", "gen", "subc", "itype", "lbl" }) do
  SILE.registerCommand(pos, function (options, content)
    doSpacing(options)
    local expandedAbbr = teiabbr.translateAbbr(content, pos)
    SILE.call("style:apply", { name = "tei:pos" }, { expandedAbbr })
  end)
end

SILE.registerCommand("usg", function (options, content)
  local t = SU.required(options, "type", "TEI.usg")
  if t == "hint" then
    SILE.typesetter:typeset("(")
    SILE.call("style:apply", { name = "tei:hint" }, content)
    italicCorr("tei:hint")
    SILE.typesetter:typeset(")")
  elseif t == "lang" then
    doSpacing(options)
    local norm = SU.required(options, "norm", "TEI.usg (lang)")
    SILE.call("style:apply", { name = "tei:pos" }, { options.norm })
  elseif t == "cat" then
    -- ignored (FIXME shouldn't formally, but the HSD has them wrong)
  elseif t == "gram" or t == "ext" then
    doSpacing(options)
    local expandedAbbr = teiabbr.translateAbbr(content, "usg")
    SILE.call("style:apply", { name = "tei:pos" }, { expandedAbbr })
    SILE.typesetter:typeset(",")
  else
    doSpacing(options)
    local expandedAbbr = teiabbr.translateAbbr(content, "usg")
    SILE.call("style:apply", { name = "tei:pos" }, { expandedAbbr })
  end
end)

-- EXAMPLE TAGS

-- FIXME ignored for now (at least we don't break on them, but they would
-- need some support)

SILE.call("tei:passthru:asStructure", { spacing = true }, { "eg" })

SILE.registerCommand("q", function (options, content)
  doSpacing(options)
  SILE.typesetter:typeset("◦ ") -- Note: U+25E6 white bullet
  SILE.call("style:apply", { name = "tei:q" }, function ()
    SILE.process(trimContent(content))
    SILE.typesetter:typeset(",")
  end)
end)

-- LINKING TAGS

SILE.registerCommand("xr", function (options, content)
  if options.type == "analogy" then
    SILE.settings.temporarily(function()
      SILE.settings.set("document.parindent", "0em")
      SILE.typesetter:leaveHmode()
      SILE.typesetter:typeset("☞ ") -- Note: U+261E ☞ white right pointing index
      SILE.process(content)
    end)
  elseif options.type == "see" then
    doSpacing(options)
    SILE.typesetter:typeset("→ ") -- Note: U+2192 → right arrow
    SILE.process(content)
  elseif options.type == "of" then
    doSpacing(options)
    local expandedAbbr = teiabbr.translateAbbr({ "of" }, "xr")
    SILE.call("style:apply", { name = "tei:pos" }, { expandedAbbr })
    SILE.typesetter:typeset(" ")
    SILE.process(content)
    SILE.typesetter:typeset(",")
  else
    SU.error("Unimplemented TEI.xr type: "..options.type)
  end
end)

SILE.registerCommand("ptr", function (options, content)
  local target = options.target and refs[options.target]
  if target == nil then SU.error("") end

  SILE.call("pdf:link", { dest = options.target }, function()
    SILE.call("orth", target.options, target)
  end)
end)

-- OTHER MISCELLANEOUS TAGS

SILE.call("xmltricks:ignore", {}, { "etym index" }) -- FIXME provide some support for these, later

SILE.registerCommand("note", function (options, content)
  local t = options.type

  if t == nil then
    -- Notes in the teiHeader/fileDesc/notesStmt = contain several paragraphs
    walkAsStructure({ filter = true }, options, content)
    return
  end

  SILE.settings.temporarily(function()
    SILE.settings.set("document.parindent", "0em")
    if t == "source" then
      SILE.typesetter:typeset(" ◇ ") -- U+25C7 white diamond
      SILE.process(content)
    elseif t == "source,deduced" then
      SILE.typesetter:typeset(" ←") -- U+2190 leftward arrow
      SILE.call("kern", { width = "0.25em" })
      SILE.process(content)
    elseif t == "comment" then
      local mainLang = SILE.settings.get("teidict.mainLanguage")
      if mainLang and options.lang and options.lang ~= mainLang then
        return -- Ignore comment note.
      end
      SILE.settings.temporarily(function()
        SILE.call("style:apply", { name = "tei:note" }, function()
          SILE.typesetter:leaveHmode()
          SILE.typesetter:typeset("▶") -- Note: U+25B6 black right pointing triangle
          SILE.call("kern", { width = "0.25em" })
          -- SILE.typesetter:typeset("◈ ") -- Note: U+25C8 white diamond containing black small diamond
                                          -- Absent from Libertinus.
          SILE.settings.set("document.language", options.lang)
          SILE.process(trimContent(content))
          SILE.typesetter:leaveHmode()
        end)
      end)
    else
      SU.error("Unsupported type in TEI:note: "..t)
    end
  end)
end)

SILE.registerCommand("foreign", function (options, content)
  local lang = SU.required(options, "lang", "TEI.foreign")

  SILE.settings.temporarily(function()
    SILE.settings.set("document.language", lang)
    SILE.process(content)
  end)
end)

SILE.registerCommand("hi", function (options, content)
  SILE.call("style:apply", { name = "tei:mentioned" }, content)
end)

SILE.registerCommand("mentioned", function (options, content)
  SILE.call("style:apply", { name = "tei:mentioned" }, content)
end)

SILE.registerCommand("xref", function (options, content)
  SILE.call("url", {}, content)
end)
-- Override default URL font...
SILE.registerCommand("code", function (options, content)
  SILE.process(content)
end)

return {
  documentation = [[\begin{document}
\script[src=packages/url]
%\script[src=packages/footnotes]
\script[src=packages/autodoc-extras]

This package supports a subset of the (XML) TEI  P4 “Print Dictionary” standard,
as suitable for the Sindarin Dictionary project, and assumes a similar structure to the
latter, see its \href[src=https://omikhleia.github.io/sindict/manual/DATA_MODEL.html]{Data
Model}\footnote{\doc:url{https://omikhleia.github.io/sindict/manual/DATA_MODEL.html}}.

The main pain point is that such a dictionary is a heavily “semantic” structured
mark-up (i.e. a “lexical view”, encoding structure information such as part-of-speech
etc. without much concern for its exact textual representation in print form),
much more than a “presentational” mark-up. Some XML nodes may contain many things
one needs to ignore (such as spaces, mostly) or supplement (such as punctuation,
parentheses, numbering… and again, proper spaces where needed). Without XPath to
check siblings, ascendants or descendants, it may become somewhat hard to get a nice
automated output (and even with XPath, it is not that obvious). In other terms,
the solution proposed here is somewhat \em{ad hoc} for a specific type of lexical TEI
dictionary and depends quite a lot on its structural organization.

This package is not intended to be used as-is, but along with the \doc:code{teibook}
class, which loads it as well as a number of extra packages. It itself relies
on a few settings that one would usually define in a preamble document, e.g.:

\begin{doc:codes}
\doc:code{sile -I preambles/dict-sd-en-preamble.sil} \doc:args{dictionary.xml}
\end{doc:codes}

\end{document}]]
}

-- ALL DONE.
