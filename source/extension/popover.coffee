loadJSON = (url) ->
	console.log "URL: #{url}"
	# TODO: Use official method to detect invalid Chrome/Safari pages

	ignored = [
		"chrome://"
		"//localhost"
		"//127.0.0.1"
		".dev"
	]

	for str in ignored
		if ~url.indexOf(str)
			document.body.innerHTML = "<h1>Invalid page: matches <code>#{str}</code></h1>"
			return

	# Strip down to hostname
	url = url.split("://")[1].split("/")[0].replace(/^ww[w0-9]\./, "")
	jsonURL = "https://localhost:3131/#{url}.json"

	moduleList = _.template(
		document.getElementById("module-list-tpl").innerHTML
		null
		variable: "data"
	)

	xhr = new XMLHttpRequest()
	xhr.onreadystatechange = () ->
	if xhr.readyState == 4 && xhr.status == 200
		document.body.innerHTML = moduleList {
			modules: JSON.parse(xhr.responseText)
		}
		ul = document.getElementById("site-modules")

		ul.addEventListener "click", (e) ->
			console.log "You clicked on a '#{e.target.tagName}' tag"
			e.preventDefault()

	xhr.open(method, o.url, true)
	xhr.send()

link = document.createElement "link"
link.rel = "stylesheet"

if window.safari
	link.href = safari.extension.baseURI + "popover.css"
	loadJSON safari.application.activeBrowserWindow.activeTab.url

if window.chrome
	link.href = chrome.extension.getURL "popover.css"
	chrome.tabs.getSelected null, (tab) ->
		loadJSON tab.url, cssURL

document.head.appendChild link