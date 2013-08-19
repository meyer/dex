selectedId = -1

setBadge = (badgeText) ->
	chrome.browserAction.setBadgeText
		"text": badgeText
		tabId: selectedId

chrome.tabs.onUpdated.addListener (tabId, props) ->
	if props.status == "complete" && tabId == selectedId
		setBadge tabId

chrome.tabs.onSelectionChanged.addListener (tabId, props) ->
	selectedId = tabId
	setBadge tabId

chrome.tabs.query {active: true, currentWindow: true}, (tabs) ->
	selectedId = tabs[0].id
	# url = tabs[0].url;
	setBadge tabs[0].id