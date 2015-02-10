if window.self isnt window.top
	console.groupCollapsed("Ignoring iframe: #{window.self.location.hostname}")
	console.log window.self.location.href
	console.groupEnd()
	return

dexURL = "<%= DEX_URL %>/"

hostJS = document.createElement "script"
hostCSS = document.createElement "link"
globalJS = document.createElement "script"
globalCSS = document.createElement "link"

hostCSS.rel = "stylesheet"
globalCSS.rel = "stylesheet"

hostJS.src = dexURL + window.location.hostname + ".js"
hostCSS.href = dexURL + window.location.hostname + ".css"
globalJS.src = dexURL + "global.js"
globalCSS.href = dexURL + "global.css"

asapLoaded = false
bodyLoaded = false

insertDexfiles = (e) ->
	return unless e.relatedNode.tagName?

	if !asapLoaded && headOrBody = document.head || document.body
		asapLoaded = true
		headOrBody.appendChild globalCSS
		headOrBody.appendChild hostCSS

	if !bodyLoaded && document.body
		bodyLoaded = true
		# document.body.appendChild dexJS
		document.body.appendChild globalJS
		document.body.appendChild hostJS

	if asapLoaded and bodyLoaded
		this.removeEventListener "DOMNodeInserted", insertDexfiles, false

document.addEventListener "DOMNodeInserted", insertDexfiles
