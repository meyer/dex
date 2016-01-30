/* global chrome:true */
'use strict';

function updateTabStatus(tabID) {
  var e;
  try {
    chrome.tabs.get(tabID, function(tab) {
      var hostname, tabAction;
      console.log(`Tab ${tabID}:`, tab);
      hostname = window.dexutils.getValidHostname(tab.url);
      tabAction = hostname ? 'enable' : 'disable';
      if (!hostname) {
        chrome.browserAction.setIcon({
          tabId: tab.id,
          path: {
            19: 'toolbar-button-icon-chrome-disabled.png',
            38: 'toolbar-button-icon-chrome-disabled@2x.png',
          },
        });
      }
      console.log(`Tab action: ${tabAction}d tab (${hostname})`);
    });
  } catch (_error) {
    e = _error;
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
  if (~info.url.indexOf('<%= DEX_URL %>')) {
    //
  } else if (info.type === 'xmlhttprequest') {
    //
  } else if (info.type === 'main_frame') {
    //
  } else {
    console.log('[ ] ' + info.type);
    return;
  }

  console.log('[x] ' + info.type);
  const response = [];

  Object.keys(info.responseHeaders).forEach(function(header) {
    let headerName = info.responseHeaders[header].name;
    let headerVal = info.responseHeaders[header].value;

    switch (headerName.toLowerCase()) {
    case 'content-security-policy':
      response.push({
        name: headerName,
        value: headerVal.replace(/((?:script|style|default)-src(?: ['']self[''])?)/g, '$1 <%= DEX_URL %>'),
      });
      break;
    case 'content-security-policy-report-only':
      break;
    default:
      response.push(info.responseHeaders[header]);
    }
  });

  return {
    responseHeaders: response,
  };
}, {
  urls: ['http://*/*', 'https://*/*'],
}, [
  'responseHeaders', 'blocking',
]);
