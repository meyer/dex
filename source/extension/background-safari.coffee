updateTabStatus = (e) ->
	console.log "updateTabStatus:", e

# Reload the popover
safari.application.addEventListener "popover", (e) ->
	# TODO: Fix this.
	# safari.extension.popovers[0].contentWindow.dexutils.loadModuleListForURL("http://google.com")
	console.log e

safari.application.addEventListener "activate", updateTabStatus
safari.application.addEventListener "validate", updateTabStatus
safari.application.addEventListener "popover", updateTabStatus