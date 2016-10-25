GET /rsrc.php/v2/yW/r/Q1WFQNCqpeo.js
host: static.xx.fbcdn.net

HTTP/1.1 200 OK
access-control-allow-credentials: true
x-content-type-options: nosniff
content-type: application/x-javascript; charset=utf-8
timing-allow-origin: *
cache-control: public, max-age=31536000
expires: Tue, 13 Dec 2016 22:10:31 GMT
content-md5: dCRcayTdVhaLPQUgnjhufQ==
last-modified: Mon, 01 Jan 2001 08:00:00 GMT
access-control-allow-origin: *
vary: Accept-Encoding
x-fb-debug: 4gYGMfJAXDocgP4pTowoealhT8jalU7P6CI+FUbcphRTrs/wINrqgIAaVPGY0deHxrm204r4hLpaCFHM8OiZeg==
date: Fri, 18 Dec 2015 20:57:28 GMT
connection: close
content-length: 3519

/*!CK:196703556!*//*1450131031,*/

if (self.CavalryLogger) { CavalryLogger.start_js(["d7V4X"]); }

__d('DetectBrokenProxyCache',['AsyncSignal','Cookie','URI'],function a(b,c,d,e,f,g,h,i,j){if(c.__markCompiled)c.__markCompiled();function k(l,m){var n=i.get(m);if(n!=l&&n!=null&&l!='0'){var o={c:'si_detect_broken_proxy_cache',m:m+' '+l+' '+n},p=new j('/common/scribe_endpoint.php').getQualifiedURI().toString();new h(p,o).send();}}f.exports={run:k};},null);
__d('DimensionLogging',['BanzaiNectar','getViewportDimensions'],function a(b,c,d,e,f,g,h,i){if(c.__markCompiled)c.__markCompiled();var j=i();h.log('browser_dimension','homeload',{x:j.width,y:j.height,sw:window.screen.width,sh:window.screen.height,aw:window.screen.availWidth,ah:window.screen.availHeight,at:window.screen.availTop,al:window.screen.availLeft});},null);
__d('DimensionTracking',['Cookie','Event','debounce','getViewportDimensions','isInIframe'],function a(b,c,d,e,f,g,h,i,j,k,l){if(c.__markCompiled)c.__markCompiled();function m(){var n=k();h.set('wd',n.width+'x'+n.height);}if(!l()){setTimeout(m,100);i.listen(window,'resize',j(m,250));i.listen(window,'focus',m);}},null);
__d('HighContrastMode',['AccessibilityLogger','CSS','CurrentUser','DOM','Style','URI','emptyFunction'],function a(b,c,d,e,f,g,h,i,j,k,l,m,n){if(c.__markCompiled)c.__markCompiled();var o={init:function(p){var q=new m(window.location.href);if(q.getPath().indexOf('/intern/')===0)return;if(window.top!==window.self)return;var r=k.create('div');k.appendContent(document.body,r);r.style.cssText='border: 1px solid !important;'+'border-color: red green !important;'+'position: fixed;'+'height: 5px;'+'top: -999px;'+'background-image: url('+p.spacerImage+') !important;';var s=l.get(r,'background-image'),t=l.get(r,'border-top-color'),u=l.get(r,'border-right-color'),v=t==u&&(s&&(s=='none'||s=='url(invalid-url:)'));if(v){i.conditionClass(document.documentElement,'highContrast',v);if(j.getID())h.logHCM();}k.remove(r);o.init=n;}};f.exports=o;},null);
__d('Live',['Arbiter','AsyncDOM','AsyncSignal','ChannelConstants','DataStore','DOM','ServerJS','emptyFunction'],function a(b,c,d,e,f,g,h,i,j,k,l,m,n,o){if(c.__markCompiled)c.__markCompiled();function p(r,s){s=JSON.parse(JSON.stringify(s));new n().setRelativeTo(r).handle(s);}var q={logAll:false,startup:function(r){q.logAll=r;q.startup=o;h.subscribe(k.getArbiterType('live'),q.handleMessage.bind(q));},lookupLiveNode:function(r,s){var t=m.scry(document.body,'.live_'+r+'_'+s);t.forEach(function(u){if(l.get(u,'seqnum')===undefined){var v=JSON.parse(u.getAttribute('data-live'));l.set(u,'seqnum',v.seq);}});return t;},handleMessage:function(r,s){var t=s.obj,u=t.fbid,v=t.assoc,w=this.lookupLiveNode(u,v);if(!w)return false;w.forEach(function(x){i.invoke(t.updates,x);if(t.js)p(x,t.js);});},log:function(){if(q.logAll){var r=Array.from(arguments).join(':');new j('/common/scribe_endpoint.php',{c:'live_sequence',m:r}).send();}}};f.exports=q;},null);
__d("UFITracking",["Bootloader"],function a(b,c,d,e,f,g,h){if(c.__markCompiled)c.__markCompiled();function i(k){h.loadModules(["DOM","collectDataAttributes"],function(l,m){k.forEach(function(n){var o=l.scry(document.body,n);if(!o||o.link_data)return;var p=m(o,['ft']).ft;if(Object.keys(p).length){var q=l.create('input',{type:'hidden',name:'link_data',value:JSON.stringify(p)});o.appendChild(q);}});});}var j={addAllLinkData:function(){i(['form.commentable_item']);},addAllLinkDataForQuestion:function(){i(['form.fbEigenpollForm','form.fbQuestionPollForm']);}};f.exports=j;},null);