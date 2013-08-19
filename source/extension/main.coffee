dexfile = window.location.host.replace /^www\./, ''
address = '<%= DEX_URL %>/'

# Don’t load on iframed content (like buttons and whatnot)
# Idea: load different stylesheets if iframed? Alas, poor webrick.
return unless window.self is window.top

# Stuff to load
script = document.createElement 'script'
script.src = address + dexfile + '.js'

# OMG THIS IS SO BAD
# xhr = new XMLHttpRequest()
# xhr.open "GET", address + dexfile + '.eval.js', false
# xhr.send null
# eval xhr.responseText

link = document.createElement 'link'
link.rel = 'stylesheet'
link.href = address + dexfile + '.css'

cssLoaded = false
jsLoaded = false

# Because DOMContentLoaded is too slow™
# TODO: Find an event that isn’t deprecated.
document.addEventListener 'DOMNodeInserted', (e) ->
	if typeof(e.relatedNode.tagName) != 'undefined'
		if !cssLoaded
			asap = document.head || document.body
			if asap
				# TODO: Load site.com.head.js here?
				console.log 'CSS Loaded'
				cssLoaded = true
				asap.appendChild link
		else if !jsLoaded && e.relatedNode.tagName == 'BODY'
			console.log 'JS Loaded'
			jsLoaded = true
			document.body.appendChild link.cloneNode()
			document.body.appendChild script
		else if cssLoaded and jsLoaded
			this.removeEventListener 'DOMNodeInserted', arguments.callee, false

# Idea: reload JS on popstate (?)