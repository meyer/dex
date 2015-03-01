updateTabStatus = (tabID) ->
	try
		# Option B: get current tab
		chrome.tabs.get tabID, (tab) ->
			hostname = window.dexutils.getValidHostname(tab.url)
			tabAction = if hostname then "enable" else "disable"

			unless hostname
				chrome.browserAction.setIcon
					tabId: tab.id
					path:
						19: "toolbar-button-icon-chrome-disabled.png"
						38: "toolbar-button-icon-chrome-disabled@2x.png"

			# chrome.browserAction[tabAction] tabID

			# console.log "Tab action: #{tabAction}d tab (#{hostname})"
	catch e
		console.error "updateTabStatus error:", e

# Fired when page is refreshed
chrome.tabs.onUpdated.addListener (tabID, props) ->
	console.log "Tab #{tabID}: chrome.tabs.onUpdated, { status: '#{props.status}' }"

	switch props.status
		when "loading"
			#chrome.storage.local.get "dexData", (res) ->
			#	if !res.dexData
			#		console.error "Dex cache has not been built yet!"
			#
			#	chrome.tabs.get tabID, (tab) ->
			#		hostname = window.dexutils.getValidHostname(tab.url)
			#		if !hostname
			#			console.error "Tab #{tabID}: Invalid hostname for #{tab.url}"
			#			return
			#
			#		{css, js} = dexutils.getDataForHostname(hostname, res.dexData)
			#
			#		console.info "Injecting CSS and JS into #{tab.url} (#{props.status})"
			#		dexutils.injectJS tabID, js
			#		dexutils.injectCSS tabID, css

			updateTabStatus tabID

# Fired when different tab is selected
chrome.tabs.onSelectionChanged.addListener (tabID, props) ->
	# console.log "onSelectionChanged:", props
	updateTabStatus tabID

chrome.tabs.onActivated.addListener (e) ->
	# console.log "UPDATE: tab activated", e
	# updateTabStatus e.tabId

cspListener = (info) ->
	if ~info.url.indexOf("<%= DEX_URL %>")
	else if info.type == "xmlhttprequest"
	else if info.type == "main_frame"
	else
		# console.log "[ ] #{info.type}"
		return

	# console.log "[x] #{info.type}"

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

# Modify Content-Security-Policy header to allow extension assets
chrome.webRequest.onHeadersReceived.addListener(
	cspListener,

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

# No practical use for this yet
chrome.storage.onChanged.addListener (changes, namespace) ->
	for key in changes
		storageChange = changes[key]
		console.log('Storage key "%s" in namespace "%s" changed. Old value was "%s", new value is "%s".',
			key,
			namespace,
			storageChange.oldValue,
			storageChange.newValue
		)

window.dexutils.listenForBKGMessage "refresh data", (res) ->
	chrome.storage.local.get "dexData", (itemDict) ->
		console.log "Old Dex data:", itemDict.dexData

	window.dexutils.getJSON "<%= DEX_URL %>/getdata", (jsonData, err) ->
		if !jsonData
			console.error "#{err}"
			return

		console.log "Writing Dex data to localstorage", jsonData
		chrome.storage.local.set {"dexData": jsonData}

	console.log "Reloading data", res

# chrome.storage.local.set key: value
# chrome.storage.local.get key, (itemDict) -> itemDict
# chrome.storage.local.remove key