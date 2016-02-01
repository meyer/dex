'use strict';

const urlLib = require('url');

function getValidHostname(url) {
  if (!url || url === '') {
    return false;
  }

  const parsedURL = urlLib.parse(url);

  if (!~['http:', 'https:'].indexOf(parsedURL.protocol)) {
    if (process.env.NODE_ENV === 'development') {
      console.error(`Dex error: Only HTTP and HTTPS protocols are supported (got '${parsedURL.protocol}')`);
    }
  } else if (!~parsedURL.hostname.indexOf('.')) {
    if (process.env.NODE_ENV === 'development') {
      console.error(`Dex error: Hostname '${parsedURL.hostname}' is invalid (no dot)`);
    }
  } else if (parsedURL.hostname.match(/^.+\.(\d+|dev)$/)) {
    if (process.env.NODE_ENV === 'development') {
      console.error(`Dex error: Hostname '${parsedURL.hostname}' is invalid (ip/dev)`);
    }
  } else {
    return parsedURL.hostname.replace(/^ww[w\d]\./, '');
  }
  return false;
}

module.exports = {getValidHostname};
