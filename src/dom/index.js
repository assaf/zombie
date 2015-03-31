// Exports the JSDOM DOM living namespace.

const DOM = require('jsdom/lib/jsdom/living');
module.exports = DOM;


// Monkey patching JSDOM.  This is why we can't have nice things.
require('./focus');
require('./iframe');
require('./forms');
require('./jsdom_patches');
require('./scripts');

