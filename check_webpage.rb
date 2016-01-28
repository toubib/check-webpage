#!/usr/bin/env ruby
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#       Copyright Vincent Reydet

# Project: nagios-check-webpage 
# Website: https://github.com/Toubib/check-webpage/

# To use in nagios:
#   - Put the script into the $USER1$ directory
#   - Add this check command ( add your options ... )
#     define command{
#       command_name  check-webpage
#       command_line  $USER1$/check_webpage.rb -u $ARG1$
#     }

# Quick documentation: use -h option
# Full documentation: https://github.com/Toubib/check-webpage/wiki/Documentation-en

begin
  require 'thread'
  require 'net/http'
  require 'net/https'
  require 'open-uri'
  require 'rubygems'
  require 'hpricot'
  require 'optiflag'
  require 'zlib'
  require 'base64'
  require 'date'
  require 'socket'
  
  rescue LoadError => e
   mgem = /\w+$/.match(e.message)
   puts "#{mgem} required."
   puts "Please install with 'gem install #{mgem}'"
   exit
end

MAX_REDIRECT=5 #set max redirect to prevent infinite loop

#set http headers
httpHeaders = Hash.new
httpHeaders = { 'User-Agent' => 'nagios-check-webpage' }

## OPT PARSING
###############################################################
module Example extend OptiFlagSet
  usage_flag "h","help"
  optional_switch_flag "v" do
    description "verbose"
  end
  optional_switch_flag "vv" do
    description "more verbose !"
  end
  optional_switch_flag "e" do
    description "extended mode, see the documentation"
  end
  optional_switch_flag "H" do
    long_form "span-hosts"
    description "--span-hosts, download from other hosts"
  end
  optional_flag "c" do
    long_form "critical"
    description "--critical, default 60,  Critical time (s)"
  end
  optional_flag "C" do
    long_form "cookie"
    description '--cookie "key=value[;key=value]"'
  end
  optional_flag "w" do
    long_form "warn"
    description "--warn, default 5,  warn time (s)"
  end
  optional_flag "w2" do
    long_form "warn2"
    description "--warn2, default 10,  warn2 time (s), use with '-e'"
  end
  optional_flag "k" do
    long_form "key"
    description "--key, check for keyword"
  end
  optional_switch_flag "z" do
    long_form "gzip"
    description "--gzip, add gzip,deflate to http headers"
  end
  optional_switch_flag "n" do
    long_form "no-inner-links"
    description "--no-inner-links, do not dl inner links, get only the html"
  end
  optional_flag "a" do
    long_form "auth"
    description "--auth user:password"
  end
  optional_flag "p" do
    long_form "post"
    description "--post param=data, use post request with data for the main page"
  end
  flag "u" do
    long_form "url"
    description "--url, absolute: [http://www.google.com]"
  end
  optional_flag "P" do
    long_form "proxy"
    description "--proxy, proxy address host[:port]"
  end
  optional_flag "Pu" do
    long_form "proxy-user"
    description "--proxy-user, proxy username"
  end
  optional_flag "Pp" do
    long_form "proxy-pass"
    description "--proxy-pass, proxy password"
  end

  optional_flag "l" do
    long_form "log"
    description "--log, log directory to store output on error"
  end

  optional_flag "Gh" do
    long_form "graphite-host"
    description "--graphite-host, send response time to this graphite host"
  end

  optional_flag "Gp" do
    long_form "graphite-port"
    description "--graphite-port, the graphite server UDP port to use"
  end

  optional_flag "Gx" do
    long_form "graphite-prefix"
    description "--graphite-prefix, prefix the graphite path (default to 'webpage')"
  end

  optional_flag "vhc" do
    long_form "valid-http-codes"
    description "--valid-http-codes XXX,XXX (ex 401,404)"
  end

  and_process!
end 

# GET THE ARGV VALUES
if ARGV.flags.e?
  EXTENDED=1
else
  EXTENDED=0
end

if ARGV.flags.vv?
  DEBUG=2
elsif ARGV.flags.v?
  DEBUG=1
