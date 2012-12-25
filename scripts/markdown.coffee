# Process Markdown files, page layout and generates HTML page.
#
# Used by scripts/docs and scripts/live.

File        = require("fs")
NSH         = require("node-syntaxhighlighter")
Robotskirt  = require("robotskirt")


NSH_OPTIONS =
  "auto-links": false
  "class-name": "code"
  "gutter":     false
  "toolbar":    false

ROBOTSKIRT_OPTIONS = [
  Robotskirt.EXT_TABLES
  Robotskirt.EXT_AUTOLINK
  Robotskirt.EXT_FENCED_CODE
]


# Render the Markdown file using the given HTML layout file.  Pass error or HTML
# to callback.
render = (markdownFilename, layoutFilename, callback)->
  File.readFile markdownFilename, "utf8", (error, markdown)->
    if error
      callback(error)
      return

    File.readFile layoutFilename, "utf8", (error, layout)->
      if error
        callback(error)
        return

      # Render to HTML with syntax highlighting
      renderer = new Robotskirt.HtmlRenderer()
      renderer.blockcode = (code, language)->
        if language
          nshLanguage = NSH.getLanguage(language)
        if nshLanguage
          return NSH.highlight(code, nshLanguage, NSH_OPTIONS)
        else
          return "<pre>" + Robotskirt.houdini.escapeHTML(code) + "</pre>"

      # Parse Markdown with support for tables, autolinking and fenced code blocks
      parser = new Robotskirt.Markdown(renderer, ROBOTSKIRT_OPTIONS)
      content = parser.render(markdown)

      # http://daringfireball.net/projects/smartypants/
      content = Robotskirt.smartypantsHtml(content)
        
      # Add IDs for all headers so they can be references
      addIDToHeader = (match, level, textContent)->
        id = textContent.replace(/\s+/, "_").toLowerCase()
        return "<h#{level} id=\"#{id}\">#{textContent}</h#{level}>"
      content = content.replace(/<h([1-3])>(.*)<\/h[1-3]>/g, addIDToHeader)

      html = layout.replace("{content}", content)
      callback(null, html)


module.exports = render
