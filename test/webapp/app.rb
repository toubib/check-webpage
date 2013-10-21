require 'sinatra'

get '/' do
  erb :index
end

get '/subfolder/' do
  erb :subfolder
end

get '/cookie' do
  "value: #{request.cookies["gordon"]}"
end

get '/wait3s' do
  sleep 3
  erb :index
end

get '/401' do
  headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
  halt 401, "Not authorized\n"
end