else
  DEBUG=0
end

if ARGV.flags.c?
  timeCritical=ARGV.flags.c.to_f
else
  timeCritical=60
end

if ARGV.flags.C?
  httpHeaders['Cookie'] = ARGV.flags.C
end

if ARGV.flags.w?
  timeWarn=ARGV.flags.w.to_f
else
  timeWarn=5
end

if ARGV.flags.w2?
  timeWarn2=ARGV.flags.w2.to_f
else
  timeWarn2=10
end

if ARGV.flags.k?
  keyword=ARGV.flags.k
else
  keyword=nil
end

if ARGV.flags.a?
  httpHeaders['Authorization'] = 'Basic '+Base64.encode64(ARGV.flags.a)
end

if ARGV.flags.vhc?
  validHttpCodes = ARGV.flags.vhc.split(',')
else
  validHttpCodes = []
end

if ARGV.flags.p?
  postData = ARGV.flags.p
else
  postData = nil
end

if ARGV.flags.P?
  proxy = {}
  proxy['host'] = ARGV.flags.P.split(':')[0]
  proxy['port'] = ARGV.flags.P.split(':')[1]
  proxy['user'] = ARGV.flags.Pu if ARGV.flags.Pu?
  proxy['pass'] = ARGV.flags.Pp if ARGV.flags.Pp?
else
  proxy = { 'host'=>nil, 'port'=>nil, 'user'=>nil, 'pass'=>nil }
end

if ARGV.flags.z?
  gzip = 1
  httpHeaders['Accept-Encoding'] = "gzip,deflate"
else
  gzip = 0
end

if ARGV.flags.n?
  GET_INNER_LINKS = 0
else
  GET_INNER_LINKS = 1
end

if ARGV.flags.H?
  SPAN_HOSTS = 1
else
  SPAN_HOSTS = 0
end

if ARGV.flags.l?
  LOG = ARGV.flags.l
else
  LOG = nil
end

if ARGV.flags.Gx?
	GRAPHITE_BUCKET_PRE=ARGV.flags.Gx
else
	GRAPHITE_BUCKET_PRE='webpage'
end

