import getValidHostname from '../lib/getValidHostname';
import setDexFileURLs from '../lib/setDexFileURLs';

(function() {

  if (window.self !== window.top) {
    console.groupCollapsed('Ignoring iframe');
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

  let asapLoaded, bodyLoaded;

  function insertDexfiles(e) {
    if (!e.relatedNode.tagName) {
      console.log('relatedNode.tagName is not set', e);
      return;
    }

    if (!asapLoaded && document.documentElement) {
      asapLoaded = true;
      console.log('Appending Dex CSS to html');
      document.documentElement.appendChild(globalCSS);
      document.documentElement.appendChild(hostCSS);
    }

    if (!bodyLoaded && document.body) {
      bodyLoaded = true;
      console.log('Appending Dex JS to body');
      document.body.appendChild(globalJS);
      document.body.appendChild(hostJS);
    }

    if (asapLoaded && bodyLoaded) {
      document.removeEventListener('DOMNodeInserted', insertDexfiles, false);
    }
  }

  document.addEventListener('DOMNodeInserted', insertDexfiles);

  setDexFileURLs(hostname, hostJS, hostCSS);
  setDexFileURLs('global', globalJS, globalCSS);

})();
