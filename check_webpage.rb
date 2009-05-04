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
#	Copyright Vincent Reydet

#TODO
# - check if threadsafe
# - catch timeout error

require 'net/http'
require 'net/https'
require 'open-uri'
require 'rubygems'
require 'hpricot'
require 'optiflag'

#OPT PARSING
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
  optional_flag "c" do
    long_form "critical"
    description "--critical, default 60,  Critical time (s)"
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
  flag "u" do
    long_form "url"
    description "--url, absolute: [http://www.google.com]"
  end

  and_process!
end 

#VARS
if ARGV.flags.e?
  isEXTENDED=1
else
  isEXTENDED=0
end

if ARGV.flags.vv?
  isDEBUG=2
elsif ARGV.flags.v?
  isDEBUG=1
else
  isDEBUG=0
end

if ARGV.flags.c?
  tCRITICAL=ARGV.flags.c.to_f
else
  tCRITICAL=60
end

if ARGV.flags.w?
  tWARN=ARGV.flags.w.to_f
else
  tWARN=5
end

if ARGV.flags.w2?
  tWARN2=ARGV.flags.w2.to_f
else
  tWARN2=10
end

if ARGV.flags.k?
  keyword=ARGV.flags.k
else
  keyword=nil
end


requestTimeout=180

if isDEBUG >= 2;puts "\n * ARGS: c=#{tCRITICAL} w=#{tWARN} e=#{isEXTENDED} w2=#{tWARN2} u=#{ARGV.flags.u}";end

begin
  mainUrl = URI.parse(ARGV.flags.u)
rescue
  puts "Critical: syntax error, can't parse url ..."
  retCodeLabel="Critical"
  exit 2
end

if mainUrl.path == "" || mainUrl.path == nil
  mainUrl.path = '/'
end

## Remove certificate warning
#  http://www.5dollarwhitebox.org/drupal/node/64

class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end

## PART 1 - get main page and parse it
tStart = Time.now
if isDEBUG >= 1;puts "\n * Get main page: #{mainUrl}";end
h = Net::HTTP.new( mainUrl.host, mainUrl.port)
if mainUrl.scheme == "https"
  h.use_ssl = true
end
h.read_timeout=requestTimeout
resp, data = h.get(mainUrl.path, nil)

#handle redirection
i=0
while resp.code == "302"
  begin
    mainUrl = URI.parse(resp['location'])
  rescue
    puts "Critical: can't parse redirected url ..."
    exit 2
  end
  if isDEBUG >= 1;puts "   -> 302, main page is now: #{mainUrl}";end
  h = Net::HTTP.new( mainUrl.host, mainUrl.port)
  if mainUrl.scheme == "https"
    h.use_ssl = true
  end
  h.read_timeout=requestTimeout
  resp, data = h.get(mainUrl.path, nil)
  i+=1
  if i >= 5
    if isDEBUG >= 1;puts "   -> too much redirect (5), exit";end
    exit 2
  end
end

#check return code
if resp.code != "200"
  puts "Critical: main page rcode is #{resp.code} - #{resp.message}"
  exit 2
end

#Check for keyword
if keyword != nil
  hasKey=0
  data.each { |line|
    if line =~ /#{keyword}/
      hasKey=1
    end
  }
  if hasKey==0
    puts "Critical: string not found"
    exit 2
  end
end

#Get page size
tsize=data.length

if isDEBUG >= 1;puts "[#{resp.code}] #{resp.message} s(#{tsize}) t(#{Time.now-tStart})";end

doc = Hpricot(data)
parsingResult = doc.search("//img[@src]").map { |x| x['src'] }
parsingResult = parsingResult + doc.search("//script[@src]").map { |x| x['src'] }
#parsingResult = parsingResult + doc.search("//SCRIPT[@SRC]").map { |x| x['src'] }
parsingResult = parsingResult + doc.search("//link[@href]").map { |x| x['href'] }
parsingResult = parsingResult + doc.search("//embed[@src]").map { |x| x['src'] }

linksToDl = []

if isDEBUG >= 2;puts "\n * parsing results (#{parsingResult.length}) ...";end
parsingResult.length.times do |i|
  #change link to full link
  if parsingResult[i][0,4] != "http" && parsingResult[i][0,1] != "/"
    parsingResult[i]="/"+parsingResult[i];
  end
  if parsingResult[i][0,4] != "http"
   parsingResult[i]= mainUrl.scheme+"://"+mainUrl.host + parsingResult[i]
  end

  begin
    #test if url
    url = URI.parse(URI.escape(parsingResult[i],"[]{}|+"))
    if url.host != mainUrl.host
      if isDEBUG >= 2;puts "#{parsingResult[i]} -> pass";end
      next
    end

  rescue URI::InvalidURIError
    if isDEBUG >= 2;puts "#{parsingResult[i]} -> error";end
    next
  end
  if isDEBUG >= 2;puts "#{parsingResult[i]} -> add";end
  linksToDl.push(url)
end

if isDEBUG >= 2;linksToDlPrevCount=linksToDl.length;end
linksToDl.uniq!
if isDEBUG >= 2;puts "\n * remove duplicated links: #{linksToDlPrevCount} -> #{linksToDl.length}";end

## PART 2 - DL content links
tdl=0 #Stat
fileErrorCount=0
if isDEBUG >= 1;puts "\n * downloading inner links (#{linksToDl.length}) ...";end
threads = []
linksToDl.each {  |link|
  threads << Thread.new(link) { |myLink|
      t0 = Time.now
      h = Net::HTTP.new(myLink.host, myLink.port)
      if mainUrl.scheme == "https"
        h.use_ssl = true
      end
      h.read_timeout=requestTimeout
      resp, data = h.get(myLink.path, nil)
      t1 = Time.now-t0
      size=data.length
      tdl+=t1
      tsize+=size
      if resp.code != "200"
        fileErrorCount+=1
      end
      if isDEBUG >= 1;puts "[#{resp.code}] #{resp.message} "+myLink.to_s.gsub(mainUrl.scheme+"://"+mainUrl.host,"")+" -> s(#{size}o) t("+sprintf("%.2f", t1)+"s)";end
  }
}
threads.each { |aThread|  aThread.join }

tFinish = Time.now
tTotal=tFinish-tStart

if isDEBUG >= 1
  puts "\n * results"
  puts "Inner links count: #{linksToDl.length}"
  puts "Inner links dl cumulated time: "+sprintf("%.2f", tdl)+"s"
  puts "Total time: "+sprintf("%.2f", tTotal)+"s"
  puts "Total size: #{tsize/1000}ko"
  puts "\n"
end

# set return
if tTotal < tWARN
  retCode=0
  retCodeLabel="OK"
elsif !isEXTENDED && tTotal >= tWARN && tTotal < tCRITICAL
  retCode=1
  retCodeLabel="Warn"
## - Extended mode begin
elsif isEXTENDED && tTotal >= tWARN && tTotal < tWARN2
  retCode=1
  retCodeLabel="Warn"
elsif isEXTENDED && tTotal >= tWARN2 && tTotal < tCRITICAL
  retCode=3
  retCodeLabel="Unknown"
## - Extended mode end
else
  retCode=2
  retCodeLabel="Critical"
end

if fileErrorCount > 0
  fileErrorStr="/#{fileErrorCount} err"
else
  fileErrorStr=""
end

puts "#{retCodeLabel} - #{tsize/1000}ko, #{linksToDl.length+1} files#{fileErrorStr}, "+sprintf("%.2f", tTotal)+"s"
exit retCode
