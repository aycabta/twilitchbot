require 'bundler'
require 'sinatra'
require 'slim'
require 'slim/include'
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
      r.play(url: "#{ENV['HEROKU_URL']}/announcement.mp3")
    end
  end.to_xml
end

post '/receive_number' do
  Twilio::TwiML::VoiceResponse.new do |r|
    delivery = Delivery.first(tracking_number: params[:Digits])
    if delivery
      Thread.start {
        24.times do
          sleep 5
          delivery.user.ifttt.punch
        end
      }
      r.play(url: "#{ENV['HEROKU_URL']}/correct.mp3")
    else
      r.play(url: "#{ENV['HEROKU_URL']}/error.mp3")
    end
  end.to_xml
end

get '/user/set_ifttt' do
  slim :set_ifttt
end

post '/user/set_ifttt' do
  @errors = []
  md = params[:url].match(%r{https://maker\.ifttt\.com/trigger/(.*)/with/key/(.+)})
  if md
    if @me.ifttt
      @me.ifttt.update(
        access_key: md[1],
        event_name: md[2])
    else
      ifttt = IFTTT.create(
        access_key: md[1],
        event_name: md[2])
      @me.update(ifttt: ifttt)
    end
    redirect_to_top
  else
    @errors << 'URL is not valid'
    slim :set_ifttt
  end
end

post '/user/add_tracking_number' do
  delivery = Delivery.create(tracking_number: params[:tracking_number])
  @me.deliveries << delivery
  @me.save
  redirect_to_top
end

post '/user/delete_tracking_number' do
  delivery = Delivery.first(tracking_number: params[:tracking_number])
  delivery.destroy
  redirect_to_top
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
  if uri.path =~ %r{^/user/(\d+)} and @me.nil?
    redirect_to_top
  end
end
