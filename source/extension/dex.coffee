
window.dex = new ->
	_cache = {}
	conf = false

	@utils =
		ajax: (o, callback) ->
			data = o.data if "data" in o else {}
			method = o.type if "type" in o else "POST"

			xmlhttp = new XMLHttpRequest()
			xmlhttp.onreadystatechange = () ->
			if xmlhttp.readyState == 4 && xmlhttp.status == 200
				callback(xmlhttp.responseText)

			xmlhttp.open(method, o.url, true)
			xmlhttp.send()

	@__defineSetter__ "config", (configDict) ->
		conf = {}
		for m, fn of configDict
			do (m, fn) =>
				conf.__defineGetter__ m, ->
					console.log "#{m} is cached? #{_cache[m]?}"
					_cache[m] || _cache[m] = fn()
				conf.__defineSetter__ m, (s) ->
					console.log "Config object is read-only, cannot set #{m} to #{s}."

	@__defineGetter__ "config", ->
		conf

	@

return