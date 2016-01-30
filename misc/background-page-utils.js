/* global safari: true, _: true */
'use strict';

function loadEmpty(url) {
  let emptyTpl = _.template(document.getElementById('module-list-empty').innerHTML);
  bodySwap(emptyTpl({ url: url }));
}

window.dexutils = {};

window.dexutils.getValidHostname = function(url) {
  if (!url || url === '') {
    return false;
  }

  const a = document.createElement('a');
  a.href = url;

  if (!~['http:', 'https:'].indexOf(a.protocol)) {
    console.error('Only HTTP and HTTPS protocols are supported');
    return false;
  } else if (!~a.hostname.indexOf('.')) {
    return console.error(`Hostname '${a.hostname}' is invalid (no dot)`);
  } else if (a.hostname.match(/^.+\.(\d+|dev)$/)) {
    console.error(`Hostname '${a.hostname}' is invalid (ip/dev)`);
    return false;
  } else {
    return a.hostname.replace(/^ww[w\d]\./, '');
  }
};

window.dexutils.getJSON = function(url, callback) {
  var e, xhr;
  try {
    xhr = new XMLHttpRequest();
    xhr.open('GET', url, true);
    xhr.onreadystatechange = function() {
      var error, responseJSON;
      if (xhr.readyState === 4) {
        if (xhr.status === 200) {
          responseJSON = {};
          try {
            responseJSON = JSON.parse(xhr.responseText);
          } catch (_error) {
            error = _error;
            console.error('Error parsing response JSON: `' + xhr.responseText + '`');
            console.info(error);
          }
          return typeof callback === 'function' ? callback(responseJSON) : void 0;
        } else {
          return typeof callback === 'function' ? callback({}, true) : void 0;
        }
      }
    };
    xhr.send();
  } catch (_error) {
    e = _error;
    console.error('Weird XHR error:', e);
    if (typeof callback === 'function') {
      callback({}, 'Error: ' + e);
    }
  }
};

function bodySwap(guts) {
  const tempDiv = document.createElement('div');

  tempDiv.style.visibility = 'hidden';
  tempDiv.style.position = 'absolute';
  tempDiv.style.top = 0;
  tempDiv.style.left = 0;
  tempDiv.innerHTML = guts;

  document.body.appendChild(tempDiv);
  if (
    typeof safari === 'object' &&
    typeof safari.self === 'object' &&
    typeof safari.self.height !== 'undefined'
  ) {
    safari.self.height = tempDiv.clientHeight;
    console.log('Set popover height (' + safari.self.height + ')');
  }

  document.body.innerHTML = tempDiv.innerHTML;

  tempDiv.remove();
}

window.dexutils.loadModuleListForURL = function(url) {
  var hostname, jsonURL, moduleListTpl;

  if (!(hostname = window.dexutils.getValidHostname(url))) {
    console.error('URL is invalid:', url);

    if (document.body != null) {
      loadEmpty(url);
    } else {
      document.addEventListener('DOMContentLoaded', loadEmpty);
    }

    return;
  }

  jsonURL = `<%= DEX_URL %>/${hostname}.json`;
  moduleListTpl = _.template(document.getElementById('module-list-tpl').innerHTML);

  window.dexutils.getJSON(jsonURL, function(data, error) {
    if (error != null) {
      return;
    }
    data.hostname = hostname;
    bodySwap(moduleListTpl(data));
    return document.body.addEventListener('change', function(e) {
      if (e.target.dataset.module == null) {
        console.error('Element ' + e.target.tagName + ' is missing data-href attribute');
        return;
      }
      return window.dexutils.getJSON(jsonURL + '?toggle=' + e.target.dataset.module, function(moduleData) {
        var action, module;
        if ((moduleData.length != null) && moduleData.length === 2) {
          action = moduleData[0], module = moduleData[1];
          return console.log(module + ': ' + action + ', checked: ' + e.target.checked);
        } else {
          return console.error('Expected a two-element array, got something funky instead:', moduleData);
        }
      });
    });
  });
};
