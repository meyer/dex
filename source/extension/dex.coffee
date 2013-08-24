`<%= File.read File.join(EXT_SOURCE_DIR,'jquery-2.0.3.min.js') %>`
# Per-site config

console.log "Dex jQuery: #{$.fn.jquery}"
dexJQ = jQuery.noConflict(true)
console.log "Page jQuery: "+(if $? && $.fn? then "#{$.fn.jquery}" else 'none')

window.dex = new ->
	_cache = {}
	conf = false

	@utils =
		jquery: dexJQ

	@__defineSetter__ 'config', (configDict) ->
		conf = {}
		for m, fn of configDict
			do (m, fn) =>
				conf.__defineGetter__ m, ->
					console.log "#{m} is cached? #{_cache[m]?}"
					_cache[m] || _cache[m] = fn()
				conf.__defineSetter__ m, (s) ->
					console.log "Config object is read-only, cannot set #{m} to #{s}."

	@__defineGetter__ 'config', ->
		conf

	@

window.DexConfig = (getters) ->
	_cache = {}
	conf = {}

return