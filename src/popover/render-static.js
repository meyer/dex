/* global RWB: true */
'use strict';

const React = require('react');
const ReactDOMServer = require('react-dom/server');
const Root = require('__rwb_root__').default;

const fs = require('fs');
const path = require('path');

const writeFileOptions = {
  encoding: 'utf8',
};

function renderStatic() {
  fs.writeFileSync(
    path.join(RWB.STATIC_ROOT, 'index.html'),
    '<!doctype html>' + ReactDOMServer.renderToStaticMarkup(
      <html>
        <head>
          <meta charSet="utf-8" />
          <title>Dex</title>
          {RWB.ASSETS.css.map((a, idx) => <link key={idx} rel="stylesheet" href={a.slice(1)} />)}
        </head>
        <body>
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

module.exports = renderStatic;
