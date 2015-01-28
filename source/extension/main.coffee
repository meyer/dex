if window.self isnt window.top
	console.groupCollapsed("Ignoring iframe: #{window.self.location.hostname}")
	console.log window.self.location.href
	console.groupEnd()
	return

dexURL = "<%= DEX_URL %>/"

dexJS = document.createElement "script"

if window.chrome
	dexJS.src = chrome.extension.getURL "dex.js"
else
	dexJS.src = safari.extension.baseURI + "dex.js"

hostJS = document.createElement "script"
hostJS.src = dexURL + window.location.hostname + ".js"

hostCSS = document.createElement "link"
hostCSS.rel = "stylesheet"
hostCSS.href = dexURL + window.location.hostname + ".css"

asapLoaded = false
bodyLoaded = false

insertDexfiles = (e) ->
	return unless e.relatedNode.tagName?

	if !asapLoaded && headOrBody = document.head || document.body
		asapLoaded = true
		headOrBody.appendChild hostCSS

	if !bodyLoaded && document.body
		bodyLoaded = true
		document.body.appendChild dexJS
		document.body.appendChild hostJS
		document.body.appendChild hostCSS.cloneNode()

	if asapLoaded and bodyLoaded
		this.removeEventListener "DOMNodeInserted", insertDexfiles, false

document.addEventListener "DOMNodeInserted", insertDexfiles
