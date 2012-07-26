#!/bin/bash
# launchcheck-webpage tests with a local web server
# TODO before:
#  $ gem install bundler
#  $ bundle

echo "Launch webserver with sinatra"

ruby webapp/app.rb &
SERVER_PID=$!

#echo "do tests"
#sleep 5

#echo "kill webserver (pid [$SERVER_PID])"
#kill -9 $SERVER_PID

echo -e "to stop the web server:\nkill -9 $SERVER_PID"
