dexURL = "<%= DEX_URL %>/"

# TODO: Conditionally support iframes
if window.self isnt window.top
	console.log "iframe, total area: #{(window.self.innerWidth+1) * (window.self.innerHeight+1)}px"

dexJS = document.createElement "script"

if window.chrome
	dexJS.src = chrome.extension.getURL "dex.js"
else
	dexJS.src = safari.extension.baseURI + "dex.js"

hostJS = document.createElement "script"
hostJS.src = dexURL + window.location.host + ".js"

hostCSS = document.createElement "link"
hostCSS.rel = "stylesheet"
hostCSS.href = dexURL + window.location.host + ".css"

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