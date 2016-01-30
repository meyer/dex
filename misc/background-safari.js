/* global safari:true */

'use strict';

function updateTabStatus(e) {
  console.log('updateTabStatus:', e);
}

safari.application.addEventListener('popover', function(e) {
  console.log(e);
});

safari.application.addEventListener('activate', updateTabStatus);
safari.application.addEventListener('validate', updateTabStatus);
safari.application.addEventListener('popover', updateTabStatus);
