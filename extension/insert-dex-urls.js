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

  const globalJS = document.createElement('script')
  const globalCSS = document.createElement('link')
  const hostJS = document.createElement('script')
  const hostCSS = document.createElement('link')

  globalCSS.rel = 'stylesheet'
  hostCSS.rel = 'stylesheet'

  document.documentElement.appendChild(globalJS)
  document.documentElement.appendChild(globalCSS)
  document.documentElement.appendChild(hostJS)
  document.documentElement.appendChild(hostCSS)

  setDexFileURLs(hostname, hostJS, hostCSS)
  setDexFileURLs('global', globalJS, globalCSS)

})()
