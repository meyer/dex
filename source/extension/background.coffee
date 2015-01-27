selectedID = -1
currentPageURL = ""
cachedValue = 0

# Events
if window.safari
	# Reload the popover
	safari.application.addEventListener "popover", ->
		safari.extension.popovers[0].contentWindow.location.reload()


else if window.chrome
	# Modify Content-Security-Policy header to allow extension assets
	chrome.webRequest.onHeadersReceived.addListener(
		(info) -> (
			response = []
			for header of info.responseHeaders
				headerName = info.responseHeaders[header].name
				headerVal = info.responseHeaders[header].value

				switch headerName.toLowerCase()
					when "content-security-policy"
						v = info.responseHeaders[header].value.replace(/((?:script|default)-src(?: ['"]self['"])?)/g, "$1 <%= DEX_URL %>")
						console.log "CSP: #{v}"
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