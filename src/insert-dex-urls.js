/* global chrome */
'use strict';

(function() {

  const {dexURL} = require('../package.json');
  const {getValidHostname} = require('./_utils');
  let asapLoaded, bodyLoaded;

  if (window.self !== window.top) {
    console.groupCollapsed('Ignoring iframe:', window.self.location.toString());
    console.log(window.self.location.href);
    console.groupEnd();
    return;
  }

  const hostname = getValidHostname(window.location.href);

  if (!hostname) {
    return;
  }

  const hostJS = document.createElement('script');
  const hostCSS = document.createElement('link');
  const globalJS = document.createElement('script');
  const globalCSS = document.createElement('link');

  hostCSS.rel = 'stylesheet';
  globalCSS.rel = 'stylesheet';

  function insertDexfiles(e) {
    if (!e.relatedNode.tagName) {
      console.log('relatedNode.tagName is not set', e);
      return;
    }

    if (!asapLoaded && document.documentElement) {
      asapLoaded = true;
      console.log('Appending dex CSS to html');
      document.documentElement.appendChild(globalCSS);
      document.documentElement.appendChild(hostCSS);
    }

    if (!bodyLoaded && document.body) {
      bodyLoaded = true;
      console.log('Appending dex JS to body');
      document.body.appendChild(globalJS);
      document.body.appendChild(hostJS);
    }

    if (asapLoaded && bodyLoaded) {
      document.removeEventListener('DOMNodeInserted', insertDexfiles, false);
    }
  }

  document.addEventListener('DOMNodeInserted', insertDexfiles);

  chrome.storage.local.get('lastModified', function (result) {
    let lastModified = result.lastModified;

    if (!lastModified) {
      lastModified = Date.now();
      chrome.storage.local.set({lastModified}, function() {
        console.log('lastModified updated');
      });
    }

    console.log('Last modified:', lastModified);
    console.log('Loading Dex CSS/JS...');

    hostJS.src = `${dexURL}${lastModified}/${hostname}.js`;
    hostCSS.href = `${dexURL}${lastModified}/${hostname}.css`;
    globalJS.src = `${dexURL}${lastModified}/global.js`;
    globalCSS.href = `${dexURL}${lastModified}/global.css`;
  });

  chrome.runtime.onMessage.addListener(function(request, sender, sendResponse) {
    if (sender.tab) {
      console.log('from a content script:', sender.tab.url);
    } else {
      console.log('from a URL');
    }

    console.log(request, sender);

    if (request.updateLastModified) {
      const lastModified = Date.now();

      hostCSS.href = `${dexURL}${lastModified}/${hostname}.css`;
      globalCSS.href = `${dexURL}${lastModified}/global.css`;

      sendResponse({
        status: 'success',
        message: `Updated lastModified to ${lastModified}`,
      });

      chrome.storage.local.set({lastModified}, function() {
        console.log('Updated lastModified');
      });
    } else {
      console.log('Nope');
      sendResponse({
        status: 'error',
        message: 'Nothing happened here.',
      });
    }
  });

})();
