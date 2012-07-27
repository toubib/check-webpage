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
