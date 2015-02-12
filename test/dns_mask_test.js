const assert  = require('assert');
const Browser = require('../src');
const DNS     = require('dns');


describe('DNS mask', function() {
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

  it('should match most specific hostname first', async function() {
    const www = await new Promise((resolve)=> DNS.lookup('www.test.com', (error, ...args)=> resolve(args)) );
    assert.deepEqual(www, ['1.1.1.1', 4]);
    const bar = await new Promise((resolve)=> DNS.lookup('bar.test.com', (error, ...args)=> resolve(args)) );
    assert.deepEqual(bar, ['2.2.2.2', 4]);
    const root = await new Promise((resolve)=> DNS.lookup('test.com', (error, ...args)=> resolve(args)) );
    assert.deepEqual(root, ['2.2.2.2', 4]);
  });

  it('should resolve A/AAAA record to itself', async function() {
    const a = await new Promise((resolve)=> DNS.lookup('3.3.3.3', (error, ...args)=> resolve(args)) );
    assert.deepEqual(a, ['3.3.3.3', 4]);
    const aaaa = await new Promise((resolve)=> DNS.lookup('::4', (error, ...args)=> resolve(args)) );
    assert.deepEqual(aaaa, ['::4', 6]);
  });

  it('should be able to lookup by CNAME', async function() {
    const cname = await new Promise((resolve)=> DNS.lookup('cname.test.com', (error, ...args)=> resolve(args)) );
    const localhost = await new Promise((resolve)=> DNS.lookup('localhost', (error, ...args)=> resolve(args)) );
    assert.deepEqual(localhost, ['127.0.0.1', 4]);
  });

  it('should match based on family', async function() {
    const ipv4 = await new Promise((resolve)=> DNS.lookup('www.test.com', 4, (error, ...args)=> resolve(args)) );
    assert.deepEqual(ipv4, ['1.1.1.1', 4]);
    const ipv6 = await new Promise((resolve)=> DNS.lookup('www.test.com', 6, (error, ...args)=> resolve(args)) );
    assert.deepEqual(ipv6, ['::3', 6]);
  });

  it('should be able to resolve by record type', async function() {
    const a = await new Promise((resolve)=> DNS.resolve('www.test.com', 'A', (error, arg)=> resolve(arg)) );
    assert.deepEqual(a, ['1.1.1.1']);
    const aaaa = await new Promise((resolve)=> DNS.resolve('www.test.com', 'AAAA', (error, arg)=> resolve(arg)) );
    assert.deepEqual(aaaa, ['::3']);
    const cname = await new Promise((resolve)=> DNS.resolve('cname.test.com', 'CNAME', (error, arg)=> resolve(arg)) );
    assert.deepEqual(cname, ['www.test.com']);
    const mx = await new Promise((resolve)=> DNS.resolve('www.test.com', 'MX', (error, arg)=> resolve(arg)) );
    assert.deepEqual(mx, [{ exchange: 'mail.test.com', priority: 10 }]);
    // Default record type is A
    const noType = await new Promise((resolve)=> DNS.resolve('www.test.com', (error, arg)=> resolve(arg)) );
    assert.deepEqual(noType, ['1.1.1.1']);
  });

  it('should be able to resolve MX record', async function() {
    const mx = await new Promise((resolve)=> DNS.resolveMx('www.test.com', (error, arg)=> resolve(arg)) );
    assert.deepEqual(mx, [{ exchange: 'mail.test.com', priority: 10 }]);
  });

  after(function() {
    Browser.dns.unmap('www.test.com');
    Browser.dns.unmap('*.test.com');
    Browser.dns.unmap('cname.test.com');
  });
});

