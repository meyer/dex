setBadgeCount = (badgeText) ->
	if oldTabID == selectedID
		console.log "Already set tab #{selectedID}"
		return
	selectedID = oldTabID

	if window.chrome
		console.log 'SET BADGE IN CHROME'
		chrome.browserAction.setBadgeText
			"text": badgeText+''
			tabId: selectedID

	if window.safari
		console.log 'SET BADGE IN SAFARI'

	return

selectedID = -1
oldTabID = -1


if window.safari

	console.log "URL: #{safari.application.activeBrowserWindow.activeTab.url}"

	# Fired when the button is clicked
	popoverHandler = (e) ->
		console.log "POPOVER: #{e.target.identifier}"
		safari.extension.popovers[0].contentWindow.location.reload()

	# Fired when new tab/window is focused
	activateHandler = (e) ->
		console.log "ACTIVATE"

	safari.application.addEventListener "popover", popoverHandler, true
	safari.application.addEventListener "activate", activateHandler, true

else if window.chrome

	chrome.tabs.onUpdated.addListener (tabID, props) ->
		if props.status == "complete" && tabID == selectedID
			console.log "New page loaded"
			setBadgeCount tabID

	chrome.tabs.onSelectionChanged.addListener (tabID, props) ->
		console.log "Tab changed from #{oldTabID} to #{tabID}."
		setBadgeCount tabID

	chrome.tabs.onActivated.addListener (e, props) ->
		console.log "onActivated: #{e.tabId}"

	chrome.tabs.query {active: true, currentWindow: true}, (tabs) ->
		console.log 'TAB QUERY'
		setBadgeCount tabs[0].id