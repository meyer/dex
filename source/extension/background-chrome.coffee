updateTabStatus = (tabID) ->
	try
		# Option B: get current tab
		chrome.tabs.get tabID, (tab) ->
			console.log "Tab #{tabID}:", tab

			hostname = window.dexutils.getValidHostname(tab.url)
			tabAction = if hostname then "enable" else "disable"

			unless hostname
				chrome.browserAction.setIcon
					tabId: tab.id
					path:
						19: "toolbar-button-icon-chrome-disabled.png"
						38: "toolbar-button-icon-chrome-disabled@2x.png"

			# chrome.browserAction[tabAction] tabID

			console.log "Tab action: #{tabAction}d tab (#{hostname})"
	catch e
		console.error "updateTabStatus error:", e

# Fired when page is refreshed
chrome.tabs.onUpdated.addListener (tabID, props) ->
	if props.status == "loading"
		updateTabStatus tabID

# Fired when different tab is selected
chrome.tabs.onSelectionChanged.addListener (tabID, props) ->
	console.log "onSelectionChanged:", props
	updateTabStatus tabID

###
chrome.tabs.onActivated.addListener (e) ->
	console.log "onActivated:", e
	updateTabStatus e.tabId
###

# Modify Content-Security-Policy header to allow extension assets
chrome.webRequest.onHeadersReceived.addListener(
	(info) -> (
		if ~info.url.indexOf("<%= DEX_URL %>")
		else if info.type == "xmlhttprequest"
		else if info.type == "main_frame"
		else
			console.log "[ ] #{info.type}"
			return

		console.log "[x] #{info.type}"

		response = []
		for header of info.responseHeaders
			headerName = info.responseHeaders[header].name
			headerVal = info.responseHeaders[header].value

			switch headerName.toLowerCase()
				when "content-security-policy"
					v = info.responseHeaders[header].value.replace(/((?:script|style|default)-src(?: ['"]self['"])?)/g, "$1 <%= DEX_URL %>")

					response.push
						name: info.responseHeaders[header].name
						value: v
				when "content-security-policy-report-only"
					# nah
				else
					response.push info.responseHeaders[header]

		responseHeaders: response
	),

	{
		urls: [
			"http://*/*"
			"https://*/*"
		]
	},

	[
		"responseHeaders"
		"blocking"
	]
)