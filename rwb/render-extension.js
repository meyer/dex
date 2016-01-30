'use strict';

import React from 'react';
import ReactDOMServer from 'react-dom/server';
import Root from '__rwb_root__';

import fs from 'fs';
import path from 'path';

const DEX_URL = 'https://localhost:3131'

const writeFileOptions = {
  encoding: 'utf8',
}

const chromeManifest = {
  name: 'Dex',
  manifest_version: 2,
  version: '1.1.0',
  description: 'Hello!',
  homepage_url: 'http://github.com/meyer/dex-extension',
  icons: {

  },
  browser_action: {
    default_icon: {
      19: "toolbar-button-icon-chrome.png",
      38: "toolbar-button-icon-chrome@2x.png"
    },
    default_title: 'Dex!',
    default_popup: 'popover.html',
  },

  background: {
    scripts: [
      'background-page-utils.js',
      'background-chrome.js',
    ],
    persistent: true,
  },

  content_security_policy: `default-src 'self' 'unsafe-eval' ${DEX_URL}`,
  content_scripts: [{
    all_frames: true,
    run_at: 'document_start',
    js: [
      'content-script.js',
    ],
    matches: [
      'http://*/*',
      'https://*/*',
    ],
  }],
  web_accessible_resources: [
    RWB.ASSETS.misc,
  ],
  permissions: [
    'tabs',
    'webRequest',
    'webRequestBlocking',
    'http://*/*',
    'https://*/*',
  ],
};


export default function() {
  fs.writeFileSync(
    path.join(RWB.STATIC_ROOT, 'manifest.json'),
    '',
    writeFileOptions
  );

  fs.writeFileSync(
    path.join(RWB.STATIC_ROOT, 'index.html'),
    '<!doctype html>' + ReactDOMServer.renderToStaticMarkup(
      <html>
        <head>
          <title>MyComponent</title>
          {RWB.ASSETS.css.map((a, idx) => <link key={idx} rel="stylesheet" href={a} />)}
        </head>
        <body>
          <RWB.DOM_NODE_ELEMENT
            id={RWB.DOM_NODE_ID}
            dangerouslySetInnerHTML={{
              __html: ReactDOMServer.renderToString(Root),
            }}
          />
        {RWB.ASSETS.js.map((a, idx) => <script key={idx} src={a} />)}
        </body>
      </html>
    ),
    writeFileOptions
  );
}
