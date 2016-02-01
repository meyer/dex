'use strict';

const config = require('../config');

module.exports = {
  name: 'Dex',
  manifest_version: 2,
  version: '1.1.0',
  description: 'Hello!',
  homepage_url: 'http://github.com/meyer/dex-extension',

  icons: {
    32: 'assets/Icon-32.png',
    48: 'assets/Icon-48.png',
    64: 'assets/Icon-64.png',
    96: 'assets/Icon-96.png',
    128: 'assets/Icon-128.png',
  },

  browser_action: {
    default_icon: {
      19: 'assets/toolbar-button-icon-chrome.png',
      38: 'assets/toolbar-button-icon-chrome@2x.png',
    },
    default_title: 'Dex',
    default_popup: 'popover/index.html',
  },

  background: {
    scripts: [
      'background-chrome.js',
    ],
    persistent: true,
  },

  content_security_policy: [
    `default-src ${config.dexURL}`,
    `style-src 'unsafe-inline' ${config.dexURL}`,
  ].join('; '),

  content_scripts: [{
    all_frames: true,
    run_at: 'document_start',
    js: [
      'insert-dex-urls.js',
    ],
    matches: [
      'http://*/*',
      'https://*/*',
    ],
  }],

  web_accessible_resources: [],

  permissions: [
    'tabs',
    'webRequest',
    'webRequestBlocking',
    'http://*/*',
    'https://*/*',
  ],
};
