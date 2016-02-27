/* global RWB: true */

import React from 'react';
import ReactDOMServer from 'react-dom/server';
import Root from '__rwb_root__';

import fs from 'fs';
import path from 'path';

const writeFileOptions = {
  encoding: 'utf8',
};

export default function renderStatic() {
  fs.writeFileSync(
    path.join(RWB.STATIC_ROOT, 'index.html'),
    '<!doctype html>' + ReactDOMServer.renderToStaticMarkup(
      <html>
        <head>
          <meta charSet="utf-8" />
          <title>Dex</title>
          {RWB.ASSETS.css.map((a, idx) => <link key={idx} rel="stylesheet" href={a.slice(1)} />)}
        </head>
        <body style={{minWidth: 300}}>
          <RWB.DOM_NODE_ELEMENT
            id={RWB.DOM_NODE_ID}
            dangerouslySetInnerHTML={{
              __html: ReactDOMServer.renderToString(Root),
            }}
          />
          {RWB.ASSETS.js.map((a, idx) => <script key={idx} src={a.slice(1)} />)}
        </body>
      </html>
    ),
    writeFileOptions
  );
}
