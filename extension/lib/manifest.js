'use strict';
const pkg = require('../../package.json')

let cspArray = [
  `default-src ${process.env.DEX_URL}`,
  `style-src 'unsafe-inline' ${process.env.DEX_URL}`,
]

if (process.env.NODE_ENV === 'development') {
  cspArray = [
    `default-src blob: ${process.env.DEX_URL} http://localhost:3000`,
    `style-src  'unsafe-inline' blob: ${process.env.DEX_URL} http://localhost:3000`,
    `script-src 'unsafe-eval' blob: ${process.env.DEX_URL} http://localhost:3000`,
    `connect-src blob: ${process.env.DEX_URL} ws://localhost:3000 http://localhost:3000`,
  ]
}

module.exports = {
  name: pkg.name,
  manifest_version: 2,
  version: process.env.DEX_VERSION,
  description: pkg.description,
  homepage_url: pkg.homepage,

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

  content_security_policy: cspArray.join('; '),

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
    'storage',
    'webRequest',
    'webRequestBlocking',
    'http://*/*',
    'https://*/*',
  ],
}
