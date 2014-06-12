check-webpage
=============

The aim of this nagios compatible check script is to download a web page with all his content.

I used [Check HTTP Requisites plugin](http://www.nagiosexchange.org/cgi-bin/page.cgi?g=Detailed%2F1352.html;d=1) but it's a mono thread way and it's too slow for performance checks.

Main features
-------------

 * Ruby small script, easy to understand and hack ...
 * Use the powerful and simple [hpricot](https://github.com/hpricot/hpricot) lib to parse html
 * Multi-thread
 * Keyword check
 * Follow redirections
 * Download all the links on the page or only the html 
 * Supported options: gzip deflate, auth, proxy, http post, https

Example
-------

```
$ ./check_webpage.rb -vv -u http://www.google.com

 * ARGS: c=60 w=5 e=0 w2=10 u=http://www.google.com

 * Get main page: http://www.google.com/
   -> 302, main page is now: http://www.google.fr/
[200] OK s(6697) t(0.251305)

 * parsing results (1) ...
http://www.google.fr/intl/fr_fr/images/logo.gif -> add

 * remove duplicated links: 1 -> 1

 * downloading inner links (1) ...
[200] OK /intl/fr_fr/images/logo.gif -> s(8866o) t(0.09s)

 * results
Inner links count: 1
Inner links dl cumulated time: 0.09s
Total time: 0.35s
Total size: 15ko

OK - 15ko, 2 files, 0.35s
```
Download
--------

https://github.com/Toubib/check-webpage/releases/latest

Documentation
-------------

 * English: https://github.com/Toubib/check-webpage/wiki/Documentation-en
 * Français: https://github.com/Toubib/check-webpage/wiki/Documentation-fr
