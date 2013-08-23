hostname = window.location.host.replace /^www\./, ''
address = '<%= DEX_URL %>/'

return unless window.self is window.top # no iframes
return if ~hostname.indexOf 'localhost' # no localhost

jquery = document.createElement 'script'
dex = document.createElement 'script'

if window.chrome
	jquery.src = chrome.extension.getURL 'jquery-2.0.3.min.js'
	dex.src = chrome.extension.getURL 'dex.js'
else
	jquery.src = safari.extension.baseURI + 'jquery-2.0.3.min.js'
	dex.src = safari.extension.baseURI + 'dex.js'

js = document.createElement 'script'
js.src = address + hostname + '.js'

css = document.createElement 'link'
css.rel = 'stylesheet'
css.href = address + hostname + '.css'

cssLoaded = false
jsLoaded = false

# Because DOMContentLoaded is too slow™
# TODO: Find an event that isn’t deprecated. Or maybe just an interval? IDK.
document.addEventListener 'DOMNodeInserted', (e) ->
	if typeof(e.relatedNode.tagName) != 'undefined'
		if !cssLoaded
			asap = document.head || document.body
			if asap
				# TODO: Load site.com.head.js here?
				console.log 'CSS Loaded'
				cssLoaded = true
				asap.appendChild css

		if !jsLoaded && (document.body || false)
			console.log 'JS Loaded'
			jsLoaded = true
			document.body.appendChild css.cloneNode()

			document.body.appendChild jquery
			document.body.appendChild dex
			document.body.appendChild js

		if cssLoaded and jsLoaded
			this.removeEventListener 'DOMNodeInserted', arguments.callee, false