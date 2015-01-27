loadModuleListForURL = (url) ->
	unless hostname = utils.getValidHostname(url)
		console.error "loadModuleListForURL cannot continue: URL is invalid (#{url})"
		return

	jsonURL = "https://localhost:3131/#{hostname}.json"
	moduleListTpl = _.template document.getElementById("module-list-tpl").innerHTML

	utils.getJSON jsonURL, (data, error) ->
		# TODO: Deal with dexd failures
		return if error?

		data.json_url = jsonURL
		data.hostname = hostname

		document.body.innerHTML = moduleListTpl(data)

		document.body.addEventListener "change", (e) ->
			unless e.target.dataset.href?
				console.error "Element #{e.target.tagName} is missing data-href attribute"
				return

			utils.getJSON e.target.dataset.href, (moduleData) ->
				[action, module] = moduleData
				console.log "#{module}: #{action}, checked: #{e.target.checked}"

if window.safari?.application?
	loadModuleListForURL safari.application.activeBrowserWindow.activeTab.url

else if window.chrome?.tabs?
	chrome.tabs.getSelected null, (tab) ->
		loadModuleListForURL tab.url
		return

else
	console.info "INIT DEMOTRON"
	if window.location.hash == ""
		loadModuleListForURL "http://dribbble.com"
	else
		loadModuleListForURL "http://#{window.location.hash.substr(1)}"