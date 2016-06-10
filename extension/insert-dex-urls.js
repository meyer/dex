import getValidHostname from './lib/getValidHostname'
import setDexFileURLs from './lib/setDexFileURLs'

(function() {

  if (window.self !== window.top) {
    console.groupCollapsed('Ignoring iframe')
    console.info(window.self.location.href)
    console.groupEnd()
    return
  }

  const hostname = getValidHostname(window.location.href)

  if (!hostname) {
    return
  }

  const hostJS = document.createElement('script')
  const globalJS = document.createElement('script')
  const hostCSS = document.createElement('link')
  const globalCSS = document.createElement('link')

  hostCSS.rel = 'stylesheet'
  globalCSS.rel = 'stylesheet'

  document.documentElement.appendChild(hostJS)
  document.documentElement.appendChild(globalJS)
  document.documentElement.appendChild(hostCSS)
  document.documentElement.appendChild(globalCSS)

  setDexFileURLs(hostname, hostJS, hostCSS)
  setDexFileURLs('global', globalJS, globalCSS)

})()
