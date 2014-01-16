cssURL = ''

loadURL = (url, cssURL) ->
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

	dexURL = "https://localhost:3131/#{url}.html?css=#{cssURL}"
	document.body.innerHTML = "<iframe src='#{dexURL}'></iframe>"

if window.safari
	cssURL = safari.extension.baseURI + 'popover.css'
	loadURL safari.application.activeBrowserWindow.activeTab.url, cssURL

if window.chrome
	cssURL = chrome.extension.getURL 'popover.css'
	chrome.tabs.getSelected null, (tab) ->
		loadURL tab.url, cssURL

console.log "CSS URL: #{cssURL}"