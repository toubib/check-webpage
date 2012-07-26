require 'sinatra'

get '/' do
  erb :index
end

get '/subfolder/' do
  erb :subfolder
end

