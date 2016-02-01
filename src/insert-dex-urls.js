'use strict';

(function() {

  const config = require('../config');
  const {getValidHostname} = require('./_utils');
  let asapLoaded, bodyLoaded;

  // Check for iframes
  if (window.self !== window.top) {
    if (window.self.location.hostname !== window.top.location.hostname) {
      console.groupCollapsed('Ignoring iframe:', window.self.location.hostname);
      console.log(window.self.location.href);
      console.groupEnd();
      return;
    }
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
  hostJS.src = `${config.dexURL}123456/${hostname}.js`;
  hostCSS.href = `${config.dexURL}654321/${hostname}.css`;
  globalJS.src = `${config.dexURL}1234/global.js`;
  globalCSS.href = `${config.dexURL}4321/global.css`;

  function insertDexfiles(e) {
    let headOrBody;
    if (!e.relatedNode.tagName) {
      return;
    }

    if (!asapLoaded && (headOrBody = document.head || document.body)) {
      asapLoaded = true;
      headOrBody.appendChild(globalCSS);
      headOrBody.appendChild(hostCSS);
    }

    if (!bodyLoaded && document.body) {
      bodyLoaded = true;
      document.body.appendChild(globalJS);
      document.body.appendChild(hostJS);
    }

    if (asapLoaded && bodyLoaded) {
      document.removeEventListener('DOMNodeInserted', insertDexfiles, false);
    }
  }

  document.addEventListener('DOMNodeInserted', insertDexfiles);

})();
