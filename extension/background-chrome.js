/* global chrome:true */

import getValidHostname from './lib/getValidHostname'
import {dexURL} from './package.json'

function updateTabStatus(tabID) {
  try {
    chrome.tabs.get(tabID, function(tab) {
      console.info(`Tab ${tabID}:`, tab)

      const hostname = getValidHostname(tab.url)
      const tabAction = hostname ? 'enable' : 'disable'

      if (!hostname) {
        chrome.browserAction.setIcon({
          tabId: tab.id,
          path: {
            19: 'assets/toolbar-button-icon-chrome-disabled.png',
            38: 'assets/toolbar-button-icon-chrome-disabled@2x.png',
          },
        })
      }
      console.info(`Tab action: ${tabAction}d tab (${hostname})`)
    })
  } catch (e) {
    console.error('updateTabStatus error:', e)
  }
}

chrome.tabs.onUpdated.addListener(function(tabID, props) {
  if (props.status === 'loading') {
    updateTabStatus(tabID)
  }
})

chrome.tabs.onSelectionChanged.addListener(function(tabID, props) {
  console.info('onSelectionChanged:', props)
  updateTabStatus(tabID)
})

/*

Twitter's CSP

script-src https://connect.facebook.net https://cm.g.doubleclick.net https://ssl.google-analytics.com https://graph.facebook.com https://twitter.com 'unsafe-eval' https://*.twimg.com https://api.twitter.com https://analytics.twitter.com https://ton.twitter.com https://syndication.twitter.com https://www.google.com https://t.tellapart.com https://platform.twitter.com https://www.google-analytics.com 'nonce-jGOYl3F7fNAnl7FiR9FqMQ==' 'self';

frame-ancestors 'self'; font-src https://twitter.com https://*.twimg.com data: https://ton.twitter.com https://fonts.gstatic.com https://maxcdn.bootstrapcdn.com https://netdna.bootstrapcdn.com 'self';

media-src https://twitter.com https://*.twimg.com https://ton.twitter.com blob: 'self';

connect-src https://graph.facebook.com https://media4.giphy.com https://media0.giphy.com https://pay.twitter.com https://analytics.twitter.com https://media.riffsy.com https://media.giphy.com https://media3.giphy.com https://upload.twitter.com https://media2.giphy.com https://media1.giphy.com 'self';

style-src https://fonts.googleapis.com https://twitter.com https://*.twimg.com https://translate.googleapis.com https://ton.twitter.com 'unsafe-inline' https://platform.twitter.com https://maxcdn.bootstrapcdn.com https://netdna.bootstrapcdn.com 'self';

object-src https://twitter.com https://pbs.twimg.com;

default-src 'self';

frame-src https://staticxx.facebook.com https://twitter.com https://*.twimg.com https://player.vimeo.com https://pay.twitter.com https://www.facebook.com https://ton.twitter.com https://syndication.twitter.com https://vine.co twitter: https://www.youtube.com https://platform.twitter.com https://upload.twitter.com https://s-static.ak.facebook.com 'self' https://donate.twitter.com;

img-src https://graph.facebook.com https://twitter.com https://*.twimg.com https://media4.giphy.com data: https://media0.giphy.com https://fbcdn-profile-a.akamaihd.net https://www.facebook.com https://ton.twitter.com https://*.fbcdn.net https://syndication.twitter.com https://media.riffsy.com https://www.google.com https://media.giphy.com https://stats.g.doubleclick.net https://media3.giphy.com https://www.google-analytics.com blob: https://media2.giphy.com https://media1.giphy.com 'self';

report-uri https://twitter.com/i/csp_report?a=NVQWGYLXFVZXO2LGOQ%3D%3D%3D%3D%3D%3D&ro=false;

*/

// https://w3c.github.io/webappsec-csp/#parse-serialized-policy
function addDexToCSP (cspStr) {
  return cspStr.split(';').map(function(csp) {
    csp = csp.trim()
    // TODO: check for 'none'? maybe?
    const cspBits = csp.trim().split(' ')
    if (~['script-src', 'style-src', 'default-src'].indexOf(cspBits[0])) {
      cspBits.push(dexURL)
    }
    return cspBits.join(' ')
  }).join('; ')
}

chrome.webRequest.onHeadersReceived.addListener(function(info) {
  // if (~info.url.indexOf(dexURL)) {
  //   //
  // } else if (info.type === 'xmlhttprequest') {
  //   //
  // } else if (info.type === 'main_frame') {
  //   //
  // // } else if (info.type === 'sub_frame') {
  //   //
  // } else {
  //   console.info('[ ]', info.type);
  //   return;
  // }

  if (info.type !== 'main_frame') {
    console.info('[ ]', info.type)
    return
  }

  console.info('[x]', info.type)
  const responseHeaders = []

  Object.keys(info.responseHeaders).forEach(function(header) {
    const headerName = info.responseHeaders[header].name
    const headerVal = info.responseHeaders[header].value

    switch (headerName.toLowerCase()) {
    case 'content-security-policy':
      responseHeaders.push({
        name: headerName,
        value: addDexToCSP(headerVal),
      })
      break

    case 'content-security-policy-report-only':
      break

    default:
      responseHeaders.push(info.responseHeaders[header])
    }
  })

  return {responseHeaders}
}, {
  urls: ['http://*/*', 'https://*/*'],
}, [
  'responseHeaders', 'blocking',
])
