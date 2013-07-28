hostname = window.location.host.replace 'www.', ''
localhost = 'https://localhost:<%= DEX_PORT %>/'

# Stuff to load
script = document.createElement "script"
script.type = "text/javascript"
script.src = localhost + hostname + ".js"

link = document.createElement "link"
link.rel = "stylesheet"
link.href = localhost + hostname + ".css"

# Because DOMContentLoaded is too slow™
document.addEventListener "DOMNodeInserted", (e) ->
	if typeof(e.relatedNode.tagName) != "undefined"
		if e.relatedNode.tagName == 'BODY'
			this.removeEventListener 'DOMNodeInserted', arguments.callee, false

			document.body.appendChild script
			document.body.appendChild link