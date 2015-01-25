validateURL = (url) ->
	if !url?
		console.error "URL is not defined"
		return false

	if url == ""
		console.error "URL is blank"
		return false

	try
		# Strip down to hostname
		[protocol, url] = url.split("://")
		url = url.split("/")[0]
	catch e
		console.error "URL parsing failed:", e
		return false

	ignoredProtocols = [
		"chrome"
		"chrome-extension"
	]

	if ~ignoredProtocols.indexOf(protocol)
		console.error "URL protocol is blacklisted"
		return false

	# Lazy IP address regex, *.dev, localhost
	if url.match /^((?:\d{1,3}\.){3}\d{1,3}|([^\/]+)\.dev|localhost)/
		console.error "URL is invalid (regex miss, #{url})"
		return false

	# Necessary?
	unless url.match /^[\w\-_.]+\.\w{2,}$/
		console.error "URL is invalid (regex miss 2, #{url})"
		return

	return url

loadJSON = (originalURL) ->

	unless url = validateURL(originalURL)
		console.error "loadJSON cannot continue: URL is invalid"
		return

	jsonURL = "https://localhost:3131/#{url}.json"

	moduleListTpl = _.template(
		document.getElementById("module-list-tpl").innerHTML
		null
		{
			variable: "data"
		}
	)

	xhr = new XMLHttpRequest()
	xhr.open "GET", jsonURL, true

	xhr.onreadystatechange = ->
		if xhr.readyState == 4 && xhr.status == 200
			try
				moduleJSON = JSON.parse xhr.responseText
			catch e
				console.error "Error parsing response JSON: #{e}"
				console.error "xhr.responseText is blank" if xhr.responseText == ""
				return

			moduleJSON.json_url = jsonURL

			console.log moduleJSON

			document.body.innerHTML = moduleListTpl(moduleJSON)

			document.body.addEventListener "change", (e) ->
				unless e.target.dataset.href?
					console.error "Element #{e.target.tagName} is missing data-href attribute"
					return

				xhr2 = new XMLHttpRequest()
				xhr2.open "GET", e.target.dataset.href, true
				xhr2.onreadystatechange = ->
					if xhr2.readyState == 4 && xhr2.status == 200
						[action, module] = JSON.parse xhr2.responseText
						console.log "#{module}: #{action}, checked: #{e.target.checked}"

				xhr2.send()

	xhr.send()

link = document.createElement "link"
link.rel = "stylesheet"

if window.safari?.extension?
	link.href = safari.extension.baseURI + "popover.css"
	loadJSON safari.application.activeBrowserWindow.activeTab.url

else if window.chrome?.extension?
	link.href = chrome.extension.getURL "popover.css"
	chrome.tabs.getSelected null, (tab) ->
		loadJSON tab.url
		return

else
	console.info "INIT DEMOTRON"
	if window.location.hash == ""
		loadJSON "http://dribbble.com"
	else
		loadJSON "http://#{window.location.hash.substr(1)}"

document.head.appendChild link