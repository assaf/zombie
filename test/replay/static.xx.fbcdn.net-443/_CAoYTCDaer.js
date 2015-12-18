GET /rsrc.php/v2/yH/r/_CAoYTCDaer.js
host: static.xx.fbcdn.net

HTTP/1.1 200 OK
access-control-allow-credentials: true
x-content-type-options: nosniff
content-type: application/x-javascript; charset=utf-8
timing-allow-origin: *
cache-control: public, max-age=31536000
expires: Tue, 13 Dec 2016 20:01:48 GMT
content-md5: Ad3KVHjfb9Tw+ibpEGH98w==
last-modified: Mon, 01 Jan 2001 08:00:00 GMT
access-control-allow-origin: *
vary: Accept-Encoding
x-fb-debug: qss1lSIkGdNqXGZXHo42wuv1EXIIrFbdVVnWFE25V8zZ1Ts9aAdk5uOGOlDL9JL3Q94bbxZy4BAB+YqyHCzoEw==
date: Fri, 18 Dec 2015 20:57:28 GMT
connection: close
content-length: 1189

/*!CK:2469445612!*//*1450123308,*/

if (self.CavalryLogger) { CavalryLogger.start_js(["lYMIq"]); }

__d('FormSubmit',['AsyncRequest','AsyncResponse','CSS','DOMQuery','Event','Form','Parent','trackReferrer'],function a(b,c,d,e,f,g,h,i,j,k,l,m,n,o){if(c.__markCompiled)c.__markCompiled();var p={send:function(q,r){var s=(m.getAttribute(q,'method')||'GET').toUpperCase();r=n.byTag(r,'button')||r;var t=n.byClass(r,'stat_elem')||q;if(j.hasClass(t,'async_saving'))return;if(r&&(r.form!==q||r.nodeName!='INPUT'&&r.nodeName!='BUTTON'||r.type!='submit')){var u=k.scry(q,'.enter_submit_target')[0];u&&(r=u);}var v=m.serialize(q,r);m.setDisabled(q,true);var w=m.getAttribute(q,'ajaxify')||m.getAttribute(q,'action'),x=!!m.getAttribute(q,'data-cors');o(q,w);new h().setAllowCrossOrigin(x).setURI(w).setData(v).setNectarModuleDataSafe(q).setReadOnly(s=='GET').setMethod(s).setRelativeTo(q).setStatusElement(t).setInitialHandler(m.setDisabled.bind(null,q,false)).setHandler(function(y){l.fire(q,'success',{response:y});}).setErrorHandler(function(y){if(l.fire(q,'error',{response:y})!==false)i.defaultErrorHandler(y);}).setFinallyHandler(m.setDisabled.bind(null,q,false)).send();}};f.exports=p;},null);