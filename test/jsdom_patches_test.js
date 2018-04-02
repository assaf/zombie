const assert = require('assert');
const Utils  = require('jsdom/lib/jsdom/utils');
const URL    = require('url');

describe('Utils', function() {
  describe('resolving HREFs', function() {
    const patterns = [
      ['http://localhost', 'foo', 'http://localhost/foo'],
      ['http://localhost/foo/bar', 'baz', 'http://localhost/foo/baz'],
      ['http://localhost/foo/bar', '/bar', 'http://localhost/bar'],
      ['http://localhost', 'file://foo/Users', 'file://foo/Users'],
      ['http://localhost', 'file:///Users/foo', 'file:///Users/foo'],
      ['file://foo/Users', 'file:bar', 'file://foo/bar']
    ];

    it('returns the correct URL', function() {
      patterns.forEach(function(pattern) {
        assert.equal(URL.resolve(pattern[0], pattern[1]), pattern[2]);
      });
    });
  });
});