if ARGV.flags.Gh?
	GRAPHITE_HOST=ARGV.flags.Gh
	GRAPHITE_BUCKET=GRAPHITE_BUCKET_PRE + '.' + ARGV.flags.u.sub(/https?:\/\//,'').tr('./','-')
else
	GRAPHITE_HOST=nil
end

if ARGV.flags.Gp?
	GRAPHITE_PORT=ARGV.flags.Gp
else
	GRAPHITE_PORT=2003
end

inputURL=ARGV.flags.u
REQUEST_TIMEOUT=timeCritical

#reports hashtable init
reports = {}
reports['totalDlTime'] = 0 #Stat total download
reports['totalSize'] = 0 #Stat total size
reports['fileErrorCount'] = 0 #error count
reports['linksToDlCount'] = 0 #links count

if DEBUG >= 2 then puts "\n * ARGS: c=#{timeCritical} w=#{timeWarn} e=#{EXTENDED} w2=#{timeWarn2} u=#{ARGV.flags.u}" end

## PARSE INPUT URL
###############################################################
begin
  if inputURL.index("http") != 0
    inputURL ="http://"+inputURL
  end
  uri = URI.escape(inputURL)
  mainUrl = URI.parse(uri)
rescue
  puts "Critical: syntax error, can't parse url ..."
  exit 2
end

## COMPLETE THE INPUT URL
###############################################################
if mainUrl.path == "" || mainUrl.path == nil
  mainUrl.path = '/'
end

## Remove ssl certificate warning
#  http://www.5dollarwhitebox.org/drupal/node/64
###############################################################
class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end

def filename_safe(filename)
  filename.tr(" \t\n/", '_')
end


def log_content(url, response) 
  return if LOG.nil?

  logstamp = DateTime.now().strftime('%F:%H:%M:%S')
  logfile = File.join(LOG, filename_safe(url.to_s) + '-' + logstamp)
  logfile = File.new(logfile, "w")
  response.each_header {|key,value| logfile.write "#{key}: #{value}\n" }
  logfile.write("\n#{response.body}\n")
end

#send data to graphite with UDP
class Graphite
  def initialize(host, port = GRAPHITE_PORT)
    @host, @port = host, port
  end

  def push(bucket, value)
    t = Time.now
    #puts "#{bucket} #{value} #{t.to_i}"
    socket.send("#{bucket} #{value} #{t.to_i}", 0, @host, @port)
  end

  def socket
    @socket ||= UDPSocket.new
  end
end

## get url function
###############################################################
def getUrl( parsedUri, httpHeaders, proxy, postData = nil )
  begin
    _h = Net::HTTP::Proxy( proxy['host'], proxy['port'], proxy['user'], proxy['pass']).new( parsedUri.host, parsedUri.port)
  rescue
    puts "Critical: error with [#{parsedUri}]: "+$!.to_s
    exit 2
  end

  if parsedUri.scheme == "https"
    begin
      _h.use_ssl = true
      _h.verify_mode = OpenSSL::SSL::VERIFY_NONE
    rescue IOError
      puts "Critical: error with [#{parsedUri}]: "+$!.to_s
      exit 2
    end
  end

  if parsedUri.path == "" || parsedUri.path == nil
    parsedUri.path = '/'
  end
  _h.read_timeout=REQUEST_TIMEOUT

  if DEBUG >= 2
  then
    printf " * Path:%s\nHTTP headers:%s\n", parsedUri, httpHeaders
  end

  begin
    if parsedUri.query.nil?
      path = parsedUri.path
    else
      path = parsedUri.path + '?' + parsedUri.query
    end
    if postData != nil
      res = _h.post(path, postData, httpHeaders)
    else
      res = _h.get(path, httpHeaders)
    end

	#Get response cookies and set them again
    r_cookies = res.get_fields('set-cookie')

	if ! r_cookies.nil?
		cookies_temp_array = Array.new
		r_cookies.each { | cookie |
			cookies_temp_array.push(cookie.split('; ')[0])
		}
		httpHeaders['Cookie'] = cookies_temp_array.join('; ')
	end

	if DEBUG >= 2
	then
	  printf "COOKIE: %s\n", r_cookies
	end

  rescue Timeout::Error
    puts "Critical: timeout #{REQUEST_TIMEOUT}s on [#{parsedUri.path}]"
    exit 2
  rescue
    puts "Critical: error with [#{parsedUri}]: "+$!.to_s
    exit 2
  end

  return res
end

## get inner links function
###############################################################
def getInnerLinks (mainUrl, data, httpHeaders, reports, proxy)

  ## Parsing main page data
  doc = Hpricot(data)
  parsingResult =                 doc.search("//img[@src]").map { |x| x['src'].strip }
  parsingResult = parsingResult + doc.search("//script[@src]").map { |x| x['src'].strip }
  parsingResult = parsingResult + doc.search("//input[@src]").map { |x| x['src'].strip }
  parsingResult = parsingResult + doc.search("//link[@href]").map { |x| x['href'].strip }
  parsingResult = parsingResult + doc.search("//embed[@src]").map { |x| x['src'].strip }

  #link_path is path without filename
  link_path = /.*\//.match(mainUrl.path)[0]
  if DEBUG >= 2 then puts "\nDEBUG path=#{mainUrl.path}, link_path=#{link_path}" end

  base = doc.search("//base").map { |x| x['href'] }
  if base.length > 0 then
    if DEBUG >= 2 then puts "\n * switching main url to base (#{base[0]})" end
    mainUrl = URI.parse(base[0])
  end

  ## Pop the wanted links
  if DEBUG >= 2 then puts "\n * parsing results (#{parsingResult.length}) ..." end
  linksToDl = []

  parsingResult.length.times do |i|
    if parsingResult[i]==nil || parsingResult[i]==""
      if DEBUG >= 2 then puts "#{parsingResult[i]} -> pass (empty)" end
      next
    end

    # Ensure the link is expanded to a URL
    if parsingResult[i][0,4] != "http"
      begin
        parsingResult[i]= mainUrl.merge(parsingResult[i]).to_s;
      rescue
        if DEBUG >= 1 then puts "#{parsingResult[i]} ->  pass (bad uri?)" end
        next
      end
    end

    begin
      # test if url
      if RUBY_VERSION =~ /1.8/
        url = URI.parse(URI.escape(parsingResult[i],"[]{}|+"))
      else
        url = URI.parse(URI.escape(parsingResult[i].encode('UTF-8'),"[]{}|+"))
      end
      if SPAN_HOSTS == 0 && url.host != mainUrl.host
        if DEBUG >= 2 then puts "#{parsingResult[i]} -> pass" end
        next
      end
    rescue URI::InvalidURIError
      if DEBUG >= 2 then puts "#{parsingResult[i]} -> error invalid URI" end
      next
    rescue
      if DEBUG >= 2 then puts "#{parsingResult[i]} -> unexpected error" end
      next
    end
    if DEBUG >= 2 then puts "#{parsingResult[i]} -> add" end
    linksToDl.push(url)
  end

  if DEBUG >= 2 then linksToDlPrevCount=linksToDl.length end
  linksToDl.uniq!
  reports['linksToDlCount'] = linksToDl.length
  if DEBUG >= 2 then puts "\n * remove duplicated links: #{linksToDlPrevCount} -> #{linksToDl.length}" end

  ## DL content links with threads
  mutex = Mutex.new #set mutex
  if DEBUG >= 1 then puts "\n * downloading inner links (#{linksToDl.length}) ..." end
  if !GRAPHITE_HOST.nil? then graphite = Graphite.new(GRAPHITE_HOST) end
  threads = []
  linksToDl.each {  |link|
    threads << Thread.new(link) { |myLink|
      t0 = Time.now
      res = getUrl(myLink, httpHeaders, proxy)
      if res == nil then
        # Happens when '204 no content' occurs
        res = ''
      end
      t1 = Time.now-t0
      mutex.synchronize do
        reports['totalDlTime'] += t1
        reports['totalSize'] += res.body.length
      end
      if res.code =~ /[^2]../ then
        reports['fileErrorCount'] += 1
        log_content(myLink, res)
      end
      if DEBUG >= 1 then puts "[#{res.code}] #{res.message} "+myLink.to_s+" -> s(#{res.body.length}B) t("+sprintf("%.2f", t1)+"s)" end
      if !GRAPHITE_HOST.nil?
        bucket = link.path.tr('./','-')
	    graphite.push(GRAPHITE_BUCKET+'.'+bucket+'_time', t1*1000)
	    graphite.push(GRAPHITE_BUCKET+'.'+bucket+'_size', res.body.length)
	  end
    }
  }
  threads.each { |aThread|  aThread.join }
end

## get main page and parse it
###############################################################
startedTime = Time.now
if DEBUG >= 1 then puts "\n * Get main page: #{mainUrl}" end
res = getUrl(mainUrl, httpHeaders, proxy, postData)

## handle redirection
###############################################################
i=0 #redirect count
while res.code =~ /3../
  lastHost = mainUrl.host #issue 7
  begin
    mainUrl = URI.parse(URI.escape(res['location']))
    if mainUrl.host.nil?
       mainUrl.host = lastHost #issue 7
    end
  rescue
    puts "Critical: can't parse redirected url ..."
    exit 2
  end
  if DEBUG >= 1 then puts "   -> #{res.code}, main page is now: #{mainUrl}" end
  res = getUrl(mainUrl, httpHeaders, proxy)

  if (i+=1) >= MAX_REDIRECT
    puts "Critical: too much redirect (#{MAX_REDIRECT}), exit"
    exit 2
  end
end

## check main url return code
###############################################################
if res.code =~ /[^2]../
  if validHttpCodes.include? res.code
    text = "OK: server respond with http code "
    result = 0
  else
    text = "Critical: main page http code is "
    result = 2
  end

  puts "#{text} #{res.code} - #{res.message}"
  log_content(mainUrl, res)
  exit result
end

## Get main url page size
###############################################################
reports['totalSize'] = res.body.length

## inflate if gzip is on
###############################################################
if gzip == 1 && res['Content-Encoding'] == 'gzip'
  begin
    res_body = Zlib::GzipReader.new(StringIO.new(res.body)).read
  rescue Zlib::GzipFile::Error, Zlib::Error
    puts "Critical: error while inflating gzipped url '#{mainUrl}': "+$!.to_s
    log_content(mainUrl, res)
    exit 2
  end
else
  res_body = res.body
end

## Check for keyword ( -k option )
###############################################################
if keyword != nil
  hasKey=0
  res_body.each_line { |line|
    if line.include? keyword
      hasKey=1
    end
  }
  if hasKey==0
    puts "Critical: string not found"
    log_content(mainUrl, res)
    exit 2
  end
end

if DEBUG >= 1 then puts "[#{res.code}] #{res.message} s(#{reports['totalSize']}) t(#{Time.now-startedTime})" end

## inner links part
###############################################################
getInnerLinks(mainUrl, res_body, httpHeaders, reports, proxy) unless GET_INNER_LINKS == 0

## set total size report
###############################################################
if reports['totalSize'] < 1000
	totalSizeReport = reports['totalSize'].to_s + "B"
else
	totalSizeReport = (reports['totalSize']/1000).to_s + "KB"
end

#send data to graphite
if !GRAPHITE_HOST.nil?
  graphite = Graphite.new(GRAPHITE_HOST)
  graphite.push GRAPHITE_BUCKET+'.'+'mainpage_time', (Time.now-startedTime)*1000
  graphite.push GRAPHITE_BUCKET+'.'+'mainpage_size', reports['totalSize']
end

## Get Statistics
###############################################################
finishedTime = Time.now
totalTime=finishedTime-startedTime


if DEBUG >= 1
  puts "\n * results"
  puts "Inner links count: #{reports['linksToDlCount']}"
  puts "Inner links dl cumulated time: "+sprintf("%.2f", reports['totalDlTime']) + "s"
  puts "Total time: "+sprintf("%.2f", totalTime)+"s"
  puts "Total size: #{totalSizeReport}"
  puts "\n"
end

if !GRAPHITE_HOST.nil?
  graphite.push(GRAPHITE_BUCKET+'.total_time', totalTime*1000)
  graphite.push(GRAPHITE_BUCKET+'.total_size', reports['totalSize'])
end

## Set exit value
###############################################################
if totalTime < timeWarn # Good \o/
  retCode=0
  retCodeLabel="OK"
elsif EXTENDED == 0 && totalTime >= timeWarn && totalTime < timeCritical # not so good o_o
  retCode=1
  retCodeLabel="Warn"
## - Extended mode begin
elsif EXTENDED == 1 && totalTime >= timeWarn && totalTime < timeWarn2 # not so good o_o
  retCode=1
  retCodeLabel="Warn"
elsif EXTENDED == 1 && totalTime >= timeWarn2 && totalTime < timeCritical # not so good o_o'
  retCode=3
  retCodeLabel="Unknown"
## - Extended mode end
else # bad :(
  retCode=2
  retCodeLabel="Critical"
end

## Store main page content if not OK
###############################################################
if retCode > 0 then
    log_content(mainUrl, res)
end

## show the error file count in output
###############################################################
if reports['fileErrorCount'] > 0
  fileErrorStr="/#{reports['fileErrorCount']} err"
else
  fileErrorStr=""
end


## print the script result for nagios
###############################################################
print "#{retCodeLabel} - #{totalSizeReport}, #{reports['linksToDlCount']+1} files#{fileErrorStr}, "+sprintf("%.2f", totalTime)+"s"
print "|size="+"#{totalSizeReport}"+" "+"time="+sprintf("%.2f", totalTime)+"s;#{timeWarn};#{timeCritical};0;#{REQUEST_TIMEOUT}"
print "\n"
exit retCode
