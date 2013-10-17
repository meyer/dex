selectedID = -1
currentPageURL = ''
cachedValue = 0

getHostnameFromURL = (url) ->
	url = url.split('//')[1] if ~url.indexOf('//')
	url = url.split('/')[0]
	url = url.replace /^www\./, ''
	return url

isForbiddenURL = (url) ->
	!url || ~url.indexOf('//localhost') || ~url.indexOf('//127.0.0.1') || ~url.indexOf('chrome://') || ~url.indexOf('chrome-extension://')

updateBadgeCount = (badgeText) ->
	if window.chrome
		chrome.tabs.query {active: true, currentWindow: true}, (tabs) ->
			tab = tabs[0]
			currentPageURL = tab.url

			console.log 'selectedID == tab.id' if selectedID == tab.id
			selectedID = tab.id

			if isForbiddenURL tab.url
				console.log "Disable tab: #{tab.url}"
				chrome.browserAction.disable tab.id
				badgeText = ''
			else
				console.log "Enable tab: #{tab.url}"
				chrome.browserAction.enable tab.id

			chrome.browserAction.setBadgeText
				"text": badgeText
				tabId: tab.id

	if window.safari
		currentPageURL = safari.application.activeBrowserWindow.activeTab.url

		for item in safari.extension.toolbarItems
			break if item.identifier != "DexToolbarItem"

			item.disabled = isForbiddenURL item.browserWindow.activeTab.url
			badgeText = 0
			badgeText = item.browserWindow.activeTab.url.length if !item.disabled
			item.badge = badgeText if 'badge' of item

	console.log "Updated badge text to #{badgeText}"
	return

getBadgeCount = (url) ->
	hostname = getHostnameFromURL url
	returnValue = 0
	if hostname
		xhr = new XMLHttpRequest();
		xhr.onload = ->
			console.log this.responseText
			console.log JSON.parse this.responseText
			JSON.parse this.responseText

		xhr.open "get", "<%= DEX_URL %>/#{hostname}.json", true
		xhr.send()
	else


# Events
if window.safari
	# Fired when the menubar button is clicked
	popoverHandler = (e) ->
		safari.extension.popovers[0].contentWindow.location.reload()

	# Fired when new tab/window is focused
	activateHandler = (e) ->
		# updateBadgeCount(Math.floor(Math.random()*100))
		console.log "ACTIVATE"

	safari.application.addEventListener "popover", popoverHandler, true
	safari.application.addEventListener "activate", activateHandler, true
	safari.application.addEventListener "validate", activateHandler, true

if window.chrome
	# Fired when page is refreshed
	chrome.tabs.onUpdated.addListener (tabID, props) ->
		if props.status == "complete" && tabID == selectedID
			console.log "New page loaded (#{tabID})"
		else
			console.log "HALP (#{tabID})"
		# updateBadgeCount tabID

	# Fired when tab is changed
	chrome.tabs.onSelectionChanged.addListener (tabID, props) ->
		console.log "Tab changed from #{selectedID} to #{tabID}."
		# updateBadgeCount tabID

	# Fired when different tab is loaded
	chrome.tabs.onActivated.addListener (e, props) ->
		console.log "onActivated: #{e.tabId}"
		# updateBadgeCount e.tabId