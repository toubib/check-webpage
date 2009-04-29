#!/usr/bin/env ruby

require 'net/http'
require 'open-uri'
require 'rubygems'
require 'hpricot'

isDEBUG=0
tWARN1=5
tWARN2=10
tCRITICAL=60
requestTimeout=180

#  puts "Syntax error, exit ...\n\n * "+$0+" http://example.com"

begin
  mainUrl = URI.parse(ARGV[0])
rescue
  puts "Critical: syntax error, can't parse url ..."
  retCodeLabel="Critical"
  exit 2
end

if mainUrl.path == "" || mainUrl.path == nil
  mainUrl.path = '/'
end

## PART 1 - get main page and parse it
tStart = Time.now
if isDEBUG >= 1;puts "\n * Get main page: #{mainUrl}";end

h = Net::HTTP.new( mainUrl.host, 80)
h.read_timeout=requestTimeout
resp, data = h.get(mainUrl.path, nil)

if resp.code != "200"
  puts "Critical: main page rcode is #{resp.code} - #{resp.message}"
  retCodeLabel="Critical"
  exit 2
end

if isDEBUG >= 1;puts "[#{resp.code}] #{resp.message} t(#{Time.now-tStart})";end

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
tsize=0
fileErrorCount=0
if isDEBUG >= 1;puts "\n * downloading inner links (#{linksToDl.length}) ...";end
threads = []
linksToDl.each {  |link|
  threads << Thread.new(link) { |myLink|
      t0 = Time.now
      h = Net::HTTP.new(myLink.host, 80)
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
if tTotal < tWARN1
  retCode=0
  retCodeLabel="OK"
elsif tTotal >= tWARN1 && tTotal < tWARN2
  retCode=1
  retCodeLabel="Warn"
elsif tTotal >= tWARN2 && tTotal < tCRITICAL
  retCode=3
  retCodeLabel="Unknown"
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
