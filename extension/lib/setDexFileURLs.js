/* global chrome */

export default function setDexFileURLs(hostname, js, css) {
  const hostKey = `lastUpdated-${hostname}`
  const opts = {}

  // Initial setup
  chrome.storage.local.get(hostKey, function (result) {
    opts[hostKey] = result[hostKey]

    if (!opts[hostKey]) {
      opts[hostKey] = Date.now()
      chrome.storage.local.set(opts, function() {
        console.info(`${hostKey} updated:`, opts[hostKey])
      })
    }

    console.info(`DEX: ${hostKey}`, opts[hostKey])

    js.src = `${process.env.DEX_URL}/${opts[hostKey]}/${hostname}.js`
    css.href = `${process.env.DEX_URL}/${opts[hostKey]}/${hostname}.css`
  })

  // Listen for config changes, live-update CSS
  chrome.runtime.onMessage.addListener(function(request, sender, sendResponse) {
    if (request[hostKey]) {
      opts[hostKey] = Date.now()

      css.href = `${process.env.DEX_URL}/${opts[hostKey]}/${hostname}.css`

      chrome.storage.local.set(opts, function() {
        console.info(`Updated ${hostKey} to`, opts[hostKey])
      })

      // Only send a response if the message is for us
      sendResponse({
        status: 'success',
        message: `Updated ${hostKey} to ${opts[hostKey]}`,
      })
    } else {
      console.info(`Ignoring message (not '${hostKey}'):`, request)
    }
  })

}
