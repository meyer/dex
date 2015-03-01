loadModuleCallback = (data, error) ->
	if error
		console.error "loadModule error:", error
		return

	document.getElementById("refresh-data").addEventListener "click", (e) ->
		console.log "CLICK CLICK"
		e.preventDefault()
		e.stopPropagation()
		dexutils.sendMessageToBKG("refresh data")
		return

if window.safari?.application?
	dexutils.loadModuleListForURL(
		safari.application.activeBrowserWindow.activeTab.url,
		loadModuleCallback
	)

else if window.chrome?.tabs?
	chrome.tabs.getSelected null, (tab) ->
		dexutils.loadModuleListForURL(
			tab.url,
			loadModuleCallback
		)

else
	console.info "INIT DEMOTRON"
	document.addEventListener "DOMContentLoaded", (e) ->
		document.body.classList.add "demotron"

	if window.location.hash == ""
		dexutils.loadModuleListForURL(
			"http://dribbble.com",
			loadModuleCallback
		)

	else
		dexutils.loadModuleListForURL(
			"http://#{window.location.hash.substr(1)}",
			loadModuleCallback
		)