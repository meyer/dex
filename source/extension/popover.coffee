if window.safari?.application?
	dexutils.loadModuleListForURL safari.application.activeBrowserWindow.activeTab.url
	# TODO: Fix this.
	document.addEventListener "DOMContentLoaded", (e) ->
		console.log "DOMContentLoaded test"
		console.log "Body height: #{document.body.clientHeight}"
		safari.self.height = document.body.clientHeight

else if window.chrome?.tabs?
	chrome.tabs.getSelected null, (tab) ->
		dexutils.loadModuleListForURL tab.url
		return

else
	console.info "INIT DEMOTRON"
	if window.location.hash == ""
		dexutils.loadModuleListForURL "http://dribbble.com"
	else
		dexutils.loadModuleListForURL "http://#{window.location.hash.substr(1)}"