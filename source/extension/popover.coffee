cssURL = ''

loadURL = (url) ->
	console.log "URL: #{url}"
	# TODO: Use official method to detect invalid Chrome/Safari pages

	# ignored = [/chrome:\/\//,/\/\/localhost/,/\/\/127.0.0.1/, /\*.dev/]
	# for str in ignored
	# 	if url.match(str)
	# 		return

	return if ~url.indexOf('chrome://') || ~url.indexOf('//localhost') || ~url.indexOf('//127.0.0.1') || ~url.indexOf('.dev')

	# Strip down to hostname
	url = url.split('://')[1].split('/')[0]

	# Remove www
	url = url.replace /^www\./, ''

	dexURL = "https://localhost:3131/#{url}.html"
	document.body.innerHTML = "<iframe src='#{dexURL}'></iframe>"

if window.safari
	cssURL = safari.extension.baseURI + 'popover.css'
	loadURL safari.application.activeBrowserWindow.activeTab.url

if window.chrome
	cssURL = chrome.extension.getURL 'popover.css'
	chrome.tabs.getSelected null, (tab) ->
		loadURL tab.url

console.log "CSS URL: #{cssURL}"