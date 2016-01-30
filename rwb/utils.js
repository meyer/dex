'use strict';

const urlLib = require('url');

function getValidHostname(url) {
  if (!url || url === '') {
    return false;
  }

  const parsedURL = urlLib.parse(url);

  if (!~['http:', 'https:'].indexOf(parsedURL.protocol)) {
    console.error('Only HTTP and HTTPS protocols are supported');
    return false;
  } else

  if (!~parsedURL.hostname.indexOf('.')) {
    console.error(`Hostname '${parsedURL.hostname}' is invalid (no dot)`);
    return false;
  } else

  if (parsedURL.hostname.match(/^.+\.(\d+|dev)$/)) {
    console.error(`Hostname '${parsedURL.hostname}' is invalid (ip/dev)`);
    return false;
  }

  return parsedURL.hostname.replace(/^ww[w\d]\./, '');
}

module.exports = {
  getValidHostname,
};
