hostname = window.location.host.replace /^www\./, ''
address = '<%= DEX_URL %>/'

return unless window.self is window.top # no iframes
return if ~hostname.indexOf 'localhost' # no localhost

dex = document.createElement 'script'

if window.chrome
	dex.src = chrome.extension.getURL 'dex.js'
else
	dex.src = safari.extension.baseURI + 'dex.js'

js = document.createElement 'script'
js.src = address + hostname + '.js'

css = document.createElement 'link'
css.rel = 'stylesheet'
css.href = address + hostname + '.css'

# dex.defer = true
# js.defer = true

asapLoaded = false
bodyLoaded = false

# Because DOMContentLoaded is too slow™
# TODO: Find an event that isn’t deprecated. Or maybe just an interval? IDK.
document.addEventListener 'DOMNodeInserted', (e) ->
	if typeof(e.relatedNode.tagName) != 'undefined'
		console.log 'AGAIN'
		if !asapLoaded
			d = document.head || document.body
			if d
				console.log 'ASAP'
				asapLoaded = true
				d.appendChild css

		if !bodyLoaded
			d = document.body || false
			if d
				console.log 'BODY'
				bodyLoaded = true
				d.appendChild dex
				d.appendChild js
				d.appendChild css.cloneNode()

		if asapLoaded and bodyLoaded
			this.removeEventListener 'DOMNodeInserted', arguments.callee, false