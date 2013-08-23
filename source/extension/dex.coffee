console.log "Before: #{$.fn.jquery}"

window.dex =
	jquery: jQuery.noConflict true

console.log "After: #{window.dex.jquery.fn.jquery}"

window.dexfiles = {}

window.DexConfig = (getters) ->
	_cache = {}
	conf = {}
	for m, fn of getters
		do (m, fn) =>
			conf.__defineGetter__ m, ->
				console.log "Cached? #{_cache[m]?}"
				_cache[m] || _cache[m] = fn()
	conf