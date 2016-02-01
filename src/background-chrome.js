/* global chrome:true */
'use strict';

const {getValidHostname} = require('./_utils');
const config = require('../config');

function updateTabStatus(tabID) {
  try {
    chrome.tabs.get(tabID, function(tab) {
      console.log(`Tab ${tabID}:`, tab);

      const hostname = getValidHostname(tab.url);
      const tabAction = hostname ? 'enable' : 'disable';

      if (!hostname) {
        chrome.browserAction.setIcon({
          tabId: tab.id,
          path: {
            19: 'assets/toolbar-button-icon-chrome-disabled.png',
            38: 'assets/toolbar-button-icon-chrome-disabled@2x.png',
          },
        });
      }
      console.log(`Tab action: ${tabAction}d tab (${hostname})`);
    });
  } catch (e) {
    console.error('updateTabStatus error:', e);
  }
}

chrome.tabs.onUpdated.addListener(function(tabID, props) {
  if (props.status === 'loading') {
    updateTabStatus(tabID);
  }
});

chrome.tabs.onSelectionChanged.addListener(function(tabID, props) {
  console.log('onSelectionChanged:', props);
  updateTabStatus(tabID);
});

chrome.webRequest.onHeadersReceived.addListener(function(info) {
  if (~info.url.indexOf(config.dexURL)) {
    //
  } else if (info.type === 'xmlhttprequest') {
    //
  } else if (info.type === 'main_frame') {
    //
  } else {
    console.log('[ ]', info.type);
    return;
  }

  console.log('[x]', info.type);
  const responseHeaders = [];

  Object.keys(info.responseHeaders).forEach(function(header) {
    const headerName = info.responseHeaders[header].name;
    const headerVal = info.responseHeaders[header].value;

    switch (headerName.toLowerCase()) {
    case 'content-security-policy':
      responseHeaders.push({
        name: headerName,
        value: headerVal.replace(/((?:script|style|default)-src(?: ['"]self['"])?)/g, `$1 ${config.dexURL}`),
      });
      break;

    case 'content-security-policy-report-only':
      break;

    default:
      responseHeaders.push(info.responseHeaders[header]);
    }
  });

  return {responseHeaders};
}, {
  urls: ['http://*/*', 'https://*/*'],
}, [
  'responseHeaders', 'blocking',
]);
