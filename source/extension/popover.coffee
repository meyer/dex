if window.safari?.application?
	dexutils.loadModuleListForURL safari.application.activeBrowserWindow.activeTab.url

else if window.chrome?.tabs?
	chrome.tabs.getSelected null, (tab) ->
		dexutils.loadModuleListForURL tab.url
		return

else
	console.info "INIT DEMOTRON"
	document.addEventListener "DOMContentLoaded", (e) ->
		document.body.classList.add "demotron"

	if window.location.hash == ""
		dexutils.loadModuleListForURL "http://dribbble.com"
	else
		dexutils.loadModuleListForURL "http://#{window.location.hash.substr(1)}"