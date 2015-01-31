window.dexutils = {}

###
Universal Methods
###
window.dexutils.getValidHostname = (url) ->
	return false unless url? and url isnt ""

	a = document.createElement("a")
	a.href = url

	# Only match http/https
	if !~["http:", "https:"].indexOf(a.protocol)
		console.error "Only HTTP and HTTPS protocols are supported"
		false

	# Require a dot in the URL
	else if !~a.hostname.indexOf(".")
		console.error "Hostname `#{a.hostname}` is invalid (no dot)"

	# Match everything but IP addresses and .dev URLs
	else if a.hostname.match(/^.+\.(\d+|dev)$/)
		console.error "Hostname `#{a.hostname}` is invalid (ip/dev)"
		false

	else
		# Clean up that hostname
		a.hostname.replace(/^ww[w\d]\./, "")

window.dexutils.getJSON = (url, callback) ->
	try
		xhr = new XMLHttpRequest()
		xhr.open "GET", url, true

		xhr.onreadystatechange = ->
			if xhr.readyState == 4
				if xhr.status == 200
					responseJSON = {}

					try
						responseJSON = JSON.parse xhr.responseText
					catch error
						console.error "Error parsing response JSON: `#{xhr.responseText}`"
						console.info error

					callback?(responseJSON)
				else
					callback?({}, true)

		xhr.send()
	catch e
		console.error "Weird XHR error:", e
		callback?({}, "Error: #{e}")

	return

bodySwap = (guts) ->
	tempDiv = document.createElement "div"
	tempDiv.style.visibility = "hidden"
	tempDiv.style.position = "absolute"
	tempDiv.style.top = 0
	tempDiv.style.left = 0
	tempDiv.innerHTML = guts
	document.body.appendChild tempDiv

	if safari?.self?.height?
		safari.self.height = tempDiv.clientHeight
		console.log "Set popover height (#{safari.self.height})"

	document.body.innerHTML = tempDiv.innerHTML
	tempDiv.remove()

window.dexutils.loadModuleListForURL = (url) ->
	unless hostname = dexutils.getValidHostname(url)
		console.error "URL is invalid (#{url})"

		loadEmpty = ->
			emptyTpl = _.template(document.getElementById("module-list-empty").innerHTML)
			bodySwap emptyTpl {url}

		if document.body?
			loadEmpty()
		else
			document.addEventListener "DOMContentLoaded", loadEmpty

		return

	jsonURL = "<%= DEX_URL %>/#{hostname}.json"
	moduleListTpl = _.template(document.getElementById("module-list-tpl").innerHTML)

	dexutils.getJSON jsonURL, (data, error) ->
		# TODO: Deal with dexd failures
		return if error?

		data.hostname = hostname
		bodySwap moduleListTpl data

		document.body.addEventListener "change", (e) ->
			unless e.target.dataset.module?
				console.error "Element #{e.target.tagName} is missing data-href attribute"
				return

			dexutils.getJSON "#{jsonURL}?toggle=#{e.target.dataset.module}", (moduleData) ->
				if moduleData.length? && moduleData.length == 2
					[action, module] = moduleData
					console.log "#{module}: #{action}, checked: #{e.target.checked}"
				else
					console.error "Expected a two-element array, got something funky instead:", moduleData

	return