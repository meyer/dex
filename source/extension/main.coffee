if window.self isnt window.top
	console.groupCollapsed("Ignoring iframe: #{window.self.location.hostname}")
	console.log window.self.location.href
	console.groupEnd()
	return

validateLocation = ->
	# Only match http/https
	if !~["http:", "https:"].indexOf(document.location.protocol)
		console.error "Only HTTP and HTTPS protocols are supported"
		false

	# Require a dot in the URL
	else if !~document.location.hostname.indexOf(".")
		console.error "Hostname `#{document.location.hostname}` is invalid (no dot)"

	# Match everything but IP addresses and .dev URLs
	else if document.location.hostname.match(/^.+\.(\d+|dev)$/)
		console.error "Hostname `#{document.location.hostname}` is invalid (ip/dev)"
		false

	else
		# Clean up that hostname
		document.location.hostname.replace(/^ww[w\d]\./, "")

chrome.storage.local.get "dexData", (res) ->
	{
		modulesByHostname
		moduleData
		metadata
	} = res.dexData

	unless hostname = validateLocation()
		console.error "Invalid hostname"
		return

	globalModules = modulesByHostname.enabled["global"]

	unless siteModules = modulesByHostname.enabled[hostname]
		siteModules = []

	cssFiles = []
	jsFiles = []

	[].concat("global", globalModules, hostname, siteModules).forEach (mod) ->
		if moduleData[mod]
			cssFiles.push moduleData[mod].css || "/* No CSS data for '#{mod}' */"
			jsFiles.push  moduleData[mod].js  || "/* No JS data for '#{mod}' */"
		else
			cssFiles.push "/* Error: moduleData['#{mod}'] is not set */"
			jsFiles.push "/* Error: moduleData['#{mod}'] is not set */"

	cssEl = document.createElement "style"
	jsEl = document.createElement "script"

	cssEl.setAttribute("dex-was-here","")
	jsEl.setAttribute("dex-was-here","")

	cssEl.textContent = cssFiles.join("\n\n")
	jsEl.textContent  = jsFiles.join("\n\n")

	asapLoaded = false
	bodyLoaded = false

	insertDexfiles = (e) ->
		return unless e.relatedNode.tagName?

		if !asapLoaded && headOrBody = document.head || document.body
			asapLoaded = true
			headOrBody.appendChild cssEl

		if !bodyLoaded && document.body
			bodyLoaded = true
			document.body.appendChild jsEl

		if asapLoaded and bodyLoaded
			this.removeEventListener "DOMNodeInserted", insertDexfiles, false

	document.addEventListener "DOMNodeInserted", insertDexfiles
