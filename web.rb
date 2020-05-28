require 'bundler'
require 'sinatra'
require 'slim'
require 'twilio-ruby'
require 'omniauth'
require 'omniauth-github'
require './model'

configure do
  set :root, File.dirname(__FILE__)
  set :static, true
  set :public_folder, "#{File.dirname(__FILE__)}/public"
  enable :run
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET']
  use Rack::Session::Cookie,
    :key => 'rack.session',
    :path => '/',
    :expire_after => 60 * 60 * 24 * 90,
    :secret => ENV['SESSION_SECRET']
  use OmniAuth::Builder do
    provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: 'user'
  end
end

configure :production do
  DataMapper.setup(:default, ENV['DATABASE_URL'])
  database_upgrade!
end

configure :test, :development do
  DataMapper.setup(:default, 'yaml:///tmp/twilitchbot')
  database_upgrade!
end

def redirect_to_top
  redirect '/', 302
end

get '/' do
  slim :index
end

post '/start' do
  Twilio::TwiML::VoiceResponse.new do |r|
    url = "#{ENV['HEROKU_URL']}/receive_number"
    r.gather timeout: 30, finishOnKey: '#', action: url, method: 'POST' do |g|
      r.say(message: '置き配自動システムへようこそ。追跡番号を入力し、最後に、シャープを押してください。', language: 'ja-jp')
    end
  end.to_xml
end

post '/receive_number' do
  Twilio::TwiML::VoiceResponse.new do |r|
    r.say(message: "入力された番号は、#{params[:Digits].split('').join('、')}、です。", language: 'ja-jp')
  end.to_xml
end

get '/auth/:provider/callback' do
  auth = request.env['omniauth.auth']
  user = User.first(:user_id => auth[:uid].to_i)
  if not user.nil?
    user.update(nickname: auth[:info][:nickname])
  else
    user = User.create(user_id: auth[:uid].to_i, nickname: auth[:info][:nickname])
  end
  session[:user_id] = user.user_id
  session[:logged_in] = true
  redirect_to_top
end

post '/logout' do
  session.clear
  redirect_to_top
end

before do
  uri = URI(request.url)
  if session[:logged_in]
    @me = User.first(:user_id => session[:user_id])
  end
end
