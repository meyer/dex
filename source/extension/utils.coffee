window.dexutils = {}

###
Universal Methods
###
window.dexutils.getValidHostname = (url) ->
	return false unless url? and url isnt ""

	a = document.createElement("a")
	a.href = url

	# Only match http/https
	if !~["http:", "https:"].indexOf(a.protocol)
		console.error "Only HTTP and HTTPS protocols are supported"
		false

	# Require a dot in the URL
	else if !~a.hostname.indexOf(".")
		console.error "Hostname `#{a.hostname}` is invalid (no dot)"

	# Match everything but IP addresses and .dev URLs
	else if a.hostname.match(/^.+\.(\d+|dev)$/)
		console.error "Hostname `#{a.hostname}` is invalid (ip/dev)"
		false

	else
		# Clean up that hostname
		a.hostname.replace(/^ww[w\d]\./, "")

window.dexutils.getJSON = (url, callback) ->
	try
		xhr = new XMLHttpRequest()
		xhr.open "GET", url, true

		xhr.onreadystatechange = ->
			if xhr.readyState == 4
				if xhr.status == 200
					responseJSON = {}

					try
						responseJSON = JSON.parse xhr.responseText
					catch error
						console.error "Error parsing response JSON: `#{xhr.responseText}`"
						console.info error

					callback?(responseJSON)
				else
					callback?(false, "Error: xhr.status != 200 (#{xhr.status})")

		xhr.send()
	catch e
		console.error "Weird XHR error:", e
		callback?(false, "Error: #{e}")

	return

bodySwap = (guts) ->
	tempDiv = document.createElement "div"
	tempDiv.style.visibility = "hidden"
	tempDiv.style.position = "absolute"
	tempDiv.style.top = 0
	tempDiv.style.left = 0
	tempDiv.innerHTML = guts
	document.body.appendChild tempDiv

	if safari?.self?.height?
		safari.self.height = tempDiv.clientHeight
		console.log "Set popover height (#{safari.self.height})"

	document.body.innerHTML = tempDiv.innerHTML
	tempDiv.remove()

window.dexutils.loadModuleListForURL = (url, callback) ->
	unless hostname = dexutils.getValidHostname(url)
		console.error "URL is invalid (#{url})"

		loadEmpty = ->
			emptyTpl = _.template(document.getElementById("module-list-empty").innerHTML)
			bodySwap emptyTpl {url}
			callback?(false, "URL is invalid (#{url})")
			return

		if document.body?
			loadEmpty()
		else
			document.addEventListener "DOMContentLoaded", loadEmpty

		return

	jsonURL = "<%= DEX_URL %>/#{hostname}.json"
	moduleListTpl = _.template(document.getElementById("module-list-tpl").innerHTML)

	dexutils.getJSON jsonURL, (data, error) ->
		# TODO: Deal with dexd failures
		if error?
			callback?(false, error)
			return

		data.hostname = hostname
		bodySwap moduleListTpl data
		callback?(data)

		# TODO: Move this out of utils
		document.body.addEventListener "change", (e) ->
			unless e.target.dataset.module?
				console.error "Element #{e.target.tagName} is missing data-href attribute"
				return

			dexutils.getJSON "#{jsonURL}?toggle=#{e.target.dataset.module}", (moduleData) ->
				if moduleData.length? && moduleData.length == 2
					[action, module] = moduleData
					console.log "#{module}: #{action}, checked: #{e.target.checked}"
				else
					console.error "Expected a two-element array, got something funky instead:", moduleData

	return


window.dexutils.sendMessageToBKG = (key, data, callback) ->
	callback ?= (res) ->
		console.log "No callback set for dexutils.sendMessageToBKG. Response:", res

	if window.chrome
		# TODO: Figure out why callback is never called
		chrome.runtime.sendMessage({key, data}, callback)

	else if window.safari
		safari.self.tab.dispatchMessage(key, data)

	else
		console.log "Cannot send message:", {key, data}

window.dexutils.listenForBKGMessage = (key, callback) ->
	if window.chrome
		console.log "Watching for BKG messages (key: '#{key}')"
		chrome.runtime.onMessage.addListener(
			(res, sender, sendResponse) ->
				if sender.tab
					console.log "From content script (key: '#{res.key}', from content script [#{sender.tab.url}])"
				else
					console.log "BKG message (key: '#{res.key}', from extension)"

				if res?.key == key
					callback?(res.data)
					# sendResponse res.data
				return
		)

	else if window.safari
		safari.self.addEventListener("message", (
			(e) ->
				if e.name == key
					console.log "EVENT: #{e.name} (handled)", e.message
					callback?(e.message)
				else
					console.log "EVENT: #{e.name} (unhandled)", e.message
		), false)


window.dexutils.injectCSS = (tabID = null, code, callback) ->
	if window.chrome
		try
			chrome.tabs.insertCSS(tabID, {code, runAt: "document_start"}, callback)
		catch e
			console.error "Error with chrome.tabs.insertCSS:", e
	else
		console.log "dexutils.injectCSS is not supported in your browser (yet)"

window.dexutils.injectJS = (tabID = null, code, callback) ->
	if window.chrome
		try
			chrome.tabs.executeScript(tabID, {code, runAt: "document_start"}, callback)
		catch e
			console.error "Error with chrome.tabs.executeScript:", e
	else
		console.log "dexutils.injectJS is not supported in your browser (yet)"

window.dexutils.getDataForHostname = (hostname, dexData) ->
	{
		modulesByHostname
		moduleData
		metadata
	} = dexData

	globalModules = modulesByHostname.enabled["global"]

	unless siteModules = modulesByHostname.enabled[hostname]
		siteModules = []
		# console.log "No modules for #{hostname}."

	css = []
	js = []

	[].concat("global", globalModules, hostname, siteModules).forEach (mod) ->
		if moduleData[mod]
			css.push moduleData[mod].css || "/* No CSS data for '#{mod}' */"
			js.push  moduleData[mod].js  || "/* No JS data for '#{mod}' */"
		else
			css.push "/* Error: moduleData['#{mod}'] is not set */"
			js.push "/* Error: moduleData['#{mod}'] is not set */"

	css: css.join("\n\n")
	js:  js.join("\n\n")