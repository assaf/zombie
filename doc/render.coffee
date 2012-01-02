File    = require("fs")
{ exec} = require("child_process")
HLJS    = require("highlight/lib/vendor/highlight.js/highlight").hljs


# HLJS can't guess the language (JavaScript) consistently, so we're going to help by limiting its choice of languages to
# JavaScript and XML (good pick for one of the dumps).
require("highlight/lib/vendor/highlight.js/languages/xml")(HLJS)
require("highlight/lib/vendor/highlight.js/languages/javascript")(HLJS)

# Syntax highlighting
highlight = (html)->
  unescape = (html)->
    return html.replace(/&quot;/g, "\"").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
  return html.replace(/<code>([\s\S]*?)<\/code>/gm, (_, source)-> "<code>#{HLJS.highlightText(unescape(source).replace(/\uffff/g,"\n"))}</code>")

# Markdown to HTML.
exec "ronn --html #{process.argv[2]}", (error, stdout, stderr)->
  throw error if error
  File.readFile "doc/layout/main.html", "utf8", (error, layout)->
    throw error if error

    [name, title] = stdout.match(/<h1>(.*)<\/h1>/)[1].split(" -- ")
    name = name.replace(/\(\d\)/, "")
    body = stdout.replace(/<h1>.*<\/h1>/, "")
    html = layout.replace("{{body}}", body).replace(/{{title}}/g, title)
    html = highlight(html)
    File.writeFile process.argv[3], html, "utf8", (error)->
      throw error if error
      process.exit(0)
