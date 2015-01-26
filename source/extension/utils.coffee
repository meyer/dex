window.utils =
	getValidHostname: (url) ->
		return false unless url? and url != ""

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

		else a.hostname

	getJSON: (url, callback) ->
		xhr = new XMLHttpRequest()
		xhr.open "GET", url, true

		xhr.onreadystatechange = ->
			if xhr.readyState == 4 && xhr.status == 200
				try
					responseJSON = JSON.parse xhr.responseText
					callback?(responseJSON)
				catch caughtError
					console.error "Error parsing response JSON"
					console.error "xhr.responseText is blank" if xhr.responseText == ""
					console.info caughtError
					callback?({}, caughtError)

		xhr.send()