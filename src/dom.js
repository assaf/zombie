// Exports the JSDOM DOM living namespace.

const DOM = require('jsdom/lib/jsdom/living');
module.exports = DOM;


// Additional error codes defines for XHR and not in JSDOM.
DOM.SECURITY_ERR  = 18;
DOM.NETWORK_ERR   = 19;
DOM.ABORT_ERR     = 20;
DOM.TIMEOUT_ERR   = 23;

DOM.exceptionMessages[DOM.SECURITY_ERR] = 'Security error';
DOM.exceptionMessages[DOM.NETWORK_ERR]  = 'Network error';
DOM.exceptionMessages[DOM.ABORT_ERR]    = 'Abort';
DOM.exceptionMessages[DOM.TIMEOUT_ERR]  = 'Timeout';



// Monkey patching JSDOM.  This is why we can't have nice things.
require('./jsdom_patches');
require('./forms');
require('./dom_focus');
require('./dom_iframe');
require('./scripts');

