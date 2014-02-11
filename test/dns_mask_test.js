const assert  = require('assert');
const Browser = require('../src/zombie');
const DNS     = require('dns');


describe("DNS mask", function() {
  before(function() {
    // This will match www.test.com only
    Browser.dns.map('www.test.com', 'A', '1.1.1.1');
    // This will match bar.test.com and test.com
    Browser.dns.map('*.test.com', 'A', '2.2.2.2');
    // This will match IPv6 lookup
    Browser.dns.map('www.test.com', 'AAAA', '::3');
    // This will match CNAME lookup, resolve to 1.1.1.1
    Browser.dns.map('cname.test.com', 'CNAME', 'www.test.com');
    // This will match MX lookup
    Browser.dns.map('www.test.com', 'MX', { exchange: 'mail.test.com', priority: 10 });
  });

  it("should match most specific hostname first", function*() {
    var www = yield (resume)=> DNS.lookup('www.test.com', resume);
    assert.deepEqual(www, ['1.1.1.1', 4]);
    var bar = yield (resume)=> DNS.lookup('bar.test.com', resume);
    assert.deepEqual(bar, ['2.2.2.2', 4]);
    var root = yield (resume)=> DNS.lookup('test.com', resume);
    assert.deepEqual(root, ['2.2.2.2', 4]);
  });

  it("should resolve A/AAAA record to itself", function*() {
    var a = yield (resume)=> DNS.lookup('3.3.3.3', resume);
    assert.deepEqual(a, ['3.3.3.3', 4]);
    var aaaa = yield (resume)=> DNS.lookup('::4', resume);
    assert.deepEqual(aaaa, ['::4', 6]);
  });

  it("should be able to lookup by CNAME", function*() {
    var cname = yield (resume)=> DNS.lookup('cname.test.com', resume);
    assert.deepEqual(cname, ['1.1.1.1', 4]);
    var localhost = yield (resume)=> DNS.lookup('localhost', resume);
    assert.deepEqual(localhost, ['127.0.0.1', 4]);
  });

  it("should match based on family", function*() {
    var ipv4 = yield (resume)=> DNS.lookup('www.test.com', 4, resume);
    assert.deepEqual(ipv4, ['1.1.1.1', 4]);
    var ipv6 = yield (resume)=> DNS.lookup('www.test.com', 6, resume);
    assert.deepEqual(ipv6, ['::3', 6]);
  });

  it("should be able to resolve by record type", function*() {
    var a = yield (resume)=> DNS.resolve('www.test.com', 'A', resume);
    assert.deepEqual(a, ['1.1.1.1']);
    var aaaa = yield (resume)=> DNS.resolve('www.test.com', 'AAAA', resume);
    assert.deepEqual(aaaa, ['::3']);
    var cname = yield (resume)=> DNS.resolve('cname.test.com', 'CNAME', resume);
    assert.deepEqual(cname, ['www.test.com']);
    var mx = yield (resume)=> DNS.resolve('www.test.com', 'MX', resume);
    assert.deepEqual(mx, [{ exchange: 'mail.test.com', priority: 10 }]);
    // Default record type is A
    var noType = yield (resume)=> DNS.resolve('www.test.com', resume);
    assert.deepEqual(noType, ['1.1.1.1']);
  });

  it("should be able to resolve MX record", function*() {
    var mx = yield (resume)=> DNS.resolveMx('www.test.com', resume);
    assert.deepEqual(mx, [{ exchange: 'mail.test.com', priority: 10 }]);
  });

  after(function() {
    Browser.dns.unmap('www.test.com');
    Browser.dns.unmap('*.test.com');
    Browser.dns.unmap('cname.test.com');
  });
});

