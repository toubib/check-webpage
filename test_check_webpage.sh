#!/bin/bash
#
# This script use:
#   rvm - http://beginrescueend.com
#   netcat
#

RVM_VERSIONS="1.8.7 1.9.2"
PROXY_ADDRESS=192.168.0.202
PROXY_PORT=3128
PROXY_USE=0

green="\\033[1;32m"
red="\033[1;31m"
reset="\033[0m"

function die {
	echo $@
	exit 1
}

function check_if_OK {
  OPTS=$1

  echo -ne "search OK for $OPTS"

  ./check_webpage.rb $OPTS|egrep "^OK" > /dev/null

  if [ $? -eq 0 ]
  then
    echo -ne " [${green}OK${reset}]\n"
  else
    echo -ne " [${red}ERR${reset}]\n"
  fi
}

function check_if_ERR {
  OPTS=$1

  echo -ne "search ERR for $OPTS"
  
  ./check_webpage.rb $OPTS|egrep "^OK" > /dev/null

  if [ $? -gt 0 ]
  then
    echo -ne " [${green}OK${reset}]\n"
  else
    echo -ne " [${red}ERR${reset}]\n"
  fi
}

# CHECK COMMANDS
which rvm &>/dev/null || die "rvm not found"
which netcat &>/dev/null || die "netcat not found"

# TEST IF PROXY EXIST
echo "test proxy server"
netcat -v -w 1 $PROXY_ADDRESS -z $PROXY_PORT && PROXY_USE=1
echo

# LAUNCH TEST FOR EACH RUBY VERSION
for v in $RVM_VERSIONS
do
	rvm use $v
	
	echo
	check_if_OK "-u http://google.com"
	check_if_OK "-u http://google.com -vv"
	check_if_OK "-u http://google.com -k google"
	check_if_OK "-u http://google.com -k google -z"
	check_if_OK "-u http://google.com -k google -z -n"
	test $PROXY_USE -eq 1 && check_if_OK "-u http://google.com -P $PROXY_ADDRESS:$PROXY_PORT"

	check_if_OK "-u https://google.com"
	test $PROXY_USE -eq 1 && check_if_OK "-u https://google.com -P $PROXY_ADDRESS:$PROXY_PORT"
	
	echo
	check_if_ERR "-u http://4dsHfNYD4KRyktGH.com" 
	check_if_ERR "-u http://google.com -k 4dsHfNYD4KRyktGH"
	
	echo
done
