/* global chrome */
'use strict';

const {dexURL} = require('../package.json');

function setDexFileURLs(hostname, js, css) {
  const hostKey = `lastUpdated-${hostname}`;
  const opts = {};

  // Initial setup
  chrome.storage.local.get(hostKey, function (result) {
    opts[hostKey] = result[hostKey];

    if (!opts[hostKey]) {
      opts[hostKey] = Date.now();
      chrome.storage.local.set(opts, function() {
        console.log(`${hostKey} updated:`, opts[hostKey]);
      });
    }

    console.log(`DEX: ${hostKey}`, opts[hostKey]);

    js.src = `${dexURL}/${opts[hostKey]}/${hostname}.js`;
    css.href = `${dexURL}/${opts[hostKey]}/${hostname}.css`;
  });

  // Listen for config changes, live-update CSS
  chrome.runtime.onMessage.addListener(function(request, sender, sendResponse) {
    if (request[hostKey]) {
      opts[hostKey] = Date.now();

      css.href = `${dexURL}/${opts[hostKey]}/${hostname}.css`;

      chrome.storage.local.set(opts, function() {
        console.log(`Updated ${hostKey} to`, opts[hostKey]);
      });

      // Only send a response if the message is for us
      sendResponse({
        status: 'success',
        message: `Updated ${hostKey} to ${opts[hostKey]}`,
      });
    } else {
      console.info(`Ignoring message (not '${hostKey}'):`, request);
    }
  });

}

module.exports = setDexFileURLs;
