'use strict';

(function() {
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

  const dexURL = 'https://localhost:3131/';

  const hostJS = document.createElement('script');
  const hostCSS = document.createElement('link');
  const globalJS = document.createElement('script');
  const globalCSS = document.createElement('link');

  hostCSS.rel = 'stylesheet';
  globalCSS.rel = 'stylesheet';
  hostJS.src = `${dexURL}123456/${window.location.hostname}.js`;
  hostCSS.href = `${dexURL}654321/${window.location.hostname}.css`;
  globalJS.src = `${dexURL}1234/global.js`;
  globalCSS.href = `${dexURL}4321/global.css`;

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
      return this.removeEventListener('DOMNodeInserted', insertDexfiles, false);
    }
  }

  document.addEventListener('DOMNodeInserted', insertDexfiles);

})();
