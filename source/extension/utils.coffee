window.utils =
	getValidHostname: (url) ->
		return false unless url? and url isnt ""

		a = document.createElement("a")
		a.href = url

		# Only match http/https
		if !~["http:", "https:"].indexOf(a.protocol)
			console.error "Only HTTP and HTTPS protocols are supported"
			false

		# Match everything but IP addresses and .dev URLs
		else if a.hostname.match(/^.+\.(\d+|dev)$/)
			console.error "Hostname `#{a.hostname}` is invalid"
			false

		else
			# Clean up that hostname
			a.hostname.replace(/^ww[w\d]\./, "")

	getJSON: (url, callback) ->
		xhr = new XMLHttpRequest()
		xhr.open "GET", url, true

		xhr.onreadystatechange = ->
			if xhr.readyState == 4
				if xhr.status == 200
					try
						responseJSON = JSON.parse xhr.responseText
						callback?(responseJSON)
					catch error
						console.error "Error parsing response JSON"
						console.error "xhr.responseText is blank" if xhr.responseText == ""
						console.info error
						callback?({}, error)
				else
					callback?({}, "Error: status code 200 expected, received #{xhr.status}")

		xhr.send()