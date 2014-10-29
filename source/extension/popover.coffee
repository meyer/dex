loadJSON = (url) ->
	# TODO: Use official method to detect invalid Chrome/Safari pages

	ignored = [
		"chrome://"
		"chrome-extension://"
		"//localhost"
		"//127.0.0.1"
		".dev"
	]

	for str in ignored
		if ~url.indexOf(str)
			console.error "INVALID PAGE: starts with #{str}"
			document.body.innerHTML = "<h1>Invalid page: matches <code>#{str}</code></h1>"
			return

	# Strip down to hostname
	url = url.split("://")[1].split("/")[0].replace(/^ww[w0-9]\./, "")

	unless url.match /^[\w\-_.]+\.\w{2,}$/
		document.body.innerHTML = "<h1>Invalid URL: <code>#{url}</code></h1>"
		return

	jsonURL = "https://localhost:3131/#{url}.json"

	moduleList = _.template(
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

			document.body.innerHTML = moduleList moduleJSON
			ul = document.getElementById("site-modules")

			ul.addEventListener "click", (e) ->
				# Link?
				if e.target.tagName == "A"
					li = e.target.parentNode
					xhr2 = new XMLHttpRequest()
					xhr2.open "GET", e.target.href, true
					xhr2.onreadystatechange = ->
						if xhr2.readyState == 4 && xhr2.status == 200
							[action, module] = JSON.parse xhr2.responseText
							console.log "#{module}: #{action}"
							if action == "disabled"
								li.classList.add "disabled"
							else
								li.classList.remove "disabled"

					xhr2.send()

					e.preventDefault()

	xhr.send()

link = document.createElement "link"
link.rel = "stylesheet"

if window.safari
	link.href = safari.extension.baseURI + "popover.css"
	loadJSON safari.application.activeBrowserWindow.activeTab.url

if window.chrome
	link.href = chrome.extension.getURL "popover.css"
	chrome.tabs.getSelected null, (tab) ->
		loadJSON tab.url
		return

document.head.appendChild link